import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();

  AuthService._internal();

  static const String baseUrl = 'https://us-central1-tradeworksai-senthil-dev-env.cloudfunctions.net/';

  SharedPreferences? _prefs;

  // Cached state variables
  bool _isAuthenticated = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _givenName;
  String? _familyName;
  String? _pictureUrl;
  String? _googleSub;
  String? _roleAssigned;
  String? _agentId;
  String? _assignedPhoneNumber;
  bool? _textMessage;
  bool? _whatsapp;

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get givenName => _givenName;
  String? get familyName => _familyName;
  String? get pictureUrl => _pictureUrl;
  String? get googleSub => _googleSub;
  String? get roleAssigned => _roleAssigned;
  String? get agentId => _agentId;
  String? get assignedPhoneNumber => _assignedPhoneNumber;
  bool? get textMessage => _textMessage;
  bool? get whatsapp => _whatsapp;

  // Initialize and load session from SharedPreferences
  Future<void> loadSession() async {
    _prefs = await SharedPreferences.getInstance();
    
    _isAuthenticated = _prefs?.getBool('isAuthenticated') ?? false;
    _userId = _prefs?.getString('userId');
    _userEmail = _prefs?.getString('userEmail');
    _userName = _prefs?.getString('userName');
    _givenName = _prefs?.getString('givenName');
    _familyName = _prefs?.getString('familyName');
    _pictureUrl = _prefs?.getString('pictureUrl');
    _googleSub = _prefs?.getString('google_sub');
    _roleAssigned = _prefs?.getString('role_assigned');
    _agentId = _prefs?.getString('agentId');
    _assignedPhoneNumber = _prefs?.getString('assigned_phone_number');
    _textMessage = _prefs?.getBool('text_message');
    _whatsapp = _prefs?.getBool('whatsapp');
    
    notifyListeners();
  }

  // Handle common HTTP POST requests with standard headers
  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (response.body.isEmpty) {
        throw Exception('Received empty response from server.');
      }
      
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format.');
      }
      
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Auth POST Error on $path: $e');
      }
      throw Exception('Network error. Please check your connection and try again.');
    }
  }

  // Sign up — `/email-signup-v2-supabase`
  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _post('email-signup-v2-supabase', {
      'name': name,
      'email': email,
      'password': password,
    });

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Sign up failed.');
    }

    String? id = response['userId']?.toString() ?? response['id']?.toString();
    
    // Gotcha fallback (Section 4.1 of guide):
    // If signup success but userId is omitted, immediately perform a login call.
    if (id == null) {
      await login(email: email, password: password);
    } else {
      // Save session details from signup response
      await _saveSession(
        userId: id,
        email: email,
        name: response['name'] ?? name,
        agentId: response['agentId']?.toString(),
        roleAssigned: 'homeowner', // Default role for signup
      );
    }
  }

  // Log in — `/email-signin-v2-supabase`
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('email-signin-v2-supabase', {
      'email': email,
      'password': password,
    });

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Invalid email or password.');
    }

    // Resolve userId defensively (Section 4.2 of guide)
    final id = response['userId']?.toString() ?? 
               response['id']?.toString() ?? 
               response['data']?['userId']?.toString();
               
    if (id == null) {
      throw Exception('User ID could not be resolved from auth response.');
    }

    // Resolve roles
    String role = 'homeowner';
    final roles = response['role_assigned'];
    if (roles is List && roles.isNotEmpty) {
      role = roles.first.toString();
    } else if (roles != null) {
      role = roles.toString();
    }

    await _saveSession(
      userId: id,
      email: response['email'] ?? email,
      name: response['name'] ?? response['given_name'] ?? 'Homeowner',
      givenName: response['given_name'],
      familyName: response['family_name'],
      pictureUrl: response['picture_url'],
      googleSub: response['google_sub']?.toString(),
      roleAssigned: role,
      agentId: response['agentId']?.toString(),
      assignedPhoneNumber: response['assigned_phone_number']?.toString(),
      textMessage: response['text_message'] == true,
      whatsapp: response['whatsapp'] == true,
    );
  }

  // Google Sign-In — `/google-signup-v2-supabase`
  Future<void> googleSignIn(String credential) async {
    final response = await _post('google-signup-v2-supabase', {
      'credential': credential,
    });

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Google Sign-In failed.');
    }

    // Nested fields under "data" (Section 4.3 of guide)
    final data = response['data'];
    if (data == null || data is! Map<String, dynamic>) {
      throw Exception('Google Sign-In response did not contain user data.');
    }

    final id = data['userId']?.toString() ?? data['id']?.toString();
    if (id == null) {
      throw Exception('User ID could not be resolved from Google auth response.');
    }

    String role = 'homeowner';
    final roles = data['role_assigned'];
    if (roles is List && roles.isNotEmpty) {
      role = roles.first.toString();
    }

    await _saveSession(
      userId: id,
      email: data['email'],
      name: data['name'] ?? 'Google User',
      pictureUrl: data['picture_url'],
      googleSub: data['google_sub']?.toString(),
      roleAssigned: role,
      agentId: data['elevenlabs_agent_id']?.toString() ?? data['agentId']?.toString(),
      assignedPhoneNumber: data['assigned_phone_number']?.toString(),
      textMessage: data['text_message'] == true,
      whatsapp: data['whatsapp'] == true,
    );
  }

  // Simulate successful Google Sign-in for demo bypass
  Future<void> simulateGoogleSignInSuccess() async {
    await _saveSession(
      userId: '999',
      email: 'demo.homeowner@gmail.com',
      name: 'Demo Homeowner',
      pictureUrl: 'https://lh3.googleusercontent.com/a/default-user=s96-c',
      roleAssigned: 'homeowner',
      assignedPhoneNumber: '(813) 555-9999',
      textMessage: true,
      whatsapp: false,
    );
  }

  // Request Password Reset Link — `/wix-password-reset-request-v2-supabase`
  Future<String> requestPasswordReset(String email) async {
    final response = await _post('wix-password-reset-request-v2-supabase', {
      'email': email,
    });

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to send password reset link.');
    }

    return response['message'] ?? 'Password reset link sent. Check your email.';
  }

  // Perform Password Reset — `/wix-perform-password-reset-v2-supabase`
  Future<String> performPasswordReset({
    required String token,
    required String password,
  }) async {
    final response = await _post('wix-perform-password-reset-v2-supabase', {
      'token': token,
      'password': password,
    });

    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Password reset failed.');
    }

    return response['message'] ?? 'Your password has been reset. You can now log in.';
  }

  // Logout
  Future<void> logout() async {
    _isAuthenticated = false;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _givenName = null;
    _familyName = null;
    _pictureUrl = null;
    _googleSub = null;
    _roleAssigned = null;
    _agentId = null;
    _assignedPhoneNumber = null;
    _textMessage = null;
    _whatsapp = null;

    if (_prefs != null) {
      await _prefs!.clear();
    }

    notifyListeners();
  }

  // Save session to SharedPreferences
  Future<void> _saveSession({
    required String userId,
    required String email,
    required String name,
    String? givenName,
    String? familyName,
    String? pictureUrl,
    String? googleSub,
    required String roleAssigned,
    String? agentId,
    String? assignedPhoneNumber,
    bool textMessage = false,
    bool whatsapp = false,
  }) async {
    _isAuthenticated = true;
    _userId = userId;
    _userEmail = email;
    _userName = name;
    _givenName = givenName ?? name.split(' ').first;
    _familyName = familyName ?? (name.split(' ').length > 1 ? name.split(' ').last : '');
    _pictureUrl = pictureUrl;
    _googleSub = googleSub;
    _roleAssigned = roleAssigned;
    _agentId = agentId;
    _assignedPhoneNumber = assignedPhoneNumber;
    _textMessage = textMessage;
    _whatsapp = whatsapp;

    if (_prefs != null) {
      await _prefs!.setBool('isAuthenticated', true);
      await _prefs!.setString('userId', userId);
      await _prefs!.setString('userEmail', email);
      await _prefs!.setString('userName', name);
      await _prefs!.setString('givenName', _givenName!);
      await _prefs!.setString('familyName', _familyName!);
      if (pictureUrl != null) await _prefs!.setString('pictureUrl', pictureUrl);
      if (googleSub != null) await _prefs!.setString('google_sub', googleSub);
      await _prefs!.setString('role_assigned', roleAssigned);
      if (agentId != null) await _prefs!.setString('agentId', agentId);
      if (assignedPhoneNumber != null) await _prefs!.setString('assigned_phone_number', assignedPhoneNumber);
      await _prefs!.setBool('text_message', textMessage);
      await _prefs!.setBool('whatsapp', whatsapp);
      await _prefs!.setString('loginTimestamp', DateTime.now().toIso8601String());
    }

    notifyListeners();
  }
}
