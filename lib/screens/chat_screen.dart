import '../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../utils/app_error_utils.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../utils/work_order_labels.dart';
import 'work_orders/work_order_detail.dart';
import '../theme.dart';
import '../widgets/offline_state.dart';

class ChatScreen extends StatefulWidget {
  final String contractorId;
  final String contractorName;

  /// Kept so existing callers compile. It no longer pre-selects a job:
  /// a message is never auto-assigned (decisions §8).
  final String? jobReference;
  final Channel? existingChannel;

  const ChatScreen({
    super.key,
    required this.contractorId,
    required this.contractorName,
    this.jobReference,
    this.existingChannel,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Channel? _channel;
  bool _isCreating = true;
  bool _isNetworkIssue = false;
  String? _error;

  /// The homeowner's jobs with this pro and the one picked for the next
  /// message (null = "No work order").
  List<Map<String, dynamic>> _jobsWithPro = const [];
  Map<String, dynamic>? _selectedJob;

  @override
  void initState() {
    super.initState();
    _initChannel();
    _loadJobsWithPro();
  }

  /// Every job this homeowner has with this pro — the composer's optional
  /// work-order list (decisions §8). Nothing is pre-selected, even when chat
  /// was opened from a work order: a message is never auto-assigned.
  Future<void> _loadJobsWithPro() async {
    try {
      final data = await HomeownerService.instance.fetchWorkOrders();
      final tabs = data['tabs'];
      final jobs = <Map<String, dynamic>>[];
      final seen = <String>{};
      if (tabs is Map) {
        for (final list in tabs.values.whereType<List>()) {
          for (final raw in list.whereType<Map>()) {
            final job = Map<String, dynamic>.from(raw);
            final label = workOrderLabel(job);
            if (label.isEmpty || !_isWithThisPro(job) || !seen.add(label)) {
              continue;
            }
            jobs.add(job);
          }
        }
      }
      if (mounted) setState(() => _jobsWithPro = jobs);
    } catch (_) {
      // Without the list the picker is hidden; messaging still works.
    }
  }

  bool _isWithThisPro(Map<String, dynamic> job) {
    for (final node in [job['pro'], job['contractor']]) {
      if (node is Map &&
          StreamService.instance
                  .resolveMessagingUserId(Map<String, dynamic>.from(node)) ==
              widget.contractorId) {
        return true;
      }
    }
    for (final key in const [
      'chatUserId',
      'chat_user_id',
      'streamUserId',
      'stream_user_id',
      'contractorUserId',
      'contractor_user_id',
    ]) {
      if ('${job[key] ?? ''}' == widget.contractorId) return true;
    }
    final name = widget.contractorName.trim().toLowerCase();
    return name.isNotEmpty && jobProName(job, '').trim().toLowerCase() == name;
  }

  /// "WO-24144 · HVAC tune-up" — the chip and the picker read the same.
  String _jobChipLabel(Map<String, dynamic> job) =>
      '${workOrderLabel(job)} · ${jobServiceName(job)}';

  /// A message's job chip opens that work order.
  Future<void> _openJob(dynamic workOrderId, String label) async {
    final id =
        workOrderId is int ? workOrderId : int.tryParse('${workOrderId ?? ''}');
    Map<String, dynamic>? job;
    for (final candidate in _jobsWithPro) {
      if ((id != null && workOrderDbId(candidate) == id) ||
          label.startsWith(workOrderLabel(candidate))) {
        job = candidate;
        break;
      }
    }
    if (job == null && id != null) {
      try {
        job = await HomeownerService.instance.findWorkOrder(id);
      } catch (_) {
        job = null;
      }
    }
    if (!mounted || job == null) return;
    final opened = job;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkOrderDetailScreen(job: opened)),
    );
  }

