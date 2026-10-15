import 'dart:convert';
import 'dart:io';
import 'package:homeowners_app/services/service_catalog.dart';

/// Public backend fixture captured 2026-10-15. Used only by automated tests.
Future<void> loadCatalogFixture() async {
  final rows =
      (jsonDecode(File('test/fixtures/service_catalog.json').readAsStringSync())
              as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
  ServiceCatalog.fetchPage =
      (from, to) async => rows.skip(from).take(to - from + 1).toList();
  await ServiceCatalog.load(forceRefresh: true);
}
