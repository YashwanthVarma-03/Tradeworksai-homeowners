"""Exercise edited gateway functions with Flask contexts and an in-memory DB.

PLATFORM_API_ROOT can point to a checkout with platform-batches-1-17-current.patch applied.
These test business handlers; production JWT middleware and RLS need staging tests.
"""
import ast
from datetime import date, datetime, timedelta, timezone
import logging
import os
from pathlib import Path
import re
from types import SimpleNamespace
import unittest
from flask import Flask, g, jsonify, request

ROOT = Path(__file__).resolve().parents[2]
API = Path(os.environ.get('PLATFORM_API_ROOT', ROOT / '.repo_ref/platform-current-20260930/backend/services/api'))


def load_functions(relative, names, extra=None):
    source = (API / relative).read_text(encoding='utf-8-sig')
    body = []
    for node in ast.parse(source).body:
        if isinstance(node, ast.FunctionDef) and node.name in names:
            node.decorator_list = []
            body.append(node)
    namespace = dict(datetime=datetime, date=date, timedelta=timedelta, timezone=timezone,
                     re=re, logging=logging, jsonify=jsonify, request=request, g=g)
    namespace.update(extra or {})
    exec(compile(ast.Module(body=body, type_ignores=[]), relative, 'exec'), namespace)
    return namespace


class Query:
    def __init__(self, db, name):
        self.db, self.name, self.filters = db, name, []
        self.operation, self.value = None, None
    def select(self, *args, **kwargs): return self
    def limit(self, *args): return self
    def eq(self, key, value):
        self.filters.append((key, value)); return self
    def update(self, value): self.operation, self.value = 'update', value; return self
    def insert(self, value): self.operation, self.value = 'insert', value; return self
    def delete(self): self.operation = 'delete'; return self
    def execute(self):
        table = self.db.rows.setdefault(self.name, [])
        rows = [row for row in table if all(str(row.get(k)) == str(v) for k, v in self.filters)]
        if self.operation == 'insert':
            row = {'id': 100, **self.value}; table.append(row); rows = [row]
        elif self.operation == 'update':
            for row in rows: row.update(self.value)
        elif self.operation == 'delete':
            for row in rows: table.remove(row)
        return SimpleNamespace(data=rows)


class Database:
    def __init__(self, rows): self.rows = rows
    def table(self, name): return Query(self, name)


