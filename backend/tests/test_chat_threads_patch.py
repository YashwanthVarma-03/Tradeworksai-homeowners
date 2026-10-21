"""Test patched production chat handlers without Flask, credentials or Stream.

Set TRADEWORKS_CHAT_ROUTES to the patched platform batch8_routes.py. The default
is the local verification copy used to prepare chat-enquiries-and-provisioning.patch.
"""
import ast
import logging
import os
from pathlib import Path
import re
from types import SimpleNamespace
import unittest


class Database:
    def __init__(self):
        self.rows = {
            'contractor_profiles': [
                {'id': 900, 'user_id': 77, 'is_public': True},
                {'id': 901, 'user_id': 78, 'is_public': False},
            ],
            'user_login_agent_details': [
                {'id': 10, 'name': 'Homeowner'}, {'id': 77, 'name': 'Pro'},
            ],
            'work_orders': [
                {'id': 42, 'requester_user_id': 10, 'assigned_contractor_user_id': 77},
                {'id': 43, 'requester_user_id': 11, 'assigned_contractor_user_id': 77},
            ],
        }

    def table(self, table):
        class Query:
            def __init__(self, rows):
                self.rows = list(rows)
            def select(self, _): return self
            def eq(self, key, value):
                self.rows = [r for r in self.rows if r.get(key) == value]
                return self
            def limit(self, limit):
                self.rows = self.rows[:limit]
                return self
            def execute(self): return SimpleNamespace(data=self.rows)
        return Query(self.rows[table])


class Stream:
    def __init__(self):
        self.users, self.channels = {}, {}
        self.create_calls = 0
    def upsert_user(self, user): self.users[user['id']] = user
    def channel(self, kind, cid):
        owner = self
        class Channel:
            def create(self, user_id, data):
                owner.create_calls += 1
                if not set(data['members']).issubset(owner.users):
                    raise RuntimeError('participants must be provisioned first')
                owner.channels.setdefault(cid, {
                    **data, 'id': cid, 'type': kind,
                    'members': [{'user_id': uid} for uid in data['members']],
                })
                return {'channel': owner.channels[cid]}
            def query(self): return {'channel': owner.channels[cid]}
        return Channel()


class ChatPatchTests(unittest.TestCase):
    def setUp(self):
        path = Path(os.environ.get('TRADEWORKS_CHAT_ROUTES',
                    '.dart_tool/chat-backend/after.py'))
        if not path.is_file():
            self.skipTest('Apply the companion patch and set TRADEWORKS_CHAT_ROUTES to batch8_routes.py')
        tree = ast.parse(path.read_text(encoding='utf-8'))
        names = {
            '_profile_for_user', '_work_order_pair', '_has_work_order_pair',
            '_has_chat_pair', '_provision_chat_participants', '_channel_id',
            '_pair_from_channel_id', '_query_existing_member',
            '_work_order_reference', 'chat_thread_resolve',
        }
        nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
        self.assertEqual({n.name for n in nodes}, names)
        for node in nodes: node.decorator_list = []
        self.db, self.stream = Database(), Stream()
        self.body = {'contractorId': '900'}
        self.uid, self.roles = 10, ['homeowner']
        self.env = {
            '_uid': lambda: self.uid, '_body': lambda: self.body,
            'sb': lambda: self.db, '_stream': lambda: self.stream,
            'g': SimpleNamespace(roles=self.roles),
            '_err': lambda code, status=400: ({'error': code}, status),
            'jsonify': lambda **values: values, 'logging': logging,
            '_CHANNEL_ID': re.compile(r'^tw-(\d+)-(\d+)$'),
        }
        exec(compile(ast.Module(body=nodes, type_ignores=[]), str(path), 'exec'), self.env)

    def resolve(self): return self.env['chat_thread_resolve']()

    def test_homeowner_can_enquire_before_booking_and_users_are_provisioned(self):
        self.db.rows['work_orders'] = []
        response, status = self.resolve()
        self.assertEqual(status, 201)
        self.assertEqual(response['channelId'], 'tw-10-77')
        self.assertEqual(set(self.stream.users), {'10', '77'})
        self.assertIsNone(response['channel']['work_order_id'])
        self.assertTrue(self.env['_has_chat_pair'](self.db, 10, 77))
        self.assertFalse(self.env['_has_chat_pair'](self.db, 11, 77))

    def test_private_and_missing_profiles_are_rejected(self):
        for profile_id in ['901', '999']:
            self.body = {'contractorId': profile_id}
            self.assertEqual(self.resolve()[1], 404)
        self.assertEqual(self.stream.create_calls, 0)

    def test_contractors_cannot_initiate_enquiries(self):
        self.env['g'].roles = ['contractor']
        self.uid = 77
        self.assertEqual(self.resolve(), ({'error': 'contractor_cannot_initiate_chat'}, 403))
        self.assertEqual(self.stream.create_calls, 0)

    def test_foreign_order_cannot_be_opened(self):
        self.body = {'workOrderId': 43}
        self.assertEqual(self.resolve(), ({'error': 'work_order_not_found'}, 404))

    def test_profile_and_work_order_must_match(self):
        self.body = {'workOrderId': 42, 'contractorId': 901}
        self.assertEqual(self.resolve()[0]['error'], 'work_order_contractor_mismatch')

    def test_existing_work_order_chat_and_enquiry_share_the_same_channel(self):
        first, _ = self.resolve()
        self.body = {'workOrderId': 42}
        second, _ = self.resolve()
        self.assertEqual(first['channelId'], second['channelId'])
        self.assertEqual(len(self.stream.channels), 1)

    def test_untrusted_member_list_cannot_add_another_account(self):
        self.body.update({'members': ['10', '78'], 'homeowner_user_id': 11})
        response, _ = self.resolve()
        self.assertEqual(response['channel']['members'], [{'user_id': '10'}, {'user_id': '77'}])

    def test_enquiry_membership_requires_server_metadata_and_both_members(self):
        self.db.rows['work_orders'] = []
        self.resolve()
        channel = self.stream.channels['tw-10-77']
        channel['members'] = [{'user_id': '10'}]
        self.assertFalse(self.env['_has_chat_pair'](self.db, 10, 77))
        channel['members'].append({'user_id': '77'})
        channel['created_by_id'] = '78'
        self.assertFalse(self.env['_has_chat_pair'](self.db, 10, 77))

    def test_contractor_can_rejoin_an_existing_enquiry_without_initiating(self):
        # Membership is validated on list/read/send. Resolving with a work
        # order retains the existing contractor initiation restriction.
        self.db.rows['work_orders'] = []
        self.resolve()
        self.assertIsNotNone(self.env['_query_existing_member'](
            self.stream.channel('messaging', 'tw-10-77'), 77))
        self.assertIsNone(self.env['_query_existing_member'](
            self.stream.channel('messaging', 'tw-10-77'), 78))


if __name__ == '__main__':
    unittest.main()
