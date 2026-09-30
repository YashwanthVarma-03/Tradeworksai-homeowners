import 'package:flutter/material.dart';

import '../theme.dart';

Future<void> showSelectCertifiedInfo(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const Padding(
      padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select-certified',
                style: TextStyle(
                    color: AppTheme.navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            Text(
              'We vet every pro on TradeWorks ourselves — licence, insurance and workmanship — and hand-pick who gets listed. It isn\'t a rating and it isn\'t bought.',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 15, height: 1.45),
            ),
          ]),
    ),
  );
}
