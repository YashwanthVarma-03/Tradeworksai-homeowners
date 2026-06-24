import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import 'dashboard_shell.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Mock validation bypass - accept any inputs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification check bypassed. Welcome back!'),
          backgroundColor: AppTheme.success,
        ),
      );

      // Navigate to dashboard as root
      Navigator.pushAndRemoveUntil(
        context,
        createPremiumRoute(const DashboardShell()),
        (route) => false,
      );
    }
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
                          const Text(
                            'Password',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
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
                          const SizedBox(height: 28),
                          HoverButton(
                            text: 'Log In',
                            onPressed: _submit,
                          ),
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
