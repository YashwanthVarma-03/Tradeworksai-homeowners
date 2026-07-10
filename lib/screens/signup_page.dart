import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/auth_service.dart';
import 'auth/onboarding.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
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
        await AuthService.instance.signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Welcome to TradeWorksAI.'),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            createPremiumRoute(const OnboardingScreen()),
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

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signInWithGoogleInteractive();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        createPremiumRoute(const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme:
            IconThemeData(color: isDark ? Colors.white : AppTheme.navy700),
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
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
                            'Homeowner Sign Up',
                            style: AppTheme.textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              color: isDark ? Colors.white : AppTheme.navy700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create a free profile to book pre-vetted local pros and track jobs.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : AppTheme.gray,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Full Name',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'e.g. Yashwanth Varma',
                              hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white38 : AppTheme.gray,
                                  fontSize: 13),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E2E4A)
                                  : AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Email Address',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'e.g. yashwanth@example.com',
                              hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white38 : AppTheme.gray,
                                  fontSize: 13),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E2E4A)
                                  : AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              // Simple email structure regex
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(val.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Password',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Min 6 characters',
                              hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white38 : AppTheme.gray,
                                  fontSize: 13),
                              filled: true,
                              fillColor: isDark
                                  ? const Color(0xFF1E2E4A)
                                  : AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: AppTheme.gray,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          if (_isLoading)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: CircularProgressIndicator(
                                    color: AppTheme.orange500),
                              ),
                            )
                          else
                            Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _signInWithGoogle,
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 48),
                                    side:
                                        const BorderSide(color: AppTheme.line),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.g_mobiledata,
                                      size: 28, color: AppTheme.navy700),
                                  label: const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                        color: AppTheme.navy700,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                HoverButton(
                                  text: 'Create Account',
                                  onPressed: _submit,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                              color: isDark ? Colors.white70 : AppTheme.gray,
                              fontSize: 13.5),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (_isLoading) return;
                            Navigator.pushReplacement(
                              context,
                              createPremiumRoute(const LoginPage()),
                            );
                          },
                          child: const Text(
                            'Log In',
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
