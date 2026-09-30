"""Home-profile handlers for the website gateway's documented route names.

Deploy this function behind /homeowner/home-profile-get,
/homeowner/home-profile-action, and /contractor/home-profile-get.
The Supabase service key is server-only. All reads are ownership checked.
"""
import base64
import copy
import json
import os
import uuid
from datetime import datetime, timezone

import functions_framework
from supabase import create_client

CORS = {'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Content-Type': 'application/json'}
ACTIVE = {'accepted', 'booked', 'scheduled', 'en_route', 'arrived', 'in_progress', 'wrapping_up', 'reschedule_pending'}
BUCKET = 'home-profile-documents'


def reply(data, status=200):
    return json.dumps(data, default=str), status, CORS


def authenticated_uid(sb, request):
    token = request.headers.get('Authorization', '').removeprefix('Bearer ').strip()
    if not token:
        raise PermissionError('Sign in to continue')
    try:
        user = sb.auth.get_user(token).user
    except Exception as exc:
        raise PermissionError('Your session has expired') from exc
    if not user or not user.email or not user.email_confirmed_at:
        raise PermissionError('A verified account is required')
    # The website uses numeric legacy IDs while Supabase authenticates UUIDs.
    rows = sb.table('user_login_agent_details').select('id').eq('email', user.email.lower()).limit(2).execute().data
    if len(rows or []) != 1:
        raise PermissionError('Account mapping is unavailable')
    return rows[0]['id']


def default_profile(address_id):
    return {'addressId': address_id, 'propertyDetails': {}, 'systems': [],
            'accessNotes': {'text': '', 'updatedAt': None}, 'documents': []}


def stored_profile(sb, address_id):
    rows = sb.table('home_profiles_v2').select('profile').eq('address_id', address_id).limit(1).execute().data
    return copy.deepcopy(rows[0]['profile']) if rows else default_profile(address_id)


def sign_file(sb, file):
    path = file.get('storagePath')
    if not path:
        return file
    signed = sb.storage.from_(BUCKET).create_signed_url(path, 900)
    return {**file, 'url': signed.get('signedURL') or signed.get('signedUrl')}


def output_profile(sb, address_id):
    profile = stored_profile(sb, address_id)
    profile['documents'] = [sign_file(sb, d) for d in profile.get('documents', [])]
    # Never trust a client-entered service date. Only a completed, linked work
    # order establishes service history. Unlinked systems display no date.
    rows = sb.table('work_orders').select('system_id,completed_at').eq('address_id', address_id).eq('status', 'completed').execute().data or []
    for system in profile.get('systems', []):
        dates = [r['completed_at'] for r in rows if str(r.get('system_id')) == str(system.get('id')) and r.get('completed_at')]
        system['lastServicedAt'] = max(dates) if dates else None
        if system.get('dataPlateStoragePath'):
            system['dataPlatePhotoUrl'] = sign_file(sb, {'storagePath': system['dataPlateStoragePath']}).get('url')
    return profile


def validate_profile(body, current):
    value = copy.deepcopy(body)
    details = value.get('propertyDetails')
    if not isinstance(details, dict):
        raise ValueError('propertyDetails is required')
    for key in ('squareFootage', 'yearBuilt', 'bedrooms', 'bathrooms'):
        amount = details.get(key)
        if amount is not None and (isinstance(amount, bool) or not isinstance(amount, (int, float)) or not 0 <= amount <= 1000000):
            raise ValueError('Invalid property detail')
    systems = value.get('systems', [])
    if not isinstance(systems, list) or len(systems) > 100:
        raise ValueError('Invalid systems')
    seen = set()
    saved_files = {d['id']: d for d in current.get('documents', [])}
    for system in systems:
        if not isinstance(system, dict) or not system.get('id') or not str(system.get('type', '')).strip():
            raise ValueError('System id and type are required')
        if system['id'] in seen:
            raise ValueError('Duplicate system id')
        seen.add(system['id'])
        system.pop('lastServicedAt', None)
        system.pop('dataPlatePhotoUrl', None)
        # Derive photo ownership from the upload record, never a client URL.
        photos = [d for d in saved_files.values() if d.get('kind') == 'data_plate' and d.get('systemId') == system['id']]
        system.pop('dataPlateStoragePath', None)
        if photos:
            system['dataPlateStoragePath'] = photos[-1]['storagePath']
    notes = value.get('accessNotes', {})
    if not isinstance(notes, dict) or not isinstance(notes.get('text', ''), str) or len(notes.get('text', '')) > 4000:
        raise ValueError('Access notes must be at most 4000 characters')
    return {'addressId': current['addressId'], 'propertyDetails': details, 'systems': systems,
            'accessNotes': {'text': notes.get('text', ''), 'updatedAt': datetime.now(timezone.utc).isoformat()},
            'documents': list(saved_files.values())}


