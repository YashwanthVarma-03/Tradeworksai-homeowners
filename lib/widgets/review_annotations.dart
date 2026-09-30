import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';

class ReviewAnnotations extends StatelessWidget {
  const ReviewAnnotations(
      {super.key, required this.review, required this.businessName});
  final Map<String, dynamic> review;
  final String businessName;
  @override
  Widget build(BuildContext context) {
    final edited =
        DateTime.tryParse('${review['editedAt'] ?? review['edited_at']}');
    final raw = review['proResponse'] ?? review['pro_response'];
    final response = raw is Map
        ? '${raw['text'] ?? raw['response'] ?? ''}'
        : raw is String
            ? raw
            : '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (edited != null)
        Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Edited ${DateFormat.yMMMd().format(edited.toLocal())}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))),
      if (response.trim().isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(left: 16, top: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Response from $businessName',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(response),
            ])),
    ]);
  }
}
