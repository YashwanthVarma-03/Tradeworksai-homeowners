import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class IntakeService {
  IntakeService._internal();

  static final IntakeService instance = IntakeService._internal();

  static const String _intakePath = 'public/intake-assist';
  static const String _uploadUrlPath = 'public/intake-upload-url';
  static const String _sessionTokenKey = 'tw_intake_session_token';

  Future<String> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_sessionTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-${random.nextInt(1 << 32)}';
    await prefs.setString(_sessionTokenKey, token);
    return token;
  }

  Future<void> resetSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionTokenKey);
  }

  Future<Map<String, dynamic>> assist({
    required String text,
    required String zip,
    List<String> photoRefs = const [],
    List<Map<String, String>> priorTurns = const [],
    String? sessionToken,
  }) async {
    final resolvedSessionToken = sessionToken ?? await getSessionToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$_intakePath'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionToken': resolvedSessionToken,
        'text': text,
        'photoRefs': photoRefs,
        'zip': zip,
        'priorTurns': priorTurns,
      }),
    );

    if (response.body.isEmpty) {
      throw Exception('Empty intake response.');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid intake response.');
    }
    if (response.statusCode >= 400 || data['success'] == false) {
      throw Exception(
        data['error']?.toString() ??
            data['reason']?.toString() ??
            'AI intake failed.',
      );
    }
    return data;
  }

  Future<String> uploadPhoto({
    required XFile file,
    String? sessionToken,
  }) async {
    final resolvedSessionToken = sessionToken ?? await getSessionToken();
    final contentType = _contentTypeForPath(file.path);

    final signResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$_uploadUrlPath'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionToken': resolvedSessionToken,
        'contentType': contentType,
      }),
    );

    if (signResponse.body.isEmpty) {
      throw Exception('Empty upload-url response.');
    }

    final signData = jsonDecode(signResponse.body);
    if (signData is! Map<String, dynamic>) {
      throw Exception('Invalid upload-url response.');
    }
    if (signResponse.statusCode >= 400 || signData['success'] == false) {
      throw Exception(
        signData['error']?.toString() ??
            signData['reason']?.toString() ??
            'Photo upload initialization failed.',
      );
    }

    final uploadUrl = signData['uploadUrl']?.toString();
    final path = signData['path']?.toString();
    if (uploadUrl == null ||
        uploadUrl.isEmpty ||
        path == null ||
        path.isEmpty) {
      throw Exception('Incomplete photo upload details.');
    }

    final bytes = await file.readAsBytes();
    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {'content-type': contentType},
      body: bytes,
    );

    if (uploadResponse.statusCode < 200 || uploadResponse.statusCode >= 300) {
      throw Exception('Photo upload failed (${uploadResponse.statusCode}).');
    }

    return path;
  }

  String _contentTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class IntakeResolution {
  const IntakeResolution({
    required this.outcome,
    this.categorySlug,
    this.subcategorySlug,
    this.label,
    this.scopedDescription,
    this.suggestedUrgency = 'standard',
    this.clarifyingQuestion,
  });

  final String outcome;
  final String? categorySlug;
  final String? subcategorySlug;
  final String? label;
  final String? scopedDescription;
  final String suggestedUrgency;
  final String? clarifyingQuestion;

  factory IntakeResolution.fromApi(Map<String, dynamic> data) {
    final first = ((data['subcategoryMatches'] as List?) ?? const [])
        .whereType<Map>()
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final top = first.isEmpty ? null : first.first;
    return IntakeResolution(
      outcome: data['outcome']?.toString() ?? 'fallback',
      categorySlug: top?['categorySlug']?.toString(),
      subcategorySlug: top?['subcategorySlug']?.toString(),
      label: top?['label']?.toString(),
      scopedDescription: data['scopedDescription']?.toString(),
      suggestedUrgency: data['suggestedUrgency']?.toString() ?? 'standard',
      clarifyingQuestion: data['clarifyingQuestion']?.toString(),
    );
  }
}
