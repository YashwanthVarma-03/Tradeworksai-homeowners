import '../widgets/app_notification.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import '../ui/tw.dart';
import 'package:intl/intl.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../services/homeowner_service.dart';
import '../services/notification_routing.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../utils/notification_route_launcher.dart';
import '../utils/work_order_labels.dart' as labels;
import '../widgets/loading_skeleton.dart';
import '../widgets/offline_state.dart';
import 'chat_screen.dart';

/// Inbox (settled Oct 1, G-52): two tabs — Messages (one thread per pro) and
/// Activity (notifications and alerts, each opening its work order).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.pageBackground,
        appBar: TwAppBar(
          title: 'Inbox',
          onBack: () => Navigator.maybePop(context),
        ),
        body: InboxTab(initialTab: initialTab),
      );
}

class InboxTab extends StatefulWidget {
  const InboxTab({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  StreamChannelListController? _channels;
  bool _connecting = true;
  Object? _chatError;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _channels?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _chatError = null;
    });
    try {
      await StreamService.instance.ensureConnected();
      final client = StreamService.instance.client;
      final user = client?.state.currentUser;
      if (client == null || user == null) {
        throw Exception('Messaging is unavailable. Please sign in again.');
      }
      if (!mounted) return;
      _channels?.dispose();
      _channels = StreamChannelListController(
          client: client,
          filter: Filter.and([
            Filter.equal('type', 'messaging'),
            Filter.in_('members', [user.id])
          ]),
          channelStateSort: const [
            SortOption('last_message_at', direction: SortOption.DESC)
          ]);
    } catch (e) {
      if (mounted) _chatError = e;
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  User? _other(Channel channel) {
    final current = StreamService.instance.client?.state.currentUser?.id;
    for (final member in channel.state?.members ?? <Member>[]) {
      if (member.userId != current) return member.user;
    }
    return null;
  }

  void _openThread(Channel channel) {
    final other = _other(channel);
    if (other == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChatScreen(
                contractorId: other.id,
                contractorName: other.name,
                existingChannel: channel)));
  }