class PlatformContracts(unittest.TestCase):
    def setUp(self):
        self.app = Flask(__name__)
        self.db = Database({'work_orders': [{'id': 1, 'requester_user_id': 7,
            'assigned_contractor_user_id': 8, 'status': 'completed',
            'completed_at': '2025-01-01T00:00:00Z', 'invoice_amount': 100}],
            'contractor_profiles': [{'id': 20, 'user_id': 8}],
            'contractor_reviews': [{'id': 2, 'work_order_id': 1, 'rating': 5,
                'review_date': '2025-01-01', 'pro_response': {'text': 'Thank you'}}]})
        self.ns = load_functions('homeowner/routes.py', {
            '_now', '_parse_ts', '_pending_arrival', '_review_load_owned', '_eligibility',
            '_resolve_contractor_profile_id', '_flagged', '_wo_load_owned',
            'homeowner_review_action', 'homeowner_work_orders_action'}, {
            'sb': lambda: self.db, 'TEXT_MIN': 10, 'TEXT_MAX': 2000, 'REVIEW_WINDOW_DAYS': 90,
            'EMAIL_RE': re.compile(r'\S+@\S+'), 'PHONE_RE': re.compile(r'\d{10,}'), 'PROFANITY': set()})

    def invoke(self, action, user=7, **body):
        with self.app.test_request_context(json={'action': action, 'workOrderId': 1, **body}):
            g.legacy_uid = user
            result = self.ns['homeowner_review_action']()
            response = result[0] if isinstance(result, tuple) else result
            return response.get_json()

    def invoke_work_order_action(self, action, user=7, **body):
        with self.app.test_request_context(json={'action': action, 'workOrderId': 1, **body}):
            g.legacy_uid = user
            result = self.ns['homeowner_work_orders_action']()
            response = result[0] if isinstance(result, tuple) else result
            return response.get_json()

    def test_edit_preserves_date_and_response_after_new_review_window(self):
        result = self.invoke('update_review', rating=2, text='The visit ran late.', tags=['On time'])
        self.assertTrue(result['ok'])
        row = self.db.rows['contractor_reviews'][0]
        self.assertEqual(row['review_date'], '2025-01-01')
        self.assertEqual(row['pro_response']['text'], 'Thank you')
        self.assertEqual(row['rating'], 2)
        self.assertTrue(row['edited_at'])

    def test_body_identity_cannot_authorize_another_homeowners_review(self):
        result = self.invoke('deleteReview', user=99, requesterUserId=7)
        self.assertFalse(result['success'])
        self.assertEqual(result['reason'], 'not_your_order')
        self.assertEqual(len(self.db.rows['contractor_reviews']), 1)

    def test_delete_is_owned_and_idempotent(self):
        self.assertTrue(self.invoke('deleteReview')['deleted'])
        self.assertTrue(self.invoke('deleteReview')['deleted'])
        self.assertEqual(self.db.rows['contractor_reviews'], [])

    def test_cap_tag_requires_invoice_and_invalid_tags_are_rejected(self):
        self.db.rows['work_orders'][0]['invoice_amount'] = None
        result = self.invoke('update_review', rating=3, text='An ordinary service.', tags=['Price stayed within the cap'])
        self.assertEqual(result['error'], 'invoice_required_for_cap_tag')
        result = self.invoke('update_review', rating=3, text='An ordinary service.', tags=['Invented'])
        self.assertEqual(result['error'], 'invalid_tags')

    def test_arrival_silence_stays_pending_until_an_answer(self):
        row = {'status': 'accepted', 'scheduled_end': '2020-01-01T00:00:00Z'}
        self.assertTrue(self.ns['_pending_arrival'](row))
        row['arrival_check_resolved_end'] = row['scheduled_end']
        self.assertFalse(self.ns['_pending_arrival'](row))
        row['scheduled_end'] = '2020-02-01T00:00:00Z'
        self.assertTrue(self.ns['_pending_arrival'](row))
        row['status'] = 'completed'
        self.assertFalse(self.ns['_pending_arrival'](row))

    def test_customer_no_show_reply_keeps_the_case_open(self):
        self.db.rows['work_orders'][0]['status'] = 'customer_no_show'
        result = self.invoke_work_order_action(
            'no_show_reply', text='I was delayed by a family emergency.')
        self.assertTrue(result['ok'])
        row = self.db.rows['work_orders'][0]
        self.assertEqual(row['status'], 'customer_no_show')
        self.assertEqual(row['homeowner_no_show_reply'], 'I was delayed by a family emergency.')
        self.assertTrue(row['homeowner_no_show_replied_at'])

    def test_arrival_notification_uses_real_dispatcher(self):
        deliveries = []
        ns = load_functions('shared/notify.py', {'notify', '_t_arrival_reported'}, {
            '_wrap': lambda html: html, 'USER_SCOPED_TEMPLATES': set(),
            'CONTRACTOR_TEMPLATES': {'arrival_reported'},
            '_contractor_recipient': lambda db, wo: ('pro@example.test', 8, 'Pro'),
            '_inapp': lambda *args: deliveries.append(('inapp', args)),
            '_send_email': lambda *args: deliveries.append(('email', args)),
            '_log': lambda *args, **kwargs: None})
        ns['TEMPLATES'] = {'arrival_reported': ns['_t_arrival_reported']}
        self.assertTrue(ns['notify'](self.db, 'arrival_reported', {'id': 1}))
        self.assertEqual([item[0] for item in deliveries], ['inapp', 'email'])

    def test_contractor_can_discover_only_own_arrival_cases(self):
        self.db.rows['arrival_cases'] = [{'id': 9, 'work_order_id': 1}]
        ns = load_functions('contractor/routes.py', {'contractor_arrival_cases'}, {'sb': lambda: self.db})
        with self.app.test_request_context():
            g.legacy_uid = 8
            self.assertEqual(ns['contractor_arrival_cases'](1).get_json()['cases'][0]['id'], 9)
            g.legacy_uid = 99
            self.assertEqual(ns['contractor_arrival_cases'](1)[1], 404)

    def test_all_gateway_python_files_parse(self):
        for path in API.rglob('*.py'):
            ast.parse(path.read_text(encoding='utf-8-sig'), str(path))


if __name__ == '__main__':
    unittest.main()
