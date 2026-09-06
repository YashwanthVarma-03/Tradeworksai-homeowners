import 'dart:convert';
import 'dart:math';

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

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // UUID version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122
    final hexDigits = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hexDigits.substring(0, 8)}-${hexDigits.substring(8, 12)}-${hexDigits.substring(12, 16)}-${hexDigits.substring(16, 20)}-${hexDigits.substring(20, 32)}';
  }

  Future<String> getSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_sessionTokenKey);
    if (existing != null &&
        existing.isNotEmpty &&
        existing.contains('-') &&
        existing.length >= 32) {
      return existing;
    }

    final token = _generateUuidV4();
    await prefs.setString(_sessionTokenKey, token);
    return token;
  }

  Future<void> saveSessionToken(String token) async {
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionTokenKey, token);
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
    var resolvedSessionToken = sessionToken ?? await getSessionToken();
    var response = await http.post(
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

    if (response.statusCode >= 400 ||
        (response.body.isNotEmpty &&
            response.body.contains('invalid_session_token'))) {
      await resetSessionToken();
      resolvedSessionToken = await getSessionToken();
      response = await http.post(
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
    }

    if (response.body.isEmpty) {
      throw Exception(ApiConfig.emptyResponseMessage(_intakePath));
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

    final returnedToken = data['sessionToken']?.toString();
    if (returnedToken != null && returnedToken.isNotEmpty) {
      await saveSessionToken(returnedToken);
    }

    return data;
  }

  Future<String> uploadPhoto({
    required XFile file,
    String? sessionToken,
  }) async {
    var resolvedSessionToken = sessionToken ?? await getSessionToken();
    final contentType = _contentTypeForPath(file.path);

    var signResponse = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$_uploadUrlPath'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'sessionToken': resolvedSessionToken,
        'contentType': contentType,
      }),
    );

    if (signResponse.statusCode >= 400 ||
        (signResponse.body.isNotEmpty &&
            signResponse.body.contains('invalid_session_token'))) {
      await resetSessionToken();
      resolvedSessionToken = await getSessionToken();
      signResponse = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$_uploadUrlPath'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionToken': resolvedSessionToken,
          'contentType': contentType,
        }),
      );
    }

    if (signResponse.body.isEmpty) {
      throw Exception(ApiConfig.emptyResponseMessage(_uploadUrlPath));
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

    final returnedToken = signData['sessionToken']?.toString();
    if (returnedToken != null && returnedToken.isNotEmpty) {
      await saveSessionToken(returnedToken);
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
