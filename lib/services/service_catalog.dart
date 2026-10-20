import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'supabase_config.dart';

class ServiceCatalogItem {
  final String name;
  final String category;
  final String categorySlug;
  final String slug;

  const ServiceCatalogItem(this.name, this.category,
      {required this.categorySlug, required this.slug});
}

/// Both the Home count and All list use these active public backend rows.
class ServiceCatalog {
  static final revision = ValueNotifier<int>(0);
  static List<ServiceCatalogItem> _items = const [];
  static List<ServiceCatalogItem> get items => _items;

  /// Main services are unique categories; items retains subservices for search.
  static List<ServiceCatalogItem> get mainServices {
    final seen = <String>{};
    return items
        .where((item) => seen.add(item.categorySlug))
        .map((item) => ServiceCatalogItem(item.category, item.category,
            categorySlug: item.categorySlug, slug: item.categorySlug))
        .toList(growable: false);
  }

  static List<String> get names => items.map((s) => s.name).toList();
  static bool loaded = false;
  static bool loading = false;
  static String? error;
  static Future<void>? _pending;
  static DateTime? _loadedAt;

  @visibleForTesting
  static Future<List<Map<String, dynamic>>> Function(int from, int to)?
      fetchPage;

  static Future<void> load({bool forceRefresh = false}) {
    if (_pending != null) return _pending!;
    if (!forceRefresh &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < const Duration(minutes: 5)) {
      return Future.value();
    }
    return _pending = _load().whenComplete(() => _pending = null);
  }

  static Future<void> _load() async {
    loading = true;
    error = null;
    try {
      final rows = <Map<String, dynamic>>[];
      const pageSize = 500;
      for (var from = 0;; from += pageSize) {
        final page = await (fetchPage != null
                ? fetchPage!(from, from + pageSize - 1)
                : _fetchPublicPage(from, from + pageSize - 1))
            .timeout(const Duration(seconds: 20));
        rows.addAll(page);
        if (page.length < pageSize) break;
      }
      _items = List.unmodifiable(parse(rows));
      loaded = true;
      _loadedAt = DateTime.now();
    } catch (_) {
      error = 'Services could not be updated. Please try again.';
    } finally {
      loading = false;
      revision.value++;
    }
  }

  @visibleForTesting
  static List<ServiceCatalogItem> parse(List<Map<String, dynamic>> rows) {
    final seen = <String>{};
    return rows
        .where((r) => r['is_active'] == true)
        .map((r) => ServiceCatalogItem('${r['subcategory_name'] ?? ''}'.trim(),
            '${r['category_name'] ?? ''}'.trim(),
            categorySlug: '${r['category_slug'] ?? ''}'.trim(),
            slug: '${r['subcategory_slug'] ?? ''}'.trim()))
        .where((s) =>
            s.name.isNotEmpty &&
            s.category.isNotEmpty &&
            s.slug.isNotEmpty &&
            s.categorySlug.isNotEmpty &&
            seen.add('${s.categorySlug}/${s.slug}'))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchPublicPage(
      int from, int to) async {
    final uri = Uri.parse('${SupabaseConfig.url}/rest/v1/service_categories')
        .replace(queryParameters: {
      'select':
          'id,category_name,category_slug,subcategory_name,subcategory_slug,is_active,category_sort,sort_order',
      'is_active': 'eq.true',
      'order': 'category_sort,sort_order,id',
      'offset': '$from',
      'limit': '${to - from + 1}',
    });
    // This is a public catalogue, identical for guests and customers. Do not
    // attach a customer JWT: the deployed table grants reads to the public
    // API role, but currently rejects the authenticated role with HTTP 403.
    final response = await http.get(uri, headers: {
      'apikey': SupabaseConfig.publishableKey,
      'Accept': 'application/json',
    });
    if (response.statusCode != 200) throw StateError('Catalogue unavailable');
    final data = jsonDecode(response.body);
    if (data is! List)
      throw const FormatException('Invalid catalogue response');
    return data.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
}
