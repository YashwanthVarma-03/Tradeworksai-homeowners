import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/auth_service.dart';

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  final _requestFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  
  final _resetFormKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitRequest() async {
    if (_isLoading) return;
    if (_requestFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final message = await AuthService.instance.requestPasswordReset(
          _emailController.text.trim(),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.success,
              duration: const Duration(seconds: 5),
            ),
          );
          // Auto switch tab to the reset form tab so they can input the token
          _tabController.animateTo(1);
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

  void _submitReset() async {
    if (_isLoading) return;
    if (_resetFormKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final message = await AuthService.instance.performPasswordReset(
          token: _tokenController.text.trim(),
          password: _passwordController.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: AppTheme.success,
            ),
          );
          Navigator.pop(context); // Go back to login screen
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : AppTheme.navy700),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.orange500,
          unselectedLabelColor: isDark ? Colors.white60 : AppTheme.gray,
          indicatorColor: AppTheme.orange500,
          tabs: const [
            Tab(text: 'Request Link'),
            Tab(text: 'Set Password'),
          ],
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SunriseBackground(
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              // 1. Request tab
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _requestFormKey,
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Request Reset Link',
                            style: AppTheme.textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              color: isDark ? Colors.white : AppTheme.navy700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Enter your email address and we\'ll send you a secure link carrying your reset token.',
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
                          const SizedBox(height: 28),
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(color: AppTheme.orange500),
                            )
                          else
                            HoverButton(
                              text: 'Send Reset Link',
                              onPressed: _submitRequest,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // 2. Perform reset tab
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _resetFormKey,
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Set New Password',
                            style: AppTheme.textTheme.headlineMedium?.copyWith(
                              fontSize: 18,
                              color: isDark ? Colors.white : AppTheme.navy700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Type the token received in your email and enter your new password.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : AppTheme.gray,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Reset Token',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _tokenController,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Paste token from email link',
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
                                return 'Please enter your reset token';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'New Password',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              hintText: 'Min 6 characters',
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
                              if (val == null || val.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 28),
                          if (_isLoading)
                            const Center(
                              child: CircularProgressIndicator(color: AppTheme.orange500),
                            )
                          else
                            HoverButton(
                              text: 'Update Password',
                              onPressed: _submitReset,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
