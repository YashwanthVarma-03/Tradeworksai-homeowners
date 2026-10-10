import '../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../utils/app_error_utils.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../utils/work_order_labels.dart';
import 'work_orders/work_order_detail.dart';
import '../theme.dart';
import '../ui/tw.dart';
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
    final gutter = TwLayout.gutter(context);
    final label = Text(
      'About a job (optional)',
      style: TwType.caption(color: AppTheme.navy)
          .copyWith(fontWeight: FontWeight.w600),
    );
    final picker = Container(
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: TwSpace.s12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: AppTheme.navy,
          ),
          style: TwType.meta(color: AppTheme.navy)
              .copyWith(fontWeight: FontWeight.w500),
          items: [
            const DropdownMenuItem(value: '', child: Text('No work order')),
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
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(gutter, TwSpace.s12, gutter, 0),
      child: TwLayout.stackRows(context)
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                label,
                const SizedBox(height: 6),
                picker,
              ],
            )
          : Row(
              children: [
                label,
                const SizedBox(width: TwSpace.s8),
                Expanded(child: picker),
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
        backgroundColor: AppTheme.pageBackground,
        appBar: _buildAppBar(),
        body: const SkeletonPage(layout: SkeletonLayout.chat),
      );
    }

    if (_error != null ||
        _channel == null ||
        StreamService.instance.client == null) {
      return Scaffold(
        backgroundColor: AppTheme.pageBackground,
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

    final gutter = TwLayout.gutter(context);
    return StreamChat(
      client: StreamService.instance.client!,
      streamChatThemeData: twStreamChatTheme,
      child: StreamChannel(
        channel: _channel!,
        child: Scaffold(
          backgroundColor: AppTheme.pageBackground,
          appBar: _buildAppBar(),
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: TwLayout.maxContent + gutter * 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: StreamMessageListView(
                    loadingBuilder: (_) => const SkeletonPage(
                        layout: SkeletonLayout.chat,
                        label: 'Loading messages'),
                    dateDividerBuilder: (date) => _ChatDateDivider(date: date),
                    messageBuilder:
                        (context, details, messages, defaultWidget) {
                      final reference =
                          details.message.extraData['jobReference'];
                      final isMine = details.message.user?.id ==
                          StreamService.instance.client?.state.currentUser?.id;
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (reference is String &&
                                reference.trim().isNotEmpty)
                              Align(
                                alignment: isMine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: gutter,
                                      vertical: TwSpace.s4),
                                  child: _JobChip(
                                    label: reference.trim(),
                                    onTap: () => _openJob(
                                        details.message.extraData['workOrderId'],
                                        reference.trim()),
                                  ),
                                ),
                              ),
                            defaultWidget.copyWith(
                              showSendingIndicator: false,
                              borderRadiusGeometry: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMine ? 16 : 4),
                                bottomRight: Radius.circular(isMine ? 4 : 16),
                              ),
                            ),
                          ]);
                    },
                  )),
                  _buildJobPicker(),
                  StreamMessageInput(
                    hintGetter: (context, type) => switch (type) {
                      HintType.writeAMessage =>
                        'Message ${widget.contractorName}',
                      HintType.searchGif => context.translations.searchGifLabel,
                      HintType.addACommentOrSend =>
                        context.translations.addACommentOrSendLabel,
                      HintType.slowModeOn =>
                        context.translations.slowModeOnLabel,
                    },
                    idleSendButton: const _SendCircle(enabled: false),
                    activeSendButton: const _SendCircle(enabled: true),
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
    return TwAppBar(
      title: widget.contractorName,
      onBack: () => Navigator.pop(context),
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
        color: AppTheme.white,
        shape:
            const StadiumBorder(side: BorderSide(color: AppTheme.cardBorder)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: TwSpace.s12),
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
                      style: TwType.caption(color: AppTheme.navy)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// A09 send button: 40 orange circle, navy icon, in a 48×44 target. Idle
/// (nothing typed) is orange at 40% with the icon at 60% (SPEC §4 Buttons).
class _SendCircle extends StatelessWidget {
  const _SendCircle({required this.enabled});
  final bool enabled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(TwSpace.s8, 2, 0, 2),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.orange : AppTheme.orange.withOpacity(0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.send_rounded,
            size: 20,
            color: enabled ? AppTheme.navy : AppTheme.navy.withOpacity(0.6),
          ),
        ),
      );
}

/// A09 date divider: "Sat, Oct 10", 13/500 meta, centred. Also used for the
/// floating divider, so it sits on a white pill.
class _ChatDateDivider extends StatelessWidget {
  const _ChatDateDivider({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: TwSpace.s8),
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: TwSpace.s12, vertical: TwSpace.s4),
              child: Text(
                DateFormat('EEE, MMM d').format(date.toLocal()),
                style: TwType.caption().copyWith(fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      );
}

/// Stream chat look for v3.3 (SPEC §4 Chat): own bubble blue tint, other
/// bubble subtle, ink text 15/22 Inter, `caption` timestamps; composer field
/// subtle fill radius 22 with a hairline (blue when focused), navy icons.
/// Pass it as `streamChatThemeData` wherever a `StreamChat` widget is built.
StreamChatThemeData get twStreamChatTheme {
  final bubbleText =
      TwType.body(color: AppTheme.navy).copyWith(fontSize: 15, height: 22 / 15);
  final timestamp = TwType.caption();
  return StreamChatThemeData(
    brightness: Brightness.light,
    colorTheme: StreamColorTheme.light(
      textHighEmphasis: AppTheme.navy,
      textLowEmphasis: AppTheme.textSecondary,
      borders: AppTheme.cardBorder,
      inputBg: AppTheme.subtle,
      appBg: AppTheme.pageBackground,
      barsBg: AppTheme.white,
      accentPrimary: AppTheme.blue,
    ),
    ownMessageTheme: StreamMessageThemeData(
      messageBackgroundColor: AppTheme.blueTint,
      messageBorderColor: AppTheme.blueTint,
      messageTextStyle: bubbleText,
      messageLinksStyle: bubbleText.copyWith(
        color: AppTheme.blue,
        fontWeight: FontWeight.w600,
      ),
      messageAuthorStyle: timestamp,
      createdAtStyle: timestamp,
    ),
    otherMessageTheme: StreamMessageThemeData(
      messageBackgroundColor: AppTheme.subtle,
      messageBorderColor: AppTheme.subtle,
      messageTextStyle: bubbleText,
      messageLinksStyle: bubbleText.copyWith(
        color: AppTheme.blue,
        fontWeight: FontWeight.w600,
      ),
      messageAuthorStyle: timestamp,
      createdAtStyle: timestamp,
    ),
    messageInputTheme: StreamMessageInputThemeData(
      inputBackgroundColor: AppTheme.subtle,
      inputTextStyle: TwType.body(color: AppTheme.navy),
      borderRadius: BorderRadius.circular(22),
      idleBorderGradient: const LinearGradient(
        colors: [AppTheme.cardBorder, AppTheme.cardBorder],
      ),
      activeBorderGradient: const LinearGradient(
        colors: [AppTheme.blue, AppTheme.blue],
      ),
      actionButtonColor: AppTheme.navy,
      actionButtonIdleColor: AppTheme.navy,
      sendButtonColor: AppTheme.navy,
      sendButtonIdleColor: AppTheme.navy,
      expandButtonColor: AppTheme.navy,
      linkHighlightColor: AppTheme.blue,
      elevation: 0,
      shadow: AppTheme.floatShadow.first,
    ),
    messageListViewTheme: StreamMessageListViewThemeData(
      backgroundColor: AppTheme.pageBackground,
    ),
  );
}
