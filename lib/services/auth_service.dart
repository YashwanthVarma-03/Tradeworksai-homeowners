import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'stream_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  bool isTesting = false;
  static const String googleClientId =
      '71668222585-50stjb9s6ias4g5su87fsmdiaikh4iec.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: googleClientId,
  );

  SharedPreferences? _prefs;
  StreamSubscription<AuthState>? _authSubscription;

  bool _isAuthenticated = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _givenName;
  String? _familyName;
  String? _pictureUrl;
  String? _googleSub;
  String? _accessToken;
  String? _roleAssigned;
  String? _agentId;
  String? _assignedPhoneNumber;
  bool? _textMessage;
  bool? _whatsapp;

  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get givenName => _givenName;
  String? get familyName => _familyName;
  String? get pictureUrl => _pictureUrl;
  String? get googleSub => _googleSub;
  String? get accessToken => _accessToken;
  String? get roleAssigned => _roleAssigned;
  String? get agentId => _agentId;
  String? get assignedPhoneNumber => _assignedPhoneNumber;
  bool? get textMessage => _textMessage;
  bool? get whatsapp => _whatsapp;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> loadSession() async {
    _prefs = await SharedPreferences.getInstance();
    await _syncFromSession(_client.auth.currentSession);
    _bindAuthListener();
  }

  void _bindAuthListener() {
    _authSubscription ??= _client.auth.onAuthStateChange.listen((state) async {
      if (state.event == AuthChangeEvent.signedOut || state.session == null) {
        await _clearSession(notify: true);
        return;
      }
      await _syncFromSession(state.session);
    });
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'name': name,
        'full_name': name,
      },
    );

    if (response.user == null) {
      throw Exception('Sign up failed.');
    }

    if (response.session != null) {
      await _syncFromSession(response.session);
      return;
    }

    final signInResponse = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (signInResponse.session == null) {
      throw Exception(
        'Account created, but no session was returned. Please verify your email and log in.',
      );
    }
    await _syncFromSession(signInResponse.session);
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.session == null) {
      throw Exception('Invalid email or password.');
    }

    await _syncFromSession(response.session);
  }

  Future<void> googleSignIn({
    required String idToken,
    required String accessToken,
  }) async {
    final response = await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    if (response.session == null) {
      throw Exception('Google Sign-In did not return a session.');
    }
    await _syncFromSession(response.session);
  }

  Future<void> signInWithGoogleInteractive() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw Exception('Google sign-in was cancelled.');
    }

    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    final idToken = auth.idToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google did not return an access token.');
    }
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Google did not return an ID token.');
    }

    await googleSignIn(
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> simulateGoogleSignInSuccess() async {
    throw UnsupportedError(
      'Demo sign-in is disabled. Use the real Supabase-backed sign-in flow.',
    );
  }

  Future<String> requestPasswordReset(String email) async {
    await storePendingPasswordResetEmail(email);
    await _client.auth.resetPasswordForEmail(email);
    return 'Password reset email sent. Check your inbox for the verification code or reset link.';
  }

  Future<String> performPasswordReset({
    required String token,
    required String password,
  }) async {
    final email = _prefs?.getString('pendingPasswordResetEmail');
    if (email == null || email.isEmpty) {
      throw Exception('Request a reset link first so the app knows which email to verify.');
    }

    final response = await _client.auth.verifyOTP(
      type: OtpType.recovery,
      token: token,
      email: email,
    );
    if (response.session == null) {
      throw Exception('Reset code is invalid or expired.');
    }

    await _client.auth.updateUser(
      UserAttributes(password: password),
    );
    await _syncFromSession(_client.auth.currentSession);
    await _prefs?.remove('pendingPasswordResetEmail');
    return 'Your password has been reset. You can now log in.';
  }

  Future<void> logout() async {
    await _clearSession(notify: false);
    try {
      await _client.auth.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await StreamService.instance.disconnect();
    notifyListeners();
  }

  Future<void> updateCachedProfile({
    required String givenName,
    required String familyName,
    required String phone,
    required String email,
    required String userName,
  }) async {
    _givenName = givenName;
    _familyName = familyName;
    _assignedPhoneNumber = phone;
    _userEmail = email;
    _userName = userName;

    if (_prefs != null) {
      await _prefs!.setString('givenName', givenName);
      await _prefs!.setString('familyName', familyName);
      await _prefs!.setString('assigned_phone_number', phone);
      await _prefs!.setString('userEmail', email);
      await _prefs!.setString('userName', userName);
      await _prefs!.setString('email', email);
      await _prefs!.setString('name', userName);
    }
    notifyListeners();
  }

  Future<void> storePendingPasswordResetEmail(String email) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString('pendingPasswordResetEmail', email);
  }

  Future<void> _syncFromSession(Session? session) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (session == null) {
      await _clearSession(notify: true);
      return;
    }

    final user = session.user;
    final appMeta = user.appMetadata;
    final userMeta = user.userMetadata ?? const {};

    final resolvedUserId = _readString(appMeta['legacy_id']) ??
        _readString(userMeta['legacy_id']) ??
        user.id;
    final resolvedEmail = user.email ?? _prefs?.getString('userEmail') ?? '';
    final resolvedName = _readString(userMeta['name']) ??
        _readString(userMeta['full_name']) ??
        _prefs?.getString('userName') ??
        resolvedEmail.split('@').first;
    final resolvedRoles = _readRoles(appMeta['roles']);
    final givenName = _readString(userMeta['given_name']) ??
        (resolvedName.contains(' ') ? resolvedName.split(' ').first : resolvedName);
    final familyName = _readString(userMeta['family_name']) ??
        (resolvedName.contains(' ') ? resolvedName.split(' ').skip(1).join(' ') : '');
    final avatarUrl = _readString(userMeta['picture']) ??
        _readString(userMeta['picture_url']) ??
        _readString(userMeta['avatar_url']);
    final googleSub = _readString(userMeta['sub']);
    final phone = _readString(user.phone) ??
        _readString(userMeta['phone']) ??
        _prefs?.getString('assigned_phone_number');

    _isAuthenticated = true;
    _userId = resolvedUserId;
    _userEmail = resolvedEmail;
    _userName = resolvedName;
    _givenName = givenName;
    _familyName = familyName;
    _pictureUrl = avatarUrl;
    _googleSub = googleSub;
    _accessToken = session.accessToken;
    _roleAssigned = resolvedRoles.isEmpty ? 'homeowner' : resolvedRoles.first;
    _agentId = _readString(appMeta['agent_id']) ??
        _readString(appMeta['agentId']) ??
        _prefs?.getString('agentId');
    _assignedPhoneNumber = phone;
    _textMessage = _readBool(userMeta['text_message']) ?? _textMessage;
    _whatsapp = _readBool(userMeta['whatsapp']) ?? _whatsapp;

    await _persistLegacySessionKeys(
      userId: resolvedUserId,
      email: resolvedEmail,
      name: resolvedName,
      givenName: givenName,
      familyName: familyName,
      pictureUrl: avatarUrl,
      googleSub: googleSub,
      accessToken: session.accessToken,
      roles: resolvedRoles,
      agentId: _agentId,
      assignedPhoneNumber: phone,
      textMessage: _textMessage ?? false,
      whatsapp: _whatsapp ?? false,
    );

    if (!isTesting) {
      try {
        await StreamService.instance.ensureConnected(forceReconnect: true);
      } catch (e) {
        if (kDebugMode) {
          print('Stream Chat connect error: $e');
        }
      }
    }

    notifyListeners();
  }

  Future<void> _persistLegacySessionKeys({
    required String userId,
    required String email,
    required String name,
    required String givenName,
    required String familyName,
    String? pictureUrl,
    String? googleSub,
    String? accessToken,
    required List<String> roles,
    String? agentId,
    String? assignedPhoneNumber,
    required bool textMessage,
    required bool whatsapp,
  }) async {
    if (_prefs == null) return;
    await _prefs!.setBool('isAuthenticated', true);
    await _prefs!.setString('userId', userId);
    await _prefs!.setString('email', email);
    await _prefs!.setString('userEmail', email);
    await _prefs!.setString('name', name);
    await _prefs!.setString('userName', name);
    await _prefs!.setString('givenName', givenName);
    await _prefs!.setString('familyName', familyName);
    await _prefs!.setString('role_assigned', roles.isEmpty ? 'homeowner' : roles.first);
    await _prefs!.setString('userRoles', roles.toString());
    await _prefs!.setString('loginTimestamp', DateTime.now().toIso8601String());
    if (pictureUrl != null && pictureUrl.isNotEmpty) {
      await _prefs!.setString('pictureUrl', pictureUrl);
    } else {
      await _prefs!.remove('pictureUrl');
    }
    if (googleSub != null && googleSub.isNotEmpty) {
      await _prefs!.setString('google_sub', googleSub);
    } else {
      await _prefs!.remove('google_sub');
    }
    if (accessToken != null && accessToken.isNotEmpty) {
      await _prefs!.setString('accessToken', accessToken);
    } else {
      await _prefs!.remove('accessToken');
    }
    if (agentId != null && agentId.isNotEmpty) {
      await _prefs!.setString('agentId', agentId);
    }
    if (assignedPhoneNumber != null && assignedPhoneNumber.isNotEmpty) {
      await _prefs!.setString('assigned_phone_number', assignedPhoneNumber);
    }
    await _prefs!.setBool('text_message', textMessage);
    await _prefs!.setBool('whatsapp', whatsapp);
  }

  Future<void> _clearSession({required bool notify}) async {
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _givenName = null;
    _familyName = null;
    _pictureUrl = null;
    _googleSub = null;
    _accessToken = null;
    _roleAssigned = null;
    _agentId = null;
    _assignedPhoneNumber = null;
    _textMessage = null;
    _whatsapp = null;

    if (_prefs != null) {
      await _prefs!.remove('isAuthenticated');
      await _prefs!.remove('userId');
      await _prefs!.remove('email');
      await _prefs!.remove('userEmail');
      await _prefs!.remove('name');
      await _prefs!.remove('userName');
      await _prefs!.remove('givenName');
      await _prefs!.remove('familyName');
      await _prefs!.remove('pictureUrl');
      await _prefs!.remove('google_sub');
      await _prefs!.remove('accessToken');
      await _prefs!.remove('role_assigned');
      await _prefs!.remove('userRoles');
      await _prefs!.remove('agentId');
      await _prefs!.remove('assigned_phone_number');
      await _prefs!.remove('text_message');
      await _prefs!.remove('whatsapp');
      await _prefs!.remove('loginTimestamp');
    }

    if (notify) {
      notifyListeners();
    }
  }

  List<String> _readRoles(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    final single = _readString(value);
    if (single == null || single.isEmpty) {
      return const ['homeowner'];
    }
    return [single];
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    final text = _readString(value)?.toLowerCase();
    if (text == 'true') return true;
    if (text == 'false') return false;
    return null;
  }
}