  /// A09: "About a job (optional)" — "No work order" (the default) or one of
  /// this pro's jobs. Hidden when the homeowner has no job with this pro.
  Widget _buildJobPicker() {
    if (_jobsWithPro.isEmpty) return const SizedBox.shrink();
    final selected = _selectedJob == null ? '' : workOrderLabel(_selectedJob!);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Text(
            'About a job (optional)',
            style: TextStyle(
              color: AppTheme.navy,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selected,
                  isExpanded: true,
                  isDense: true,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('No work order')),
                    for (final job in _jobsWithPro)
                      DropdownMenuItem(
                        value: workOrderLabel(job),
                        child: Text(
                          _jobChipLabel(job),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() {
                    _selectedJob = value == null || value.isEmpty
                        ? null
                        : _jobsWithPro
                            .firstWhere((job) => workOrderLabel(job) == value);
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initChannel({bool forceReconnect = false}) async {
    try {
      final channel = widget.existingChannel ??
          await StreamService.instance.openDirectMessageChannel(
            otherUserId: widget.contractorId,
            otherUserName: widget.contractorName,
            forceReconnect: forceReconnect,
          );

      if (!mounted) return;
      setState(() {
        _channel = channel;
        _isCreating = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isNetworkIssue = AppErrorUtils.isNetworkError(e);
        _error = _chatErrorMessage(e);
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreating) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const SkeletonPage(layout: SkeletonLayout.chat),
      );
    }

    if (_error != null ||
        _channel == null ||
        StreamService.instance.client == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: OfflineState(
          title: _isNetworkIssue
              ? AppErrorUtils.noInternetTitle
              : 'Messaging unavailable',
          icon: _isNetworkIssue
              ? Icons.wifi_off_rounded
              : Icons.chat_bubble_outline_rounded,
          message: _error ??
              StreamService.instance.lastError ??
              (_isNetworkIssue
                  ? AppErrorUtils.noInternetMessage
                  : 'This contractor is not available for messaging yet.'),
          onRetry: () {
            setState(() {
              _isCreating = true;
              _isNetworkIssue = false;
              _error = null;
            });
            _initChannel(forceReconnect: true);
          },
        ),
      );
    }

    return StreamChat(
      client: StreamService.instance.client!,
      child: StreamChannel(
        channel: _channel!,
        child: Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              Expanded(
                  child: StreamMessageListView(
                loadingBuilder: (_) => const SkeletonPage(
                    layout: SkeletonLayout.chat, label: 'Loading messages'),
                messageBuilder: (context, details, messages, defaultWidget) {
                  final reference = details.message.extraData['jobReference'];
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (reference is String && reference.trim().isNotEmpty)
                          Align(
                            alignment: details.message.user?.id ==
                                    StreamService
                                        .instance.client?.state.currentUser?.id
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: _JobChip(
                                label: reference.trim(),
                                onTap: () => _openJob(
                                    details.message.extraData['workOrderId'],
                                    reference.trim()),
                              ),
                            ),
                          ),
                        defaultWidget.copyWith(showSendingIndicator: false),
                      ]);
                },
              )),
              _buildJobPicker(),
              StreamMessageInput(
                preMessageSending: (message) {
                  final job = _selectedJob;
                  if (job == null) return message;
                  return message.copyWith(extraData: {
                    ...message.extraData,
                    'jobReference': _jobChipLabel(job),
                    if (workOrderDbId(job) != null)
                      'workOrderId': workOrderDbId(job),
                  });
                },
                // The choice is per message; the next one starts again at
                // "No work order".
                onMessageSent: (_) {
                  if (mounted) setState(() => _selectedJob = null);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _chatErrorMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('getorcreatechannel') ||
        raw.contains("users are involved in channel create operation") ||
        raw.contains("don't exist")) {
      return 'This contractor is not available for messaging yet.';
    }
    return AppErrorUtils.friendlyMessage(
      error,
      fallback: 'Chat is unavailable right now.',
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        widget.contractorName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15,
          color: AppTheme.navy700,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: AppTheme.line, height: 0.5),
      ),
    );
  }
}

/// A09: the per-message job chip — "WO-24144 · HVAC tune-up", on the
/// sender's side above the bubble; tapping it opens the work order.
class _JobChip extends StatelessWidget {
  const _JobChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape:
            const StadiumBorder(side: BorderSide(color: AppTheme.cardBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined,
                    size: 14, color: AppTheme.navy),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
