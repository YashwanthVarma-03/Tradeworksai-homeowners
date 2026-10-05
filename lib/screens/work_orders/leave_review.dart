import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import 'package:intl/intl.dart';

import '../../utils/work_order_labels.dart';
import '../../widgets/transaction_guard.dart';

class LeaveReviewScreen extends StatefulWidget {
  final Map<String, dynamic> job;
  final int jobId;
  final double initialRating;
  final String initialReviewText;
  final List<String> initialTags;
  final bool hasExistingReview;

  const LeaveReviewScreen({
    super.key,
    required this.job,
    required this.jobId,
    this.initialRating = 0,
    this.initialReviewText = '',
    this.initialTags = const [],
    this.hasExistingReview = false,
  });

  @override
  State<LeaveReviewScreen> createState() => _LeaveReviewScreenState();
}

class _LeaveReviewScreenState extends State<LeaveReviewScreen> {
  late double _rating;
  late final TextEditingController _controller;
  final Set<String> _tags = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating.clamp(0, 5);
    if (widget.hasExistingReview) _tags.addAll(widget.initialTags);
    _controller = TextEditingController(text: widget.initialReviewText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final reviewText = _controller.text.trim();
    final statusLower = (widget.job['status']?.toString() ?? '').toLowerCase();
    final isCompleted = statusLower == 'completed' ||
        statusLower == 'complete' ||
        widget.job['timeline']?['completedAt'] != null;

    try {
      if (_rating < 1) throw Exception('Please choose a star rating.');
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
      if (!widget.hasExistingReview) {
        final eligibility =
            await HomeownerService.instance.getReviewEligibility(
          workOrderId: widget.jobId,
        );
        if (eligibility['eligible'] == false) {
          final reason = eligibility['reason']?.toString();
          if (reason != 'already_reviewed' || !widget.hasExistingReview) {
            throw Exception(reason ?? 'not_eligible');
          }
        }
      }
      final saved = await HomeownerService.instance.submitReview(
        workOrderId: widget.jobId,
        rating: _rating.roundToDouble(),
        text: reviewText,
        displayName: _publishingName,
        tags: _tags
            .where(
                (tag) => tag != 'Price stayed within the cap' || _isCapApproval)
            .toList(),
        hasExistingReview: widget.hasExistingReview,
      );

      if (mounted) {
        Navigator.pop(context, {
          ...saved,
          'rating': _rating.roundToDouble(),
          'reviewText': reviewText,
          'tags': _tags
              .where((tag) =>
                  tag != 'Price stayed within the cap' || _isCapApproval)
              .toList(),
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppNotification.showError(
          context,
          e,
          fallback: 'We couldn\'t submit your review. Please try again.',
        );
      }
    }
  }

  String get _publishingName {
    final name = AuthService.instance.userName?.trim();
    return name == null || name.isEmpty ? 'TradeWorks Customer' : name;
  }

  /// "Price stayed within the cap" is offered only on Cap Approval work
  /// orders (Oct 1, G-50). Keyed on the work-order type; a job that carries
  /// an approved cap counts when the type is missing.
  bool get _isCapApproval {
    final type = _readString(
            widget.job['workOrderType'] ?? widget.job['work_order_type'])
        ?.toLowerCase();
    if (type != null) return type == 'nte' || type.contains('cap');
    return _readString(widget.job['approvedCap'] ??
            widget.job['approved_cap'] ??
            widget.job['capAmount'] ??
            widget.job['cap_amount']) !=
        null;
  }

  Future<void> _delete() async {
    if (_isSubmitting || !widget.hasExistingReview) return;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete your review?'),
              content: const Text(
                  'Your rating and review will be removed from this pro’s profile.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep review')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete review',
                        style: TextStyle(color: AppTheme.red)))
              ],
            ));
    if (confirmed != true || !mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await HomeownerService.instance.deleteReview(widget.jobId);
      if (mounted) Navigator.pop(context, {'deleted': true});
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppNotification.showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TransactionGuard(
      isProcessing: _isSubmitting,
      blockedMessage: 'Please wait while your review is being submitted.',
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            _screenHeader(widget.hasExistingReview
                ? 'Edit your review'
                : 'Leave a review'),
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
                          Text(
                            'How was your experience?',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          _stars(),
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
                            'What should other homeowners know about working with this pro?',
                        hintStyle: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                        filled: true,
                        fillColor: AppTheme.pageBackground,
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
                    const SizedBox(height: 8),
                    const Text(
                      'At least 10 characters',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            'Quick tags',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                        const Text(
                          'Optional',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: [
                        'On time',
                        'Professional',
                        'Clean work',
                        'Great communication',
                        'Fair price',
                        if (_isCapApproval) 'Price stayed within the cap',
                      ].map(_tagChip).toList(),
                    ),
                    if (widget.hasExistingReview) ...[
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _delete,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.red,
                            minimumSize: const Size(44, 44),
                          ),
                          child: const Text(
                            'Delete your review',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  /// E06: who the review publishes as, the one primary action, and the
  /// disclosure that credits never depend on a review — in a sticky bar.
  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This will publish as $_publishingName and is tied to this work order.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onOrange,
                        ),
                      )
                    : Text(widget.hasExistingReview
                        ? 'Save changes'
                        : 'Submit review'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your credits come from what you spend, not from leaving a review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 19 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _proName() {
    final pro = widget.job['pro'];
    if (pro is Map) {
      return _readString(pro['businessName']) ??
          _readString(pro['business_name']) ??
          _readString(pro['name']) ??
          'Your pro';
    }
    return _readString(widget.job['proName']) ??
        _readString(widget.job['businessName']) ??
        'Your pro';
  }

  String _serviceName() {
    return _readString(widget.job['serviceName']) ??
        _readString(widget.job['service']) ??
        _readString(widget.job['title']) ??
        _readString(widget.job['serviceCategory']) ??
        'Service';
  }

  /// "Completed Mon, Oct 5" — the completion date only, never the visit time.
  String? _completedLabel() {
    final timeline = widget.job['timeline'];
    final completed = DateTime.tryParse(
        _readString(widget.job['completedAt']) ??
            _readString(widget.job['completed_at']) ??
            (timeline is Map ? _readString(timeline['completedAt']) : null) ??
            '');
    if (completed == null) return null;
    return 'Completed ${DateFormat('EEE, MMM d').format(completed.toLocal())}';
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
    final meta = [
      _serviceName(),
      workOrderLabel(widget.job),
      _completedLabel(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.navy,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Text(
            _initials(proName),
            style: AppTheme.headingStyle.copyWith(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
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
                meta,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
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
          tooltip: 'Rate ${index + 1} stars',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
          onPressed: () => setState(() => _rating = index + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: filled ? AppTheme.gold : AppTheme.line,
            size: 28,
          ),
        );
      }),
    );
  }

  Widget _tagChip(String label) {
    final selected = _tags.contains(label);
    final enabled = !_isSubmitting;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: !enabled
          ? null
          : (value) {
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
}
