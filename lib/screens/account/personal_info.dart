import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
import '../../utils/app_error_utils.dart';
import '../../widgets/offline_state.dart';
import '../../widgets/transaction_guard.dart';
import '../../widgets/app_notification.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  static const Color _pageBackground = AppTheme.pageBackground;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  String _originalName = '';
  String _originalPhone = '';
  String _originalEmail = '';

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
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resp = await HomeownerService.instance.fetchAccount();
      final profile = _asMap(resp['account']?['details']);
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
    if (_isSaving || !_hasChanges || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      final parts = _nameController.text.trim().split(RegExp(r'\s+'));
      final givenName = parts.isEmpty ? '' : parts.first;
      final familyName = parts.length > 1 ? parts.skip(1).join(' ') : '';
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();
      final userName = _nameController.text.trim();

      final emailChanged = email.toLowerCase() != _originalEmail.toLowerCase();
      if (emailChanged) {
        await HomeownerService.instance
            .changeAccountEmail(email, _passwordController.text);
      }
      await HomeownerService.instance.updateAccountDetails({
        'name': userName,
        'givenName': givenName,
        'familyName': familyName,
        'phone': phone,
      });
      await AuthService.instance.updateCachedProfile(
        givenName: givenName,
        familyName: familyName,
        phone: phone,
        email: _originalEmail,
        userName: userName,
      );

      if (!mounted) return;
      if (emailChanged)
        AppNotification.showInfo(context,
            'Check your email to confirm the change. Your sign-in email stays the same until confirmation.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppNotification.showError(
        context,
        e,
        fallback:
            'We couldn\'t save your personal information. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _shell(
        child: const SkeletonPage(layout: SkeletonLayout.form),
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
        child: SingleChildScrollView(
          child: TwPage(
            top: TwSpace.s20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TwFieldLabel('Full name'),
                _textField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (value) =>
                      _string(value) == null ? 'Full name is required' : null,
                ),
                const SizedBox(height: TwSpace.s16),
                const TwFieldLabel('Email'),
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
                const SizedBox(height: TwSpace.s16),
                const TwFieldLabel('Phone'),
                _textField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: TwSpace.s8),
                Text(
                  'For your account and TradeWorks support. Pros never see your '
                  'phone number.',
                  style: TwType.caption(),
                ),
                if (_emailController.text.trim() != _originalEmail) ...[
                  const SizedBox(height: TwSpace.s16),
                  const TwFieldLabel('Current password (password accounts)'),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    style: TwType.body(color: AppTheme.navy),
                    decoration: TwInputs.decoration(),
                  ),
                ],
                const SizedBox(height: TwSpace.s20),
                _infoCallout(
                  text:
                      'Email changes require confirmation. Password accounts must enter their current password; Apple and Google accounts may need to sign in again.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _shell({required Widget child, Widget? bottom}) {
    return TransactionGuard(
      isProcessing: _isSaving,
      blockedMessage:
          'Please wait while your personal information is being saved.',
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: TwAppBar(
          title: 'Personal info',
          onBack: () => Navigator.pop(context, _hasChanges),
        ),
        body: child,
        bottomNavigationBar: bottom,
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
      style: TwType.body(color: AppTheme.navy),
      decoration: TwInputs.decoration(),
    );
  }

  Widget _infoCallout({required String text}) {
    return TwFactPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppTheme.navy,
            size: 20,
          ),
          const SizedBox(width: TwSpace.s12),
          Expanded(
            child: Text(text, style: TwType.bodySm()),
          ),
        ],
      ),
    );
  }

  /// F03 sticky bar: one orange button (navy label, navy spinner) and the
  /// enable hint.
  Widget _saveBar() {
    return TwStickyBar(
      note: _hasChanges
          ? 'Review your changes before saving'
          : 'Save is enabled once something changes',
      noteBelow: true,
      children: [
        TwPrimaryButton(
          label: 'Save changes',
          loading: _isSaving,
          onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
        ),
      ],
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
