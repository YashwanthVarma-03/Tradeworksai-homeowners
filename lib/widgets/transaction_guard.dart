import 'package:flutter/material.dart';

import 'app_notification.dart';

/// Prevents a route from being dismissed while a server mutation is in flight.
///
/// A completed request must have one deterministic navigation outcome. Allowing
/// Back during the request can leave the user on an earlier screen while the
/// mutation still succeeds, which encourages duplicate submissions.
class TransactionGuard extends StatelessWidget {
  final bool isProcessing;
  final Widget child;
  final String blockedMessage;

  const TransactionGuard({
    super.key,
    required this.isProcessing,
    required this.child,
    this.blockedMessage = 'Please wait while your request is being completed.',
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isProcessing,
      onPopInvoked: (didPop) {
        if (!didPop && isProcessing) {
          AppNotification.showInfo(context, blockedMessage);
        }
      },
      child: child,
    );
  }
}