  Widget _messages() {
    if (_connecting) return const SkeletonPage(layout: SkeletonLayout.inbox);
    if (_chatError != null || _channels == null) {
      return OfflineState(
          title: 'Messaging unavailable',
          message: 'We could not load your conversations.',
          onRetry: _connect);
    }
    return StreamChat(
        client: StreamService.instance.client!,
        streamChatThemeData: twStreamChatTheme,
        child: StreamChannelListView(
          controller: _channels!,
          loadingBuilder: (_) => const SkeletonPage(
            layout: SkeletonLayout.inbox,
            label: 'Loading conversations',
          ),
          emptyBuilder: (_) => const Center(
            child: Padding(
              padding: EdgeInsets.all(TwSpace.s20),
              child: TwEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No messages yet',
                message:
                    "Start a conversation from a pro's profile or a booking.",
              ),
            ),
          ),
          itemBuilder: (context, channels, index, tile) {
            final channel = channels[index];
            return _ThreadRow(
              channel: channel,
              name: _other(channel)?.name ?? 'Pro',
              onTap: () => _openThread(channel),
            );
          },
          onChannelTap: _openThread,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final gutter = TwLayout.gutter(context);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: TwLayout.maxContent + gutter * 2),
        child: DefaultTabController(
          key: ValueKey(widget.initialTab),
          length: 2,
          initialIndex: widget.initialTab,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, TwSpace.s4, gutter, 0),
                child: TabBar(
                  labelColor: AppTheme.blue,
                  unselectedLabelColor: AppTheme.body,
                  indicatorColor: AppTheme.blue,
                  indicatorWeight: 2,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: AppTheme.cardBorder,
                  labelStyle:
                      TwType.title(color: AppTheme.blue).copyWith(fontSize: 15),
                  unselectedLabelStyle: TwType.title(color: AppTheme.body)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                  tabs: const [
                    Tab(height: 48, text: 'Messages'),
                    Tab(height: 48, text: 'Activity'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [_messages(), const InboxActivityView()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One thread row (A08): initials tile, pro name and date, last message —
/// "You: …" when the homeowner sent it; ink text and a blue dot while unread.
class _ThreadRow extends StatelessWidget {
  const _ThreadRow(
      {required this.channel, required this.name, required this.onTap});

  final Channel channel;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Message>>(
      stream: channel.state?.messagesStream,
      initialData: channel.state?.messages,
      builder: (context, snapshot) {
        final messages = (snapshot.data ?? const <Message>[])
            .where((m) => m.deletedAt == null)
            .toList();
        final last = messages.isEmpty ? null : messages.last;
        final me = StreamService.instance.client?.state.currentUser?.id;
        final unread = (channel.state?.unreadCount ?? 0) > 0;
        final text = last == null
            ? 'No messages yet'
            : (last.text?.isNotEmpty == true
                ? last.text!
                : last.attachments.isNotEmpty
                    ? 'Photo'
                    : 'Message');
        final preview =
            last != null && last.user?.id == me ? 'You: $text' : text;
        final date = (last?.createdAt ?? channel.lastMessageAt)?.toLocal();
        return InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: EdgeInsets.symmetric(horizontal: TwLayout.gutter(context)),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: Row(
              children: [
                TwAvatar(name: name, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TwType.title(),
                            ),
                          ),
                          if (date != null) ...[
                            const SizedBox(width: TwSpace.s8),
                            Text(_shortDate(date), style: TwType.caption()),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TwType.meta(
                                color: unread
                                    ? AppTheme.navy
                                    : AppTheme.textSecondary,
                              ).copyWith(
                                fontWeight:
                                    unread ? FontWeight.w500 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: TwSpace.s8),
                            const _UnreadDot(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Oct 12" — or the time when it was today.
String _shortDate(DateTime date) {
  final now = DateTime.now();
  final sameDay =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return sameDay
      ? DateFormat.jm().format(date)
      : DateFormat.MMMd().format(date);
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Unread',
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppTheme.blue,
            shape: BoxShape.circle,
          ),
        ),
      );
}

/// One Activity row (A08b), from the server notifications feed.
///
/// Feed row: `{id, type, title, work_order_id, wo_number,
/// pro_name, waiting_on_you, created_at, read_at}` where `type` is one of
/// reminder · cap · estimate · reschedule · receipt · status · completed ·
/// credit.
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.workOrderId,
    this.workOrderLabel = '',
    this.proName = '',
    this.waitingOnYou = false,
    this.unread = false,
    this.targetId = '',
    this.body = '',
    this.data = const {},
  });

  final String id;
  final String type;
  final String title;
  final DateTime date;
  final int? workOrderId;
  final String workOrderLabel;
  final String proName;
  final bool waitingOnYou;
  final bool unread;
  final String targetId;

  /// Supporting notification copy. Empty hides the line.
  final String body;
  final Map<String, dynamic> data;
  bool get actionable =>
      notificationIsAction(data) &&
      (waitingOnYou ||
          type == 'message' ||
          (!data.containsKey('waiting_on_you') &&
              !data.containsKey('waitingOnYou')));

  factory ActivityItem.fromApi(Map<String, dynamic> row) {
    String text(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.toLowerCase() == 'null' ? '' : t;
    }

    final woId = text(row['work_order_id'] ?? row['workOrderId']);
    return ActivityItem(
      id: text(row['id']),
      type: notificationType(row),
      data: row,
      title: text(row['title']),
      date: DateTime.tryParse(text(row['created_at'] ?? row['createdAt']))
              ?.toLocal() ??
          DateTime.now(),
      workOrderId: int.tryParse(woId),
      workOrderLabel: labels.workOrderLabel({
        'woNumber': row['wo_number'] ?? row['woNumber'],
        'workOrderId': woId,
      }),
      proName: text(row['pro_name'] ?? row['proName']),
      waitingOnYou: notificationWaiting(row),
      // The timestamp is authoritative; a boolean alias is not required.
      unread:
          (row.containsKey('read_at') ? row['read_at'] : row['readAt']) == null,
      targetId: text(row['channel_id'] ??
          row['channelId'] ??
          row['work_order_id'] ??
          row['workOrderId']),
      body: text(row['body']),
    );
  }
}

class InboxActivityView extends StatefulWidget {
  const InboxActivityView({super.key});
  @override
  State<InboxActivityView> createState() => _InboxActivityViewState();
}

class _InboxActivityViewState extends State<InboxActivityView> {
  List<ActivityItem> _items = const [];
  bool _loading = true;
  bool _markingAllRead = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    HomeownerService.instance.syncVersion.addListener(_sync);
    HomeownerService.instance.notificationVersion.addListener(_sync);
    _load();
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion.removeListener(_sync);
    HomeownerService.instance.notificationVersion.removeListener(_sync);
    super.dispose();
  }

  void _sync() => _load();

  Future<void> _load({bool refresh = false}) async {
    try {
      final feed = await HomeownerService.instance.fetchNotifications();
      if (feed == null) throw StateError('Activity feed unavailable');
      final items = feed
          .map(ActivityItem.fromApi)
          .where((i) => i.title.isNotEmpty)
          .toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    if (_markingAllRead) return;
    setState(() => _markingAllRead = true);
    try {
      await HomeownerService.instance.markAllNotificationsRead();
      await _load(refresh: true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not mark activity as read.')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _open(ActivityItem item) async {
    if (item.unread && item.id.isNotEmpty) {
      try {
        await HomeownerService.instance.markNotificationRead(item.id);
      } catch (_) {
        if (mounted)
          AppNotification.showInfo(
              context, 'Could not mark this activity as read.');
      }
      if (!mounted) return;
    }
    if (!notificationIsAction(item.data)) {
      await _load();
      return;
    }
    final route = NotificationRouteData.fromData(item.data, fromActivity: true);
    try {
      await openNotificationRoute(context, route);
    } catch (_) {
      if (mounted)
        AppNotification.showInfo(
            context, 'This item is unavailable right now. Please try again.');
    }
    if (mounted) {
      _load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonPage(layout: SkeletonLayout.inbox);
    if (_error != null) {
      return Center(
          child: TwEmptyState(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load activity",
              action: TwSecondaryButton(
                  label: 'Try again',
                  expand: false,
                  onPressed: () => _load(refresh: true))));
    }
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final today = _items.where((i) => isToday(i.date)).toList();
    final earlier = _items.where((i) => !isToday(i.date)).toList();
    final gutter = TwLayout.gutter(context);
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      color: AppTheme.navy,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, TwSpace.s28),
        children: [
          if (_items.any((item) => item.unread))
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _markingAllRead ? null : _markAllRead,
                child: const Text('Mark all read'),
              ),
            ),
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: TwSpace.s40),
              child: TwEmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No activity yet',
              ),
            ),
          if (today.isNotEmpty) ...[
            _heading('Today', top: 20),
            for (var i = 0; i < today.length; i++)
              _ActivityRow(
                item: today[i],
                last: i == today.length - 1,
                onTap: () => _open(today[i]),
              ),
          ],
          if (earlier.isNotEmpty) ...[
            _heading('Earlier', top: today.isEmpty ? 20 : 24),
            for (var i = 0; i < earlier.length; i++)
              _ActivityRow(
                item: earlier[i],
                last: i == earlier.length - 1,
                onTap: () => _open(earlier[i]),
              ),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text, {required double top}) => Padding(
        padding: EdgeInsets.only(top: top, bottom: 2),
        child: Text(
          text,
          style: TwType.h3().copyWith(fontSize: 15, height: 20 / 15),
        ),
      );
}

/// A08b row: tinted 36px icon, bold line, meta "Oct 12 · WO-24152" (with the
/// amber "Waiting on you" mark first when it is owed), unread dot, chevron.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
      {required this.item, required this.last, required this.onTap});

  final ActivityItem item;
  final bool last;
  final VoidCallback onTap;

  (IconData, Color, Color) get _look => switch (item.type) {
        'reminder' => (Icons.event_outlined, AppTheme.blueTint, AppTheme.blue),
        'rebooked' => (
            Icons.event_available_outlined,
            AppTheme.blueTint,
            AppTheme.blue
          ),
        'booking_cancelled' => (
            Icons.event_busy_outlined,
            AppTheme.subtle,
            AppTheme.textSecondary
          ),
        'cap' || 'estimate' || 'no_show' || 'review' => (
            Icons.description_outlined,
            AppTheme.amberTint,
            AppTheme.amber
          ),
        'reschedule' => (
            Icons.description_outlined,
            AppTheme.amberTint,
            AppTheme.amber
          ),
        'receipt' || 'credit' => (
            Icons.card_giftcard_outlined,
            AppTheme.purpleTint,
            AppTheme.purple
          ),
        'completed' => (
            Icons.check_rounded,
            AppTheme.greenTint,
            AppTheme.greenMark
          ),
        'message' => (
            Icons.chat_bubble_outline,
            AppTheme.blueTint,
            AppTheme.blue
          ),
        _ => (Icons.event_outlined, AppTheme.blueTint, AppTheme.blue),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, tint, color) = _look;
    // A08b names the pro only on a reminder; the other lines already say who.
    final showPro = item.type == 'reminder' &&
        item.proName.isNotEmpty &&
        !item.title.contains(item.proName);
    final meta = [
      DateFormat.MMMd().format(item.date),
      if (showPro) item.proName,
      if (item.workOrderLabel.isNotEmpty) item.workOrderLabel,
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.cardBorder)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: TwType.title()),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(item.body, style: TwType.bodySm()),
                  ],
                  const SizedBox(height: TwSpace.s4),
                  Text.rich(
                    TextSpan(children: [
                      if (item.actionable && item.waitingOnYou) ...[
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: SizedBox(
                              width: 8,
                              height: 8,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: AppTheme.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(
                          text: 'Waiting on you',
                          style: TextStyle(
                            color: AppTheme.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const TextSpan(text: ' · '),
                      ],
                      TextSpan(text: meta),
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TwType.caption(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: TwSpace.s8),
            if (item.unread) ...[
              const _UnreadDot(),
              const SizedBox(width: TwSpace.s8),
            ],
            if (item.actionable)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
