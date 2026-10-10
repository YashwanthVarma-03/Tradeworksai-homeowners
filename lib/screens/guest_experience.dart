import 'package:flutter/material.dart';

import '../theme.dart';
import '../ui/tw.dart';

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
            padding: EdgeInsets.symmetric(
              horizontal: TwLayout.gutter(context),
              vertical: TwSpace.s28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: AppTheme.subtle,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: AppTheme.navy, size: 36),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TwType.h1Sm(),
                  ),
                  const SizedBox(height: TwSpace.s8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TwType.body(),
                  ),
                  const SizedBox(height: 24),
                  TwPrimaryButton(
                    label: 'Create account',
                    onPressed: onCreateAccount,
                  ),
                  const SizedBox(height: TwSpace.s8),
                  Center(
                    child: TwTextAction(
                      label: 'Already have an account? Sign in',
                      onPressed: onSignIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
