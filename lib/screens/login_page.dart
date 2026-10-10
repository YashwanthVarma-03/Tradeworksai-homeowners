import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/app_notification.dart';
import '../widgets/transaction_guard.dart';
import 'dashboard_shell.dart';
import 'password_reset_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  final bool returnToPreviousPage;

  const LoginPage({
    super.key,
    this.returnToPreviousPage = false,
  });
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _obscure = true;
  bool _rememberMe = true;
  bool _socialOAuthPending = false;

  @override
  void initState() {
    super.initState();
    AuthService.instance.addListener(_completeSocialOAuthIfReady);
    unawaited(_loadRememberedLogin());
  }

  Future<void> _loadRememberedLogin() async {
    final auth = AuthService.instance;
    final rememberMe = await auth.loadRememberLoginPreference();
    final rememberedEmail = await auth.loadRememberedLoginEmail();
    if (!mounted) return;

    if (_email.text.isEmpty && rememberedEmail != null) {
      _email.text = rememberedEmail;
    }
    setState(() => _rememberMe = rememberMe);
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_completeSocialOAuthIfReady);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _completeSocialOAuthIfReady() {
    if (!mounted ||
        !_socialOAuthPending ||
        !AuthService.instance.isAuthenticated) {
      return;
    }
    _socialOAuthPending = false;
    if (_loading) setState(() => _loading = false);
    _completeLoginNavigation();
  }

  void _completeLoginNavigation() {
    if (!mounted) return;
    if (widget.returnToPreviousPage) {
      if (_loading) setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context, true);
      });
      return;
    }
    Navigator.pushAndRemoveUntil(
        context, createPremiumRoute(const DashboardShell()), (_) => false);
  }

  Future<void> _openSignup() async {
    if (!widget.returnToPreviousPage) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignupPage()),
      );
      return;
    }

    final signedUp = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SignupPage(returnToPreviousPage: true),
      ),
    );
    if (signedUp == true && mounted && AuthService.instance.isAuthenticated) {
      _completeLoginNavigation();
    }
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await AuthService.instance.login(
        email: _email.text.trim(),
        password: _password.text,
        rememberMe: _rememberMe,
      );
      _completeLoginNavigation();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    if (_loading) return;
    setState(() => _loading = true);
    _socialOAuthPending = true;
    try {
      await AuthService.instance
          .signInWithGoogleInteractive(rememberMe: _rememberMe);
      // On mobile, the OAuth callback arrives after the external browser
      // redirects to the app. Navigate only after Supabase creates a session.
      _completeSocialOAuthIfReady();
    } catch (e) {
      _socialOAuthPending = false;
      if (mounted) _showError(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _apple() async {
    if (_loading) return;
    setState(() => _loading = true);
    _socialOAuthPending = true;
    try {
      await AuthService.instance
          .signInWithAppleInteractive(rememberMe: _rememberMe);
      // On mobile, the OAuth callback arrives after the external browser
      // redirects to the app. Navigate only after Supabase creates a session.
      _completeSocialOAuthIfReady();
    } catch (e) {
      _socialOAuthPending = false;
      if (mounted) _showError(e);
    } finally {
      if (mounted && !AuthService.instance.isAuthenticated) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(Object e) => AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t sign you in. Check your details and try again.',
      );

  @override
  Widget build(BuildContext context) => TransactionGuard(
        isProcessing: _loading,
        blockedMessage: 'Please wait while sign-in is being completed.',
        child: Scaffold(
          backgroundColor: AppTheme.pageBackground,
          appBar: authBackBar(context),
          body: SafeArea(
            child: SingleChildScrollView(
              child: TwPage(
                top: 24,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Welcome back',
                          textAlign: TextAlign.center,
                          style: TwType.h1(context)),
                      const SizedBox(height: 6),
                      Text('Log in to manage your home and bookings.',
                          textAlign: TextAlign.center,
                          style: TwType.body(color: AppTheme.textSecondary)),
                      const SizedBox(height: 32),
                      const TwFieldLabel('Email address'),
                      TextFormField(
                          controller: _email,
                          style: TwType.body(color: AppTheme.navy),
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          enabled: !_loading,
                          decoration:
                              TwInputs.decoration(hint: 'you@example.com'),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Please enter your email'
                              : null),
                      const SizedBox(height: 18),
                      const TwFieldLabel('Password'),
                      TextFormField(
                          controller: _password,
                          style: TwType.body(color: AppTheme.navy),
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          enabled: !_loading,
                          decoration: TwInputs.decoration(
                              hint: '••••••••',
                              suffix: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20,
                                      color: AppTheme.textSecondary),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure))),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Please enter your password'
                              : null),
                      const SizedBox(height: TwSpace.s4),
                      // Wraps onto two lines on Compact or at large text
                      // sizes instead of squeezing "Forgot password?".
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                onChanged: _loading
                                    ? null
                                    : (value) => setState(
                                        () => _rememberMe = value ?? true),
                                activeColor: AppTheme.blue,
                              ),
                              Text('Remember me',
                                  style: TwType.bodySm(color: AppTheme.navy)),
                            ],
                          ),
                          TwTextAction(
                            label: 'Forgot password?',
                            onPressed: () {
                              if (_loading) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PasswordResetPage(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: TwSpace.s8),
                      TwPrimaryButton(
                        label: 'Log in',
                        onPressed: _submit,
                        loading: _loading,
                      ),
                      const SizedBox(height: 24),
                      const AuthOrDivider(),
                      const SizedBox(height: 24),
                      AuthSocialButton(
                        label: 'Continue with Apple',
                        icon: const Icon(Icons.apple,
                            color: AppTheme.navy, size: 22),
                        onPressed: _loading ? null : _apple,
                      ),
                      const SizedBox(height: TwSpace.s12),
                      AuthSocialButton(
                        label: 'Continue with Google',
                        icon: const GoogleMark(),
                        onPressed: _loading ? null : _google,
                      ),
                      const SizedBox(height: TwSpace.s40),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Don’t have an account? ',
                              style:
                                  TwType.bodySm(color: AppTheme.textSecondary)),
                          TwTextAction(
                            label: 'Sign up',
                            onPressed: () {
                              if (!_loading) _openSignup();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Back arrow for the auth screens (B05, B06): white, no title, no hairline.
/// Only shown when there is somewhere to go back to, like the old implied
/// leading button.
PreferredSizeWidget? authBackBar(BuildContext context) {
  if (!(ModalRoute.of(context)?.canPop ?? false)) return null;
  return AppBar(
    backgroundColor: AppTheme.pageBackground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    automaticallyImplyLeading: false,
    leading: IconButton(
      tooltip: 'Back',
      icon:
          const Icon(Icons.arrow_back_ios_new, size: 20, color: AppTheme.navy),
      onPressed: () => Navigator.maybePop(context),
    ),
  );
}

/// "or" with a hairline either side (B05, B06).
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(child: Divider(height: 1, color: AppTheme.cardBorder)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TwSpace.s16),
            child: Text('or', style: TwType.meta()),
          ),
          const Expanded(child: Divider(height: 1, color: AppTheme.cardBorder)),
        ],
      );
}

/// Apple / Google sign-in button: the theme's secondary (outlined) button
/// with a logo. Grows with the text size instead of clipping.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(
            label,
            textAlign: TextAlign.center,
            style: TwType.button(color: AppTheme.navy)
                .copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      );
}

/// The four-colour Google "G", drawn so no image asset is needed.
class GoogleMark extends StatelessWidget {
  const GoogleMark({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _GoogleMarkPainter()),
      );
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  // Google's brand colours: the logo is the only place these screens draw
  // colours that are not AppTheme tokens.
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.2;
    final ring = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    Paint arc(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    const deg = math.pi / 180;
    canvas.drawArc(ring, 0, 45 * deg, false, arc(_blue));
    canvas.drawArc(ring, 45 * deg, 90 * deg, false, arc(_green));
    canvas.drawArc(ring, 135 * deg, 75 * deg, false, arc(_yellow));
    canvas.drawArc(ring, 210 * deg, 105 * deg, false, arc(_red));
    final centre = size.center(Offset.zero);
    canvas.drawRect(
      Rect.fromLTRB(
        centre.dx,
        centre.dy - stroke / 2,
        size.width,
        centre.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