def upload(sb, uid, address_id, body, profile):
    allowed = {'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'}
    mime = body.get('mimeType')
    if mime not in allowed or (body.get('kind') == 'data_plate' and mime == 'application/pdf'):
        raise ValueError('Unsupported file type')
    try:
        data = base64.b64decode(body.get('fileBase64', ''), validate=True)
    except Exception as exc:
        raise ValueError('Invalid file encoding') from exc
    if not 0 < len(data) <= 10 * 1024 * 1024:
        raise ValueError('File must be non-empty and at most 10 MB')
    signatures = {'application/pdf': data.startswith(b'%PDF-'), 'image/jpeg': data.startswith(b'\xff\xd8\xff'),
                  'image/png': data.startswith(b'\x89PNG\r\n\x1a\n'), 'image/webp': data.startswith(b'RIFF') and data[8:12] == b'WEBP'}
    if not signatures[mime]:
        raise ValueError('File content does not match its type')
    doc_id = str(uuid.uuid4())
    path = f'{uid}/{address_id}/{doc_id}.{allowed[mime]}'
    sb.storage.from_(BUCKET).upload(path, data, {'content-type': mime})
    doc = {'id': doc_id, 'name': str(body.get('fileName') or 'Document')[:255], 'storagePath': path,
           'systemId': body.get('systemId'), 'kind': body.get('kind', 'document'), 'uploadedAt': datetime.now(timezone.utc).isoformat()}
    profile['documents'].append(doc)
    sb.table('home_profiles_v2').upsert({'address_id': address_id, 'user_id': uid, 'profile': profile}).execute()
    return sign_file(sb, doc)


@functions_framework.http
def home_profile(request):
    if request.method == 'OPTIONS':
        return '', 204, CORS
    if request.method != 'POST':
        return reply({'success': False, 'error': 'method_not_allowed'}, 405)
    try:
        sb = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SECRET_KEY'])
        uid = authenticated_uid(sb, request)
        body = request.get_json(silent=True) or {}
        # Contractors must name the actual booking, never a homeowner ID.
        if request.path.startswith('/contractor/'):
            orders = sb.table('work_orders').select('address_id,status,assigned_contractor_user_id').eq('id', body.get('workOrderId')).limit(1).execute().data
            if not orders or orders[0]['assigned_contractor_user_id'] != uid or orders[0]['status'] not in ACTIVE:
                raise PermissionError('No active confirmed booking for this address')
            return reply({'success': True, 'homeProfile': output_profile(sb, orders[0]['address_id'])})
        addresses = sb.table('homeowner_addresses').select('*').eq('user_id', uid).eq('is_deleted', False).execute().data or []
        action = body.get('action')
        if action is None:
            return reply({'success': True, 'addresses': addresses, 'hasAnyAddress': bool(addresses),
                          'homeProfiles': [output_profile(sb, a['id']) for a in addresses]})
        address_id = body.get('addressId')
        if not any(a['id'] == address_id for a in addresses):
            raise PermissionError('Address does not belong to this account')
        current = stored_profile(sb, address_id)
        if action == 'upsert':
            profile = validate_profile(body, current)
            sb.table('home_profiles_v2').upsert({'address_id': address_id, 'user_id': uid, 'profile': profile}).execute()
            return reply({'success': True, 'homeProfile': output_profile(sb, address_id)})
        if action == 'upload_document':
            doc = upload(sb, uid, address_id, body, current)
            return reply({'success': True, 'document': doc})
        raise ValueError('Unknown action')
    except PermissionError as exc:
        return reply({'success': False, 'error': str(exc)}, 403)
    except ValueError as exc:
        return reply({'success': False, 'error': str(exc)}, 400)
    except Exception:
        # Do not log profile contents, gate codes, files or access tokens.
        return reply({'success': False, 'error': 'Home profile service unavailable'}, 503)
