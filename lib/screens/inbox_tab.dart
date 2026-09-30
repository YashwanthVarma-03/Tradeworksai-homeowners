import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../widgets/offline_state.dart';
import 'chat_screen.dart';
import 'work_orders/work_order_detail.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Messages')), body: const InboxTab());
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
      if (client == null || user == null)
        throw Exception('Messaging is unavailable. Please sign in again.');
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

  Widget _messages() {
    if (_connecting)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.navy));
    if (_chatError != null || _channels == null)
      return OfflineState(
          title: 'Messaging unavailable',
          message: 'We could not load your conversations.',
          onRetry: _connect);
    return StreamChat(
        client: StreamService.instance.client!,
        child: StreamChannelListView(
          controller: _channels!,
          emptyBuilder: (_) => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                      'Start a conversation from a contractor profile or booking flow.',
                      textAlign: TextAlign.center))),
          itemBuilder: (context, channels, index, tile) {
            final channel = channels[index];
            return tile.copyWith(
              title: Text(_other(channel)?.name ?? 'Pro'),
              // Real message preview, without the SDK's sent/seen indicator.
              subtitle: StreamBuilder<List<Message>>(
                  stream: channel.state?.messagesStream,
                  initialData: channel.state?.messages,
                  builder: (_, snapshot) {
                    final messages = (snapshot.data ?? [])
                        .where((m) => m.deletedAt == null)
                        .toList();
                    final last = messages.isEmpty ? null : messages.last;
                    return Text(
                        last == null
                            ? 'No messages yet'
                            : (last.text?.isNotEmpty == true
                                ? last.text!
                                : last.attachments.isNotEmpty
                                    ? 'Attachment'
                                    : 'Message'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis);
                  }),
            );
          },
          onChannelTap: (channel) {
            final other = _other(channel);
            if (other == null) return;
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        contractorId: other.id,
                        contractorName: other.name,
                        existingChannel: channel)));
          },
        ));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(
            labelColor: AppTheme.navy,
            indicatorColor: AppTheme.blue,
            tabs: [Tab(text: 'Messages'), Tab(text: 'Activity')]),
        Expanded(
            child: TabBarView(
                children: [_messages(), const BookingActivityView()])),
      ]));
}

/// Activity is a record of API timestamps, never a conversation attributed to a pro.
class BookingActivityView extends StatefulWidget {
  const BookingActivityView({super.key});
  @override
  State<BookingActivityView> createState() => _BookingActivityViewState();
}

class _BookingActivityViewState extends State<BookingActivityView> {
  List<({Map<String, dynamic> job, String label, DateTime date})> _events = [];
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
      final data = await HomeownerService.instance
          .fetchWorkOrders(forceRefresh: refresh);
      final events =
          <({Map<String, dynamic> job, String label, DateTime date})>[];
      final tabs = data['tabs'];
      final seen = <String>{};
      if (tabs is Map) {
        for (final jobs in tabs.values.whereType<List>()) {
          for (final raw in jobs.whereType<Map>()) {
            final job = Map<String, dynamic>.from(raw);
            final id = '${job['workOrderId'] ?? job['id']}';
            if (!seen.add(id)) continue;
            final timeline =
                job['timeline'] is Map ? job['timeline'] as Map : {};
            final timestamps = {
              'Booking submitted': job['createdAt'],
              'Pro marked En route': timeline['enRouteAt'],
              'Pro marked In progress': timeline['inProgressAt'],
              'Completed': timeline['completedAt']
            };
            for (final entry in timestamps.entries) {
              final date = DateTime.tryParse('${entry.value}');
              if (date != null)
                events.add((job: job, label: entry.key, date: date));
            }
          }
        }
      }
      events.sort((a, b) => b.date.compareTo(a.date));
      if (mounted)
        setState(() {
          _events = events;
          _loading = false;
          _error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e;
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.navy));
    if (_error != null)
      return OfflineState(onRetry: () => _load(refresh: true));
    return RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_events.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No booking activity yet.')),
              for (final event in _events)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  title: Text(event.label),
                  subtitle: Text(
                      '${event.job['serviceCategory'] ?? 'Service'} · ${event.job['woNumber'] ?? event.job['workOrderId'] ?? event.job['id']}\n${DateFormat.yMMMd().add_jm().format(event.date.toLocal())}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              WorkOrderDetailScreen(job: event.job))),
                ),
            ]));
  }
}
