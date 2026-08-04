import 'package:flutter/material.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import 'chat_screen.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> with WidgetsBindingObserver {
  int _activeSegment = 0; // 0: Messages, 1: Activity

  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _activityFeed = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchInboxData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchInboxData(showLoading: false);
    }
  }

  Future<void> _fetchInboxData({bool showLoading = true}) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showLoading || (_threads.isEmpty && _activityFeed.isEmpty)) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }
    try {
      final woData = await HomeownerService.instance.fetchWorkOrders();
      final tabs = woData['tabs'];
      final List<dynamic> allJobs = [];
      if (tabs != null) {
        if (tabs['active'] != null) allJobs.addAll(tabs['active']);
        if (tabs['scheduled'] != null) allJobs.addAll(tabs['scheduled']);
        if (tabs['history'] != null) allJobs.addAll(tabs['history']);
      }

      final List<Map<String, dynamic>> threads = [];
      final List<Map<String, dynamic>> activityFeed = [];

      for (final job in allJobs) {
        final proName = job['pro']?['businessName'] ?? 'Service Pro';
        final serviceCategory = job['serviceCategory'] ?? 'Service';
        final status = job['status'] ?? 'pending';
        final woNumber =
            job['woNumber'] ?? job['workOrderId']?.toString() ?? '';
        final double quoteAmount =
            (job['quoteAmount'] as num?)?.toDouble() ?? 0.0;
        final double invoiceAmount =
            (job['invoiceAmount'] as num?)?.toDouble() ?? 0.0;
        final double rewardsEarned =
            (job['rewardsEarned'] as num?)?.toDouble() ?? 0.0;

        // 1. Thread preparation
        final String lastMessageText;
        Color statusColor = AppTheme.teal500;
        if (status == 'quote_ready') {
          lastMessageText = 'Your quote is ready to review and approve.';
          statusColor = AppTheme.orange500;
        } else if (status == 'en_route') {
          lastMessageText = 'On my way — ETA about 20 minutes.';
          statusColor = AppTheme.teal500;
        } else if (status == 'arrived') {
          lastMessageText = 'I have arrived at the property.';
          statusColor = AppTheme.teal500;
        } else if (status == 'in_progress') {
          lastMessageText = 'Work is in progress.';
          statusColor = AppTheme.teal500;
        } else if (status == 'completed') {
          lastMessageText = 'Thanks! Receipt & warranty info attached.';
          statusColor = AppTheme.success;
        } else if (status == 'cancelled') {
          lastMessageText = 'This booking has been cancelled.';
          statusColor = AppTheme.error;
        } else {
          lastMessageText = 'Intake submitted. Choose a pro to continue.';
          statusColor = AppTheme.gray;
        }

        final List<Map<String, dynamic>> messagesList = [];
        messagesList.add({
          'sender': 'sys',
          'text': 'Booking request submitted',
          'time': '',
        });

        if (job['timeline']?['acceptedAt'] != null) {
          messagesList.add({
            'sender': 'sys',
            'text': 'Booking confirmed by provider',
            'time': '',
          });
          messagesList.add({
            'sender': 'pro',
            'text':
                'Hi! Looking forward to helping you with this. Let me know if there are any specific instructions.',
            'time': 'Accepted',
          });
        }

        if (status == 'quote_ready') {
          messagesList.add({
            'sender': 'sys',
            'text': 'Quote ready to review',
            'time': '',
          });
          messagesList.add({
            'sender': 'pro',
            'text':
                'Hello! I have uploaded the quote limit for this job: \$${quoteAmount.toStringAsFixed(2)}. Please review and approve it.',
            'time': 'Quote ready',
          });
        }

        if (job['timeline']?['enRouteAt'] != null) {
          messagesList.add({
            'sender': 'sys',
            'text': 'Provider is en route',
            'time': '',
          });
          messagesList.add({
            'sender': 'pro',
            'text': 'On my way — ETA about 20 minutes.',
            'time': 'En route',
          });
        }

        if (job['timeline']?['arrivedAt'] != null) {
          messagesList.add({
            'sender': 'sys',
            'text': 'Provider arrived',
            'time': '',
          });
        }

        if (job['timeline']?['inProgressAt'] != null) {
          messagesList.add({
            'sender': 'sys',
            'text': 'Work in progress',
            'time': '',
          });
        }

        if (job['timeline']?['completedAt'] != null) {
          messagesList.add({
            'sender': 'sys',
            'text': 'Job completed',
            'time': '',
          });
          messagesList.add({
            'sender': 'pro',
            'text':
                'Thanks! Receipt and warranty info are synced. Invoice amount: \$${invoiceAmount.toStringAsFixed(2)}.',
            'time': 'Completed',
          });
        }

        if (messagesList.length <= 1) {
          messagesList.add({
            'sender': 'pro',
            'text':
                'Hello! I will be helping you with this service. Let me know if you have any questions.',
            'time': 'Created',
          });
        }

        final timeString = job['createdAt'] != null
            ? _formatTimeAgo(job['createdAt'])
            : 'Just now';

        threads.add({
          'id': job['workOrderId']?.toString() ?? '',
          'proName': proName,
          'trade': serviceCategory,
          'avatarChar': proName.isNotEmpty ? proName[0].toUpperCase() : 'S',
          'woTitle': '$serviceCategory · #$woNumber',
          'lastMessage': lastMessageText,
          'time': timeString,
          'rawTime': job['createdAt'] ?? '',
          'unreadCount': (status == 'quote_ready') ? 1 : 0,
          'status': _capitalize(status),
          'statusColor': statusColor,
          'messages': messagesList,
        });

        // 2. Activity Feed entries
        final createdAtStr = job['createdAt'] != null
            ? _formatTimeAgo(job['createdAt'])
            : 'Just now';

        activityFeed.add({
          'title': 'Booking request submitted',
          'sub': '$serviceCategory · #$woNumber matched with $proName',
          'time': createdAtStr,
          'rawTime': job['createdAt'] ?? '',
          'icon': Icons.assignment,
          'color': AppTheme.gray,
        });

        if (status == 'quote_ready') {
          activityFeed.add({
            'title': 'Quote Ready to Review',
            'sub':
                '$serviceCategory · #$woNumber · \$${quoteAmount.toStringAsFixed(2)} quote cap limit',
            'time': createdAtStr,
            'rawTime': job['createdAt'] ?? '',
            'icon': Icons.description,
            'color': AppTheme.orange500,
          });
        }

        if (job['timeline']?['enRouteAt'] != null) {
          final enRouteTime = _formatTimeAgo(job['timeline']['enRouteAt']);
          activityFeed.add({
            'title': '$proName is en route',
            'sub': '$serviceCategory · #$woNumber · arriving shortly',
            'time': enRouteTime,
            'rawTime': job['timeline']['enRouteAt'],
            'icon': Icons.airport_shuttle,
            'color': AppTheme.teal500,
          });
        }

        if (job['timeline']?['completedAt'] != null) {
          final completedTime = _formatTimeAgo(job['timeline']['completedAt']);
          activityFeed.add({
            'title': 'Job Completed',
            'sub': 'Your $serviceCategory job #$woNumber is complete',
            'time': completedTime,
            'rawTime': job['timeline']['completedAt'],
            'icon': Icons.check_circle_outline,
            'color': AppTheme.success,
          });

          if (rewardsEarned > 0) {
            activityFeed.add({
              'title':
                  'You earned \$${rewardsEarned.toStringAsFixed(0)} in service credits',
              'sub': '$serviceCategory · #$woNumber YTD reward band',
              'time': completedTime,
              'rawTime': job['timeline']['completedAt'],
              'icon': Icons.stars,
              'color': AppTheme.orange500,
              'isCredit': true,
              'earnedAmount': '\$${rewardsEarned.toStringAsFixed(0)}',
            });
          }
        }
      }

      threads.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['rawTime'].toString()) ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['rawTime'].toString()) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      activityFeed.sort((a, b) {
        final dateA =
            DateTime.tryParse(a['rawTime'].toString()) ?? DateTime(2000);
        final dateB =
            DateTime.tryParse(b['rawTime'].toString()) ?? DateTime(2000);
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _threads = threads;
          _activityFeed = activityFeed;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      _isRefreshing = false;
    }
  }

  String _formatTimeAgo(String isoStr) {
    try {
      final dt = DateTime.parse(isoStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${diff.inDays}d ago';
      }
    } catch (_) {
      return 'Just now';
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text.replaceAll('_', ' ').split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _openThread(Map<String, dynamic> thread) {
    setState(() {
      thread['unreadCount'] = 0;
    });
    // Legacy fallback – will not normally be called since Messages tab uses Stream
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          contractorId: thread['id']?.toString() ?? 'unknown',
          contractorName: thread['proName'] ?? 'Pro',
          workOrderTitle: thread['woTitle'],
          workOrderStatus: thread['status'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.orange500),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(_errorMessage!,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchInboxData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSegmentedControl(),
        Expanded(
          child:
              _activeSegment == 0 ? _buildThreadsList() : _buildActivityList(),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: SlidingSegmentControl(
        currentIndex: _activeSegment,
        activeColor: const Color(0xFF1B3C6E),
        items: const [
          SegmentItem(label: 'Messages'),
          SegmentItem(label: 'Activity'),
        ],
        onSegmentChanged: (val) {
          setState(() {
            _activeSegment = val;
          });
        },
      ),
    );
  }

  /// Messages tab: real-time channel list powered by Stream Chat
  Widget _buildThreadsList() {
    final client = StreamService.instance.client;
    if (client == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline,
                size: 48, color: AppTheme.gray.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'Connect to see messages',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: AppTheme.gray),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () async {
                try {
                  await StreamService.instance.ensureConnected();
                  if (mounted) {
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Connect Chat'),
            ),
          ],
        ),
      );
    }
    final currentUser = client.state.currentUser;

    if (currentUser == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline,
                size: 48, color: AppTheme.gray.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'Connect to see messages',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: AppTheme.gray),
            ),
          ],
        ),
      );
    }

    return StreamChat(
      client: client,
      child: StreamChannelListView(
        controller: StreamChannelListController(
          client: client,
          filter: Filter.in_('members', [currentUser.id]),
          channelStateSort: const [
            SortOption('last_message_at', direction: SortOption.DESC),
          ],
          limit: 30,
        ),
        onChannelTap: (channel) {
          final members = channel.state?.members ?? [];
          final other = members.firstWhere(
            (m) => m.userId != currentUser.id,
            orElse: () => members.first,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                contractorId: other.userId ?? 'unknown',
                contractorName: other.user?.name ??
                    channel.extraData['name']?.toString() ??
                    'Pro',
              ),
            ),
          );
        },
        emptyBuilder: (_) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 48, color: AppTheme.gray.withOpacity(0.4)),
              const SizedBox(height: 12),
              const Text(
                'No messages yet',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppTheme.gray),
              ),
              const SizedBox(height: 4),
              const Text(
                'Start a conversation from a contractor profile or booking flow.',
                style: TextStyle(color: AppTheme.gray, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        loadingBuilder: (_) => const Center(
          child: CircularProgressIndicator(color: AppTheme.orange500),
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    if (_activityFeed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none,
                size: 48, color: AppTheme.gray.withOpacity(0.5)),
            const SizedBox(height: 12),
            const Text(
              'No activity yet',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.gray),
            ),
            const SizedBox(height: 4),
            const Text(
              'Updates on your service requests will appear here.',
              style: const TextStyle(color: AppTheme.gray, fontSize: 12),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _activityFeed.length,
      itemBuilder: (context, index) {
        final act = _activityFeed[index];
        final isCredit = act['isCredit'] == true;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: act['color'].withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(act['icon'] as IconData,
                      color: act['color'] as Color, size: 18),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: isCredit
                                ? const Text.rich(
                                    TextSpan(
                                      text: 'You earned ',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppTheme.ink),
                                      children: [
                                        TextSpan(
                                          text: '\$24',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.orange500),
                                        ),
                                        TextSpan(text: ' in service credits'),
                                      ],
                                    ),
                                  )
                                : Text(
                                    act['title']!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: AppTheme.ink),
                                  ),
                          ),
                          Text(
                            act['time']!,
                            style: const TextStyle(
                                color: AppTheme.gray, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        act['sub']!,
                        style: const TextStyle(
                            color: AppTheme.gray, fontSize: 11.5),
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
