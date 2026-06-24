import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/auth_service.dart';
import 'dashboard_shell.dart';
import 'signup_page.dart';
import 'password_reset_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await AuthService.instance.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Log in successful! Welcome back.'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            createPremiumRoute(const DashboardShell()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _signInWithGoogle() {
    if (_isLoading) return;
    final tokenController = TextEditingController(
      text: '71668222585-50stjb9s6ias4g5su87fsmdiaikh4iec.apps.googleusercontent.com',
    );
    final parentContext = context;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Sign-in (Dev Mode)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'In production, native Google Sign-in obtains a JWT token. Enter or use the dev token below to call the real backend API:',
              style: TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: 'Google Credential Token',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              await AuthService.instance.simulateGoogleSignInSuccess();
              if (parentContext.mounted) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Demo Bypass Successful! Welcome.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                Navigator.pushAndRemoveUntil(
                  parentContext,
                  createPremiumRoute(const DashboardShell()),
                  (route) => false,
                );
              }
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            child: const Text(
              'Demo Bypass',
              style: TextStyle(color: AppTheme.orange500, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });
              try {
                await AuthService.instance.googleSignIn(tokenController.text.trim());
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('Google Sign-In successful!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                  Navigator.pushAndRemoveUntil(
                    parentContext,
                    createPremiumRoute(const DashboardShell()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (parentContext.mounted) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              }
            },
            child: const Text('Connect API'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppTheme.navy700),
      ),
      extendBodyBehindAppBar: true,
      body: SunriseBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.tradeworksai.com/images/bot%7Bfavicon%7D.png',
                          height: 40,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.smart_toy,
                            color: AppTheme.orange500,
                            size: 40,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TradeWorksAI',
                          style: AppTheme.headingStyle.copyWith(
                            color: isDark ? Colors.white : AppTheme.navy700,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Homeowner Log In',
                            style: AppTheme.textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              color: isDark ? Colors.white : AppTheme.navy700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your credentials to manage your home maintenance bookings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : AppTheme.gray,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Email Address',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'e.g. yashwanth@example.com',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : AppTheme.gray, fontSize: 13),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E2E4A) : AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Password',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                              ),
                              GestureDetector(
                                onTap: () {
                                  if (_isLoading) return;
                                  Navigator.push(
                                    context,
                                    createPremiumRoute(const PasswordResetPage()),
                                  );
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppTheme.orange500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : AppTheme.gray, fontSize: 13),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E2E4A) : AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: CircularProgressIndicator(color: AppTheme.orange500),
                              ),
                            )
                          else ...[
                            HoverButton(
                              text: 'Log In',
                              onPressed: _submit,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: _signInWithGoogle,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 44),
                                side: const BorderSide(color: AppTheme.line),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://www.google.com/favicon.ico',
                                    height: 16,
                                    errorBuilder: (c, e, s) => const Icon(Icons.g_mobiledata, color: Colors.blue),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Sign in with Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white : AppTheme.navy700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(color: isDark ? Colors.white70 : AppTheme.gray, fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_isLoading) return;
                            Navigator.pushReplacement(
                              context,
                              createPremiumRoute(const SignupPage()),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppTheme.orange500,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
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
}
