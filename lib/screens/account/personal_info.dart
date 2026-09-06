import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/app_error_utils.dart';
import '../../widgets/offline_state.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _originalName = '';
  String _originalPhone = '';
  String _originalEmail = '';
  String _preferredContact = 'email';
  bool _marketingConsent = false;

  bool get _hasChanges =>
      _nameController.text.trim() != _originalName ||
      _phoneController.text.trim() != _originalPhone ||
      _emailController.text.trim() != _originalEmail;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _phoneController.addListener(_onFieldChanged);
    _emailController.addListener(_onFieldChanged);
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resp = await HomeownerService.instance.fetchProfile();
      final profile = _asMap(resp['profile']);
      final given = _string(profile['givenName']) ??
          _string(AuthService.instance.givenName) ??
          '';
      final family = _string(profile['familyName']) ??
          _string(AuthService.instance.familyName) ??
          '';
      final name = _string(profile['name']) ??
          _string(profile['userName']) ??
          [given, family].where((part) => part.isNotEmpty).join(' ');
      final phone = _string(profile['phone']) ??
          _string(AuthService.instance.assignedPhoneNumber) ??
          '';
      final email = _string(profile['email']) ??
          _string(AuthService.instance.userEmail) ??
          '';

      if (!mounted) return;
      setState(() {
        _originalName = name;
        _originalPhone = phone;
        _originalEmail = email;
        _preferredContact = _string(profile['preferredContact']) ?? 'email';
        _marketingConsent = profile['marketingConsent'] == true;
        _nameController.text = name;
        _phoneController.text = phone;
        _emailController.text = email;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_hasChanges || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final parts = _nameController.text.trim().split(RegExp(r'\s+'));
      final givenName = parts.isEmpty ? '' : parts.first;
      final familyName = parts.length > 1 ? parts.skip(1).join(' ') : '';
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final userName = _nameController.text.trim();

      await HomeownerService.instance.updateProfile(
        givenName: givenName,
        familyName: familyName,
        phone: phone,
        email: email,
        userName: userName,
        preferredContact: _preferredContact,
        marketingConsent: _marketingConsent,
      );
      await AuthService.instance.updateCachedProfile(
        givenName: givenName,
        familyName: familyName,
        phone: phone,
        email: email,
        userName: userName,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorUtils.friendlyMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _shell(
        child: const Center(
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      );
    }
    if (_errorMessage != null) {
      return _shell(
        child: OfflineState(onRetry: _loadProfile, message: _errorMessage),
      );
    }

    return _shell(
      bottom: _saveBar(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 124),
          children: [
            _fieldLabel('Full name'),
            _textField(
              controller: _nameController,
              keyboardType: TextInputType.name,
              validator: (value) =>
                  _string(value) == null ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            _fieldLabel('Email'),
            _textField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                final email = _string(value);
                if (email == null) return 'Email is required';
                if (!email.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _fieldLabel('Phone'),
            _textField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _infoCallout(
              text:
                  'Changing your email will require re-verification before your next booking.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _shell({required Widget child, Widget? bottom}) {
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: _appBar('Personal info'),
      body: child,
      bottomNavigationBar: bottom,
    );
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      toolbarHeight: 56,
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        color: AppTheme.navy700,
        onPressed: () => Navigator.pop(context, _hasChanges),
      ),
      titleSpacing: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy700,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _lineSoft),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: _inkStrong,
          fontSize: 13.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: _inkStrong,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: _lineSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppTheme.teal500, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: AppTheme.error),
        ),
      ),
    );
  }

  Widget _infoCallout({required String text}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.orange500),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_up_rounded,
            color: AppTheme.orange500,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _inkStrong,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _lineSoft)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                disabledBackgroundColor: AppTheme.orange500.withOpacity(0.45),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save changes',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _hasChanges
                ? 'Review your changes before saving'
                : 'Save is enabled once something changes',
            style: const TextStyle(
              color: _mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }
}
