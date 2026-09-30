import importlib.util
import sys
import types
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

# These tests validate pure boundaries without credentials or a live database.
framework = types.SimpleNamespace(http=lambda function: function)
supabase = types.SimpleNamespace(create_client=lambda *a: None)
with patch.dict(sys.modules, {'functions_framework': framework, 'supabase': supabase}):
    spec = importlib.util.spec_from_file_location('profile_handler', Path(__file__).parents[1] / 'home_profiles/main.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)


class HomeProfileContractTests(unittest.TestCase):
    def test_service_date_and_foreign_photo_are_not_client_authority(self):
        current = module.default_profile(1)
        body = {'propertyDetails': {'bedrooms': 3}, 'systems': [{'id': 's1', 'type': 'HVAC', 'lastServicedAt': '2099-01-01', 'dataPlatePhotoUrl': 'https://foreign.test/a', 'dataPlateStoragePath': 'other/account/file'}], 'accessNotes': {'text': 'Gate instructions'}}
        saved = module.validate_profile(body, current)
        self.assertNotIn('lastServicedAt', saved['systems'][0])
        self.assertNotIn('dataPlateStoragePath', saved['systems'][0])
        self.assertNotIn('dataPlatePhotoUrl', saved['systems'][0])
        self.assertEqual(saved['addressId'], 1)

    def test_non_finite_and_negative_property_values_are_rejected(self):
        for value in (float('nan'), float('inf'), -1, True, '3'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                module.validate_profile({'propertyDetails': {'bedrooms': value}}, module.default_profile(1))

    def test_notes_limit_is_enforced_server_side(self):
        with self.assertRaises(ValueError):
            module.validate_profile({'propertyDetails': {}, 'accessNotes': {'text': 'x' * 4001}}, module.default_profile(1))

    def test_auth_uses_verified_token_identity(self):
        sb = MagicMock()
        sb.auth.get_user.return_value.user = types.SimpleNamespace(email='owner@example.com', email_confirmed_at='2026-01-01')
        sb.table.return_value.select.return_value.eq.return_value.limit.return_value.execute.return_value.data = [{'id': 42}]
        request = types.SimpleNamespace(headers={'Authorization': 'Bearer valid-session'})
        self.assertEqual(module.authenticated_uid(sb, request), 42)
        sb.auth.get_user.assert_called_once_with('valid-session')

    def test_missing_auth_fails_before_database_read(self):
        sb = MagicMock()
        with self.assertRaises(PermissionError):
            module.authenticated_uid(sb, types.SimpleNamespace(headers={}))
        sb.table.assert_not_called()

    def test_mime_spoof_fails_before_storage_upload(self):
        sb = MagicMock()
        with self.assertRaises(ValueError):
            module.upload(sb, 42, 1, {'mimeType': 'image/png', 'fileBase64': 'aGVsbG8='}, module.default_profile(1))
        sb.storage.from_.assert_not_called()


if __name__ == '__main__':
    unittest.main()
