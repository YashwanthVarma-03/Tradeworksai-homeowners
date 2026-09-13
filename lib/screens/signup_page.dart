import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/app_notification.dart';
import 'dashboard_shell.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _obscure = true;
  bool _googleOAuthPending = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_completeGoogleOAuthIfReady);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_completeGoogleOAuthIfReady);
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _completeGoogleOAuthIfReady() {
    if (!mounted || !_googleOAuthPending || !AuthService.instance.isAuthenticated) {
      return;
    }
    _googleOAuthPending = false;
    if (_loading) setState(() => _loading = false);
    _openDashboard();
  }

  void _openDashboard() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context, createPremiumRoute(const DashboardShell()), (_) => false);
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.signUp(
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text);
      // The old required onboarding/profile setup is intentionally removed.
      _openDashboard();
    } catch (e) {
      if (mounted) _error(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    _googleOAuthPending = true;
    try {
      await AuthService.instance.signInWithGoogleInteractive();
      _completeGoogleOAuthIfReady();
    } catch (e) {
      _googleOAuthPending = false;
      if (mounted) _error(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  void _error(Object e) => AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t create your account. Please try again.',
      );
  InputDecoration _field(String hint, {Widget? suffix}) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD9E2EC))));
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
          child: Center(
              child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                      key: _formKey,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Create your account',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: AppTheme.navy700,
                                    fontSize: 29,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            const Text(
                                'Book trusted local pros and keep every job in one place.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Color(0xFF64748B), fontSize: 15)),
                            const SizedBox(height: 24),
                            const Text('Full name',
                                style: TextStyle(
                                    color: AppTheme.ink, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                                controller: _name,
                                enabled: !_loading,
                                textCapitalization: TextCapitalization.words,
                                decoration: _field('Your name'),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Please enter your name'
                                    : null),
                            const SizedBox(height: 16),
                            const Text('Email address',
                                style: TextStyle(
                                    color: AppTheme.ink, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                                controller: _email,
                                enabled: !_loading,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _field('you@example.com'),
                                validator: (v) => v == null ||
                                        !RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}\$')
                                            .hasMatch(v.trim())
                                    ? 'Please enter a valid email'
                                    : null),
                            const SizedBox(height: 16),
                            const Text('Password',
                                style: TextStyle(
                                    color: AppTheme.ink, fontSize: 13)),
                            const SizedBox(height: 8),
                            TextFormField(
                                controller: _password,
                                enabled: !_loading,
                                obscureText: _obscure,
                                decoration: _field('6+ characters',
                                    suffix: IconButton(
                                        icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_outlined
                                                : Icons.visibility_outlined,
                                            color: const Color(0xFF64748B)),
                                        onPressed: () => setState(
                                            () => _obscure = !_obscure))),
                                validator: (v) => v == null || v.length < 6
                                    ? 'Password must be at least 6 characters'
                                    : null),
                            const SizedBox(height: 16),
                            SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                    onPressed: _loading ? null : _submit,
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.orange500,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14))),
                                    child: _loading
                                        ? const CircularProgressIndicator(
                                            color: Colors.white)
                                        : const Text('Create account',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 15)))),
                            const SizedBox(height: 20),
                            const Row(children: [
                              Expanded(child: Divider()),
                              Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('or',
                                      style:
                                          TextStyle(color: Color(0xFF64748B)))),
                              Expanded(child: Divider())
                            ]),
                            const SizedBox(height: 20),
                            SizedBox(
                                height: 54,
                                child: OutlinedButton.icon(
                                    onPressed: _loading ? null : _google,
                                    icon: const Text('G',
                                        style: TextStyle(
                                            color: AppTheme.teal500,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900)),
                                    label: const Text('Continue with Google',
                                        style: TextStyle(
                                            color: AppTheme.navy700,
                                            fontWeight: FontWeight.w800)),
                                    style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        side: const BorderSide(
                                            color: Color(0xFFD9E2EC))))),
                            const SizedBox(height: 30),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('Already have an account? ',
                                      style:
                                          TextStyle(color: Color(0xFF64748B))),
                                  InkWell(
                                      onTap: _loading
                                          ? null
                                          : () => Navigator.pushReplacement(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      const LoginPage())),
                                      child: const Text('Log in',
                                          style: TextStyle(
                                              color: AppTheme.orange500,
                                              fontWeight: FontWeight.w900)))
                                ])
                          ]))))));
}
