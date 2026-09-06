import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';

class LeaveReviewScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final int jobId;
  final double initialRating;
  final String initialReviewText;
  final bool isEdit;

  const LeaveReviewScreen({
    super.key,
    required this.job,
    required this.jobId,
    this.initialRating = 5,
    this.initialReviewText = '',
    this.isEdit = false,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  late double _rating;
  late final TextEditingController _controller;
  final Set<String> _tags = {'On time', 'Professional'};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(1, 5);
    _controller = TextEditingController(text: widget.initialReviewText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reviewText = _controller.text.trim();
    final statusLower = (widget.job['status']?.toString() ?? '').toLowerCase();
    final isCompleted = statusLower == 'completed' ||
        statusLower == 'complete' ||
        widget.job['timeline']?['completedAt'] != null;

    try {
      if (widget.jobId == 0) {
        throw Exception('Unable to resolve the booking for review.');
      }
      if (!isCompleted) {
        throw Exception('Only completed services can be reviewed.');
      }
      if (reviewText.length < 10) {
        throw Exception('Please enter at least 10 characters.');
      }

      setState(() => _isSubmitting = true);
      if (!widget.isEdit) {
        final eligibility = await HomeownerService.instance.getReviewEligibility(
          workOrderId: widget.jobId,
        );
        if (eligibility['eligible'] == false) {
          throw Exception(eligibility['reason']?.toString() ?? 'not_eligible');
        }
      }

      await HomeownerService.instance.submitReview(
        workOrderId: widget.jobId,
        rating: _rating.roundToDouble(),
        text: reviewText,
        displayName: AuthService.instance.userName,
      );

      if (mounted) {
        Navigator.pop(context, {
          'rating': _rating.roundToDouble(),
          'reviewText': reviewText,
          'tags': _tags.toList(),
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _screenHeader('Leave a review'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _proHeader(),
                  const SizedBox(height: 22),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'How was your experience?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.ink,
                          fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _stars(),
                        const SizedBox(height: 8),
                        Text(
                          _ratingLabel(),
                          style: const TextStyle(
                            color: AppTheme.orange500,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Tell others about your experience',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText:
                          'What went well? Was the pro on time and professional?',
                      hintStyle: const TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                      filled: true,
                      fillColor: AppTheme.pageAlt,
                      contentPadding: const EdgeInsets.all(14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.teal500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _smallLabel('QUICK TAGS'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      'On time',
                      'Professional',
                      'Clean work',
                      'Great communication',
                      'Fair price',
                    ].map(_tagChip).toList(),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Submit review'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      'Your review will be public and tied to this work order',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _proName() {
    final pro = widget.job['pro'];
    if (pro is Map) {
      return _readString(pro['businessName']) ??
          _readString(pro['business_name']) ??
          _readString(pro['name']) ??
          'Cool Air Pros';
    }
    return _readString(widget.job['proName']) ??
        _readString(widget.job['businessName']) ??
        'Cool Air Pros';
  }

  String _serviceName() {
    return _readString(widget.job['serviceName']) ??
        _readString(widget.job['service']) ??
        _readString(widget.job['title']) ??
        _readString(widget.job['serviceCategory']) ??
        'AC filter replacement';
  }

  String _dateLabel() {
    final completed = _readString(widget.job['completedAt']) ??
        _readString(widget.job['completed_at']) ??
        _readString(widget.job['scheduledStart']);
    if (completed == null) return 'Aug 14';
    final parsed = DateTime.tryParse(completed);
    if (parsed == null) return completed;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[parsed.month - 1]} ${parsed.day}';
  }

  String? _readString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  String _initials(String value) {
    final clean = value.replaceAll(RegExp(r'[^A-Za-z0-9 ]'), '').trim();
    if (clean.isEmpty) return 'P';
    return clean
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  String _ratingLabel() {
    if (_rating >= 5) return 'Excellent';
    if (_rating >= 4) return 'Great';
    if (_rating >= 3) return 'Okay';
    if (_rating >= 2) return 'Poor';
    return 'Bad';
  }

  Widget _screenHeader(String title) {
    return Container(
      width: double.infinity,
      height: 50 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 16,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.navy700, size: 24),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy700,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _proHeader() {
    final proName = _proName();
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.teal500,
          child: Text(
            _initials(proName),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_serviceName()} · ${_dateLabel()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final filled = index < _rating.round();
        return IconButton(
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _rating = index + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? AppTheme.orange500 : AppTheme.line,
            size: 28,
          ),
        );
      }),
    );
  }

  Widget _tagChip(String label) {
    final selected = _tags.contains(label);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _tags.add(label);
          } else {
            _tags.remove(label);
          }
        });
      },
      showCheckmark: false,
      selectedColor: AppTheme.tealTint,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? AppTheme.teal500 : AppTheme.line),
      labelStyle: TextStyle(
        color: selected ? AppTheme.teal500 : AppTheme.ink,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );
  }

  Widget _smallLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.gray,
        fontSize: 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.7,
      ),
    );
  }
}
