import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import 'package:intl/intl.dart';

import '../../utils/work_order_labels.dart';
import '../../widgets/transaction_guard.dart';
import '../../ui/tw.dart';

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
              title: Text('Delete your review?', style: TwType.h3()),
              content: Text(
                'Your rating and review will be removed from this pro’s profile.',
                style: TwType.bodySm(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    child: Text('Keep review',
                        style: TwType.button(color: AppTheme.navy))),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style:
                        TextButton.styleFrom(minimumSize: const Size(44, 44)),
                    child: Text('Delete review',
                        style: TwType.button(color: AppTheme.red)))
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
        appBar: TwAppBar(
          title: widget.hasExistingReview ? 'Edit your review' : 'Leave a review',
          onBack: () => Navigator.pop(context),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: TwPage(
                  top: TwSpace.s20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _proHeader(),
                      const SizedBox(height: TwSpace.s28),
                      Text(
                        'How was your experience?',
                        textAlign: TextAlign.center,
                        style: TwType.h2(),
                      ),
                      const SizedBox(height: TwSpace.s8),
                      _stars(),
                      const SizedBox(height: TwSpace.s28),
                      const TwFieldLabel('Tell others about your experience'),
                      TextField(
                        controller: _controller,
                        minLines: 5,
                        maxLines: 5,
                        style: TwType.body(color: AppTheme.navy),
                        decoration: TwInputs.decoration(
                          hint:
                              'What should other homeowners know about working with this pro?',
                        ),
                      ),
                      const SizedBox(height: TwSpace.s8),
                      Text('At least 10 characters', style: TwType.caption()),
                      const SizedBox(height: TwSpace.s28),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text('Quick tags', style: TwType.h2()),
                          ),
                          Text('Optional', style: TwType.caption()),
                        ],
                      ),
                      const SizedBox(height: TwSpace.s12),
                      Wrap(
                        spacing: TwSpace.s8,
                        runSpacing: TwSpace.s8,
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
                        const SizedBox(height: TwSpace.s20),
                        Center(
                          child: TwTextAction(
                            label: 'Delete your review',
                            onPressed: _isSubmitting ? null : _delete,
                            destructive: true,
                          ),
                        ),
                      ],
                    ],
                  ),
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
    return TwStickyBar(
      note:
          'This will publish as $_publishingName and is tied to this work order.',
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TwPrimaryButton(
              label:
                  widget.hasExistingReview ? 'Save changes' : 'Submit review',
              onPressed: _isSubmitting ? null : _submit,
              loading: _isSubmitting,
            ),
            const SizedBox(height: TwSpace.s8),
            Text(
              'Your credits come from what you spend, not from leaving a review.',
              textAlign: TextAlign.center,
              style: TwType.caption(),
            ),
          ],
        ),
      ],
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

  Widget _proHeader() {
    final proName = _proName();
    final meta = [
      _serviceName(),
      workOrderLabel(widget.job),
      _completedLabel(),
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
    return Row(
      children: [
        TwAvatar(name: proName, size: 56),
        const SizedBox(width: TwSpace.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                proName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TwType.h3(),
              ),
              const SizedBox(height: TwSpace.s4),
              Text(meta, style: TwType.meta()),
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
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: IconButton(
            tooltip: 'Rate ${index + 1} stars',
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _rating = index + 1),
            icon: Icon(
              Icons.star_rounded,
              color: filled ? AppTheme.gold : AppTheme.cardBorder,
              size: 34,
            ),
          ),
        );
      }),
    );
  }

  Widget _tagChip(String label) {
    final selected = _tags.contains(label);
    return TwPill(
      label: label,
      selected: selected,
      onTap: () {
        if (_isSubmitting) return;
        setState(() {
          if (selected) {
            _tags.remove(label);
          } else {
            _tags.add(label);
          }
        });
      },
    );
  }
}
