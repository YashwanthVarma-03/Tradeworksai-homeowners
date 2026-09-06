import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';
import '../utils/app_error_utils.dart';
import '../widgets/offline_state.dart';
import '../services/stream_service.dart';
import 'chat_screen.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Messages',
          style: TextStyle(
            color: AppTheme.navy700,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.line),
        ),
      ),
      body: const InboxTab(),
    );
  }
}

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

/// Shows the booking conversation history when a provider has not yet been
/// assigned a live Stream Chat identity. This keeps every booking thread
/// readable instead of sending the user to a broken chat connection.
class BookingConversationScreen extends StatelessWidget {
  final String contractorName;
  final String workOrderTitle;
  final List<Map<String, dynamic>> messages;

  const BookingConversationScreen({
    super.key,
    required this.contractorName,
    required this.workOrderTitle,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageAlt,
      appBar: AppBar(
        title: Text(
          contractorName,
          style: const TextStyle(
            color: AppTheme.navy700,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(42),
          child: Container(
            alignment: Alignment.centerLeft,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.navyTint,
              border: Border(bottom: BorderSide(color: AppTheme.line)),
            ),
            child: Text(
              workOrderTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
        itemCount: messages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Live messaging becomes available once the provider connects to this booking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.gray, fontSize: 12, height: 1.35),
              ),
            );
          }

          final message = messages[index];
          final sender = message['sender']?.toString() ?? 'sys';
          final isSystem = sender == 'sys';
          final isHomeowner = sender == 'me';
          if (isSystem) {
            return Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.line),
                ),
                child: Text(
                  message['text']?.toString() ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }

          final color = isHomeowner ? AppTheme.navy700 : Colors.white;
          final foreground = isHomeowner ? Colors.white : AppTheme.ink;
          return Align(
            alignment: isHomeowner ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isHomeowner ? 16 : 4),
                    bottomRight: Radius.circular(isHomeowner ? 4 : 16),
                  ),
                  border: isHomeowner ? null : Border.all(color: AppTheme.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message['text']?.toString() ?? '',
                      style: TextStyle(color: foreground, fontSize: 14, height: 1.35),
                    ),
                    if ((message['time']?.toString().trim() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        message['time'].toString(),
                        style: TextStyle(
                          color: isHomeowner ? Colors.white70 : AppTheme.gray,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
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
      if (tabs is Map) {
        if (tabs['active'] != null) allJobs.addAll(tabs['active']);
        if (tabs['scheduled'] != null) allJobs.addAll(tabs['scheduled']);
        if (tabs['history'] != null) allJobs.addAll(tabs['history']);
      }

      final List<Map<String, dynamic>> threads = [];
      final List<Map<String, dynamic>> activityFeed = [];

      for (final rawJob in allJobs) {
        if (rawJob is! Map) continue;
        final job = Map<String, dynamic>.from(rawJob);
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
          'chatUserId': StreamService.instance.resolveMessagingUserId(job),
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
          _errorMessage = AppErrorUtils.friendlyMessage(e);
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
    final chatUserId = thread['chatUserId']?.toString().trim() ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => chatUserId.isEmpty
            ? BookingConversationScreen(
                contractorName: thread['proName']?.toString() ?? 'Service Pro',
                workOrderTitle: thread['woTitle']?.toString() ?? '',
                messages: List<Map<String, dynamic>>.from(
                  thread['messages'] as List? ?? const [],
                ),
              )
            : ChatScreen(
                contractorId: chatUserId,
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
      return OfflineState(
        onRetry: _fetchInboxData,
        message: _errorMessage,
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
    if (_threads.isEmpty) {
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Start a conversation from a contractor profile or booking flow.',
                style: TextStyle(color: AppTheme.gray, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.orange500,
      onRefresh: () => _fetchInboxData(showLoading: false),
      child: ListView.separated(
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final thread = _threads[index];
          final unreadCount = (thread['unreadCount'] as num?)?.toInt() ?? 0;
          final statusColor = thread['statusColor'] as Color? ?? AppTheme.gray;
          return ListTile(
            onTap: () => _openThread(thread),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: statusColor.withOpacity(0.12),
              child: Text(
                thread['avatarChar']?.toString() ?? 'S',
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(
              thread['proName']?.toString() ?? 'Service Pro',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Text(
                  thread['woTitle']?.toString() ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
                ),
                const SizedBox(height: 3),
                Text(
                  thread['lastMessage']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.ink, fontSize: 12),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  thread['time']?.toString() ?? '',
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.orange500,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
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
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.gray),
            ),
            const SizedBox(height: 4),
            const Text(
              'Updates on your service requests will appear here.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12),
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
