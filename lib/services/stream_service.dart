import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import 'auth_service.dart';

class StreamService extends ChangeNotifier {
  StreamService._internal();

  static final StreamService instance = StreamService._internal();

  static const String _baseUrl =
      'https://us-central1-tradeworksai-senthil-dev-env.cloudfunctions.net/';
  static const String _cachedApiKeyPref = 'stream_api_key';

  SharedPreferences? _prefs;
  StreamChatClient? _client;
  String? _activeApiKey;
  bool _isConnecting = false;
  Future<void>? _connectInFlight;
  String? _lastError;

  StreamChatClient? get client => _client;
  bool get isReady => _client != null && _client!.state.currentUser != null;
  bool get isConnecting => _isConnecting;
  String? get lastError => _lastError;

  String? resolveMessagingUserId(Map<String, dynamic>? data) {
    if (data == null) return null;

    String? read(dynamic value) {
      final text = value?.toString().trim();
      if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
        return null;
      }
      return text;
    }

    for (final key in const [
      'userId',
      'user_id',
      'contractorUserId',
      'contractor_user_id',
      'proUserId',
      'pro_user_id',
    ]) {
      final value = read(data[key]);
      if (value != null) return value;
    }

    for (final nestedKey in const ['profile', 'pro', 'contractor']) {
      final nested = data[nestedKey];
      if (nested is! Map) continue;
      final resolved =
          resolveMessagingUserId(Map<String, dynamic>.from(nested));
      if (resolved != null) return resolved;
    }

    for (final key in const ['contractorId', 'contractor_id', 'id']) {
      final value = read(data[key]);
      if (value != null) return value;
    }

    return null;
  }

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    final cachedApiKey = _prefs?.getString(_cachedApiKeyPref);
    if (cachedApiKey != null && cachedApiKey.isNotEmpty) {
      _client ??= StreamChatClient(cachedApiKey);
    }
  }

  Future<void> ensureConnected({
    bool forceReconnect = false,
    String? withUserId,
  }) async {
    final userId = AuthService.instance.userId;
    final email = AuthService.instance.userEmail;
    if (userId == null && (email == null || email.isEmpty)) {
      return;
    }

    if (_connectInFlight != null) {
      await _connectInFlight;
      if (!forceReconnect &&
          (withUserId == null || withUserId.isEmpty) &&
          isReady) {
        return;
      }
    }

    _lastError = null;
    _isConnecting = true;
    notifyListeners();

    final future = () async {
      try {
        await initialize();

        final response = await http.post(
          Uri.parse('${_baseUrl}stream-token-v2-supabase'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            if (userId != null) 'userId': userId,
            if (email != null && email.isNotEmpty) 'email': email,
            if (withUserId != null && withUserId.isNotEmpty)
              'withUserId': withUserId,
          }),
        );

        if (response.body.isEmpty) {
          throw Exception('Empty Stream token response');
        }

        final data = jsonDecode(response.body);
        if (data is! Map<String, dynamic>) {
          throw Exception('Invalid Stream token response');
        }
        if (data['success'] != true) {
          throw Exception(data['error'] ?? 'Failed to initialize chat');
        }

        final apiKey = data['apiKey']?.toString();
        final token = data['token']?.toString();
        final streamUserId = data['userId']?.toString();
        final name =
            data['name']?.toString() ?? AuthService.instance.userName ?? 'User';

        if (apiKey == null ||
            apiKey.isEmpty ||
            token == null ||
            token.isEmpty ||
            streamUserId == null ||
            streamUserId.isEmpty) {
          throw Exception('Incomplete Stream token payload');
        }

        if (_client == null || _activeApiKey != apiKey) {
          if (_client != null) {
            try {
              await _client!.disconnectUser(flushChatPersistence: false);
            } catch (_) {}
          }
          _client = StreamChatClient(apiKey);
          _activeApiKey = apiKey;
          await _prefs?.setString(_cachedApiKeyPref, apiKey);
        }

        final currentUser = _client!.state.currentUser;
        if (forceReconnect ||
            currentUser == null ||
            currentUser.id != streamUserId) {
          if (currentUser != null) {
            try {
              await _client!.disconnectUser(flushChatPersistence: false);
            } catch (_) {}
          }
          await _client!.connectUser(
            User(
              id: streamUserId,
              name: name,
              image: AuthService.instance.pictureUrl,
            ),
            token,
          );
        }
      } catch (e) {
        _lastError = e.toString().replaceAll('Exception: ', '');
        if (kDebugMode) {
          print('StreamService connection error: $_lastError');
        }
        rethrow;
      } finally {
        _isConnecting = false;
        _connectInFlight = null;
        notifyListeners();
      }
    }();

    _connectInFlight = future;
    await future;
  }

  Future<void> disconnect() async {
    try {
      await _client?.disconnectUser(flushChatPersistence: false);
    } catch (e) {
      if (kDebugMode) {
        print('StreamService disconnect error: $e');
      }
    }
    _lastError = null;
    notifyListeners();
  }

  Future<Channel> openDirectMessageChannel({
    required String otherUserId,
    required String otherUserName,
    bool forceReconnect = false,
  }) async {
    await ensureConnected(
      forceReconnect: forceReconnect,
      withUserId: otherUserId,
    );

    final client = _client;
    if (client == null) {
      throw Exception('Chat is not available right now.');
    }

    final currentUserId = client.state.currentUser?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      throw Exception('Not connected. Please log in again.');
    }

    if (currentUserId == otherUserId) {
      throw Exception('Unable to open a conversation with this account.');
    }

    final ids = [currentUserId, otherUserId]..sort();
    final channelId = ids.join('_');

    final channel = client.channel(
      'messaging',
      id: channelId,
      extraData: {
        'name': otherUserName,
        'members': [currentUserId, otherUserId],
      },
    );
    await channel.watch();
    return channel;
  }
}
