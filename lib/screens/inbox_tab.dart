import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../utils/waiting_on_you.dart';
import '../utils/work_order_labels.dart' as labels;
import '../utils/work_order_status.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/offline_state.dart';
import 'chat_screen.dart';
import 'work_orders/work_order_detail.dart';

/// Inbox (settled Oct 1, G-52): two tabs — Messages (one thread per pro) and
/// Activity (notifications and alerts, each opening its work order).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(
            'Inbox',
            style: GoogleFonts.outfit(
              color: AppTheme.navy,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: AppTheme.cardBorder),
          ),
        ),
        body: const InboxTab(),
      );
}

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});
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
        child: StreamChannelListView(
          controller: _channels!,
          loadingBuilder: (_) => const SkeletonPage(
            layout: SkeletonLayout.inbox,
            label: 'Loading conversations',
          ),
          emptyBuilder: (_) => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Start a conversation from a contractor profile or booking flow.',
                      textAlign: TextAlign.center))),
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
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: TabBar(
              labelColor: AppTheme.blue,
              unselectedLabelColor: AppTheme.body,
              indicatorColor: AppTheme.blue,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: AppTheme.cardBorder,
              labelStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              tabs: [Tab(text: 'Messages'), Tab(text: 'Activity')]),
        ),
        Expanded(
            child:
                TabBarView(children: [_messages(), const InboxActivityView()])),
      ]));
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
            ),
            child: Row(
              children: [
                _InitialsTile(name: name),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (date != null)
                            Text(
                              _shortDate(date),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
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
                              style: TextStyle(
                                color: unread
                                    ? AppTheme.navy
                                    : AppTheme.textSecondary,
                                fontSize: 14,
                                height: 20 / 14,
                                fontWeight:
                                    unread ? FontWeight.w500 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (unread) ...[
                            const SizedBox(width: 8),
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

class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) =>
            part.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(part[0]))
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Text(
        initials.isEmpty ? 'P' : initials,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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

/// One Activity row (A08b). Read from the notifications feed when the backend
/// has one ([HomeownerService.fetchNotifications]); until then derived from
/// the work-order list, so the tab works today.
///
/// Feed row (Needs backend): `{id, type, title, work_order_id, wo_number,
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
    this.job,
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

  /// Present on derived rows, so the tap needs no lookup.
  final Map<String, dynamic>? job;

  factory ActivityItem.fromApi(Map<String, dynamic> row) {
    String text(dynamic v) {
      final t = v?.toString().trim() ?? '';
      return t.toLowerCase() == 'null' ? '' : t;
    }

    final woId = text(row['work_order_id'] ?? row['workOrderId']);
    return ActivityItem(
      id: text(row['id']),
      type: text(row['type']).toLowerCase(),
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
      waitingOnYou:
          row['waiting_on_you'] == true || row['waitingOnYou'] == true,
      unread: text(row['read_at'] ?? row['readAt']).isEmpty,
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
  Object? _error;

  @override
  void initState() {
    super.initState();
    HomeownerService.instance.syncVersion.addListener(_sync);
    _load();
  }

  @override
  void dispose() {
    HomeownerService.instance.syncVersion.removeListener(_sync);
    super.dispose();
  }

  void _sync() => _load();

  Future<void> _load({bool refresh = false}) async {
    try {
      final feed = await HomeownerService.instance.fetchNotifications();
      final items = feed != null
          ? feed
              .map(ActivityItem.fromApi)
              .where((i) => i.title.isNotEmpty)
              .toList()
          : _derive(await HomeownerService.instance
              .fetchWorkOrders(forceRefresh: refresh));
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

  /// Until the feed exists: what is waiting on the homeowner (A2), a
  /// reminder for a visit in the next 48 hours, and the status steps the pro
  /// has tapped. Never a message attributed to a pro.
  List<ActivityItem> _derive(Map<String, dynamic> data) {
    final jobs = <Map<String, dynamic>>[];
    final seen = <String>{};
    final tabs = data['tabs'];
    if (tabs is Map) {
      for (final list in tabs.values.whereType<List>()) {
        for (final raw in list.whereType<Map>()) {
          final job = Map<String, dynamic>.from(raw);
          if (seen.add('${job['workOrderId'] ?? job['id']}')) jobs.add(job);
        }
      }
    }
    final now = DateTime.now();
    final items = <ActivityItem>[];
    for (final job in jobs) {
      final wo = labels.workOrderLabel(job);
      final service = labels.jobServiceName(job);
      final pro = labels.jobProName(job, '');
      ActivityItem item(String type, String title, DateTime date,
              {bool waiting = false}) =>
          ActivityItem(
            id: '$wo:$type:${date.toIso8601String()}',
            type: type,
            title: title,
            date: date,
            workOrderId: labels.workOrderDbId(job),
            workOrderLabel: wo,
            proName: pro,
            waitingOnYou: waiting,
            job: job,
          );

      final waiting = WaitingOnYou.itemFor(job);
      if (waiting != null) {
        items.add(item(waiting.kind.name, waiting.activityTitle,
            (waiting.since ?? now).toLocal(),
            waiting: true));
      }

      final status = WorkOrderStatus.fromJob(job);
      final start = labels.jobVisitStart(job)?.toLocal();
      if (status.state == WorkOrderState.booked &&
          start != null &&
          start.isAfter(now) &&
          start.difference(now) < const Duration(hours: 48)) {
        final when = labels.visitPhrase(
          start,
          labels.jobVisitEnd(job),
          relativeDay: true,
        );
        items.add(item(
          'reminder',
          'Reminder: $service ${when[0].toLowerCase()}${when.substring(1)}',
          DateTime(now.year, now.month, now.day),
        ));
      }

      final timeline = job['timeline'] is Map
          ? Map<String, dynamic>.from(job['timeline'] as Map)
          : const <String, dynamic>{};
      final who = pro.isEmpty ? 'Your pro' : pro;
      for (final step in [
        ('status', '$who marked $service en route', timeline['enRouteAt']),
        (
          'status',
          '$who marked $service in progress',
          timeline['inProgressAt']
        ),
        (
          'completed',
          '$who marked $service completed',
          timeline['completedAt']
        ),
      ]) {
        final date = DateTime.tryParse('${step.$3}');
        if (date != null) items.add(item(step.$1, step.$2, date.toLocal()));
      }
    }
    return items;
  }

  Future<void> _open(ActivityItem item) async {
    if (item.unread && item.job == null && item.id.isNotEmpty) {
      unawaited(HomeownerService.instance.markNotificationRead(item.id));
    }
    var job = item.job;
    final id = item.workOrderId;
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
    if (mounted) _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SkeletonPage(layout: SkeletonLayout.inbox);
    if (_error != null)
      return OfflineState(onRetry: () => _load(refresh: true));
    final now = DateTime.now();
    bool isToday(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day;
    final today = _items.where((i) => isToday(i.date)).toList();
    final earlier = _items.where((i) => !isToday(i.date)).toList();
    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No activity yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary)),
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
          style: GoogleFonts.outfit(
            color: AppTheme.navy,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
        'cap' || 'estimate' => (
            Icons.description_outlined,
            AppTheme.amberTint,
            AppTheme.amber
          ),
        'reschedule' => (
            Icons.event_repeat_outlined,
            AppTheme.amberTint,
            AppTheme.amber
          ),
        'receipt' || 'credit' => (
            Icons.receipt_long_outlined,
            AppTheme.purpleTint,
            AppTheme.purple
          ),
        'completed' => (
            Icons.check_rounded,
            AppTheme.greenTint,
            AppTheme.greenMark
          ),
        _ => (Icons.build_outlined, AppTheme.blueTint, AppTheme.blue),
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
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontSize: 15,
                      height: 21 / 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      if (item.waitingOnYou) ...[
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.unread) ...[
              const _UnreadDot(),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
