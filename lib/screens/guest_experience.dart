import 'package:flutter/material.dart';

import '../theme.dart';

/// The signed-out treatment for tabs that require an account.
class GuestGateTab extends StatelessWidget {
  const GuestGateTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppTheme.pageBackground,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                    color: AppTheme.subtle,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppTheme.navy, size: 34),
                ),
                const SizedBox(height: 42),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 25,
                        height: 1.18,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 17,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onCreateAccount,
                    child: const Text('Create account'),
                  ),
                ),
                TextButton(
                  onPressed: onSignIn,
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      );
}
