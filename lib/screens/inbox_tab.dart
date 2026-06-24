import 'package:flutter/material.dart';
import '../theme.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  int _activeSegment = 0; // 0: Messages, 1: Activity

  final List<Map<String, dynamic>> _threads = [
    {
      'id': 'TW-4471',
      'proName': 'Marcus T.',
      'trade': 'HVAC · Select-certified',
      'avatarChar': 'M',
      'woTitle': 'HVAC Tune-Up · #TW-4471',
      'lastMessage': 'On my way — ETA about 20 minutes.',
      'time': '2:18 PM',
      'unreadCount': 2,
      'status': 'En route',
      'statusColor': AppTheme.teal500,
      'messages': [
        {'sender': 'sys', 'text': 'Booking confirmed · Fri, Jun 27', 'time': ''},
        {'sender': 'pro', 'text': 'Hi! Looking forward to the tune-up Friday. Anything I should know about the unit?', 'time': 'Tue 4:02 PM'},
        {'sender': 'homeowner', 'text': 'It\'s a 2-story — the air handler is in the upstairs closet.', 'time': 'Tue 4:15 PM'},
        {'sender': 'pro', 'text': 'Got it — thanks. I\'ll bring the right ladder.', 'time': 'Tue 4:18 PM'},
        {'sender': 'sys', 'text': 'En route · ETA ~2:40 PM', 'time': ''},
        {'sender': 'pro', 'text': 'On my way — ETA about 20 minutes.', 'time': '2:18 PM'},
      ]
    },
    {
      'id': 'TW-4458',
      'proName': 'Priya R.',
      'trade': 'Drain Specialist',
      'avatarChar': 'P',
      'woTitle': 'Drain Cleaning · #TW-4458',
      'lastMessage': 'Thanks! Receipt & warranty info attached.',
      'time': 'Yesterday',
      'unreadCount': 0,
      'status': 'Completed',
      'statusColor': AppTheme.success,
      'messages': [
        {'sender': 'sys', 'text': 'Booking confirmed · Mon, Jun 23', 'time': ''},
        {'sender': 'pro', 'text': 'Hi! Ready for the drain service today.', 'time': 'Mon 9:00 AM'},
        {'sender': 'homeowner', 'text': 'Excellent, see you then.', 'time': 'Mon 9:05 AM'},
        {'sender': 'sys', 'text': 'Completed · Mon, Jun 23', 'time': ''},
        {'sender': 'pro', 'text': 'Thanks! Receipt & warranty info attached.', 'time': 'Mon 4:30 PM'},
      ]
    },
    {
      'id': 'TW-4502',
      'proName': 'Kitchen Remodel',
      'trade': 'Estimator Pro',
      'avatarChar': 'K',
      'woTitle': 'Free estimate · #TW-4502',
      'lastMessage': 'Your quote is ready to review and approve.',
      'time': 'Mon',
      'unreadCount': 1,
      'status': 'Quote ready',
      'statusColor': AppTheme.orange500,
      'messages': [
        {'sender': 'sys', 'text': 'Intake submitted · Mon, Jun 23', 'time': ''},
        {'sender': 'pro', 'text': 'Hi Jordan, I have reviewed the photo uploads and built the estimate.', 'time': 'Mon 11:00 AM'},
        {'sender': 'sys', 'text': 'Quote ready', 'time': ''},
        {'sender': 'pro', 'text': 'Your quote is ready to review and approve.', 'time': 'Mon 11:15 AM'},
      ]
    }
  ];

  final List<Map<String, dynamic>> _activityFeed = [
    {
      'title': 'Marcus is en route',
      'sub': 'HVAC Tune-Up · #TW-4471 · arriving ~2:40 PM',
      'time': '2:18 PM',
      'icon': Icons.airport_shuttle,
      'color': AppTheme.teal500,
    },
    {
      'title': 'You earned \$24 in service credits',
      'sub': 'Drain Cleaning · #TW-4458 · 3% band',
      'time': 'Yesterday',
      'icon': Icons.stars,
      'color': AppTheme.orange500,
      'isCredit': true,
    },
    {
      'title': 'Quote Ready to Review',
      'sub': 'Free estimate · #TW-4502 · standard diagnostic quote cap',
      'time': 'Mon',
      'icon': Icons.description,
      'color': AppTheme.orange500,
    }
  ];

  void _openThread(Map<String, dynamic> thread) {
    setState(() {
      thread['unreadCount'] = 0;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(thread: thread),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSegmentedControl(),
        Expanded(
          child: _activeSegment == 0 ? _buildThreadsList() : _buildActivityList(),
        ),
      ],
    );
  }

  Widget _buildSegmentedControl() {
    int totalUnread = _threads.fold<int>(0, (sum, t) => sum + (t['unreadCount'] as int));

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.pageAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildSegmentItem(0, 'Messages', unreadCount: totalUnread),
            _buildSegmentItem(1, 'Activity'),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label, {int? unreadCount}) {
    final isSelected = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.navy700 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.navy700.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.gray,
                  fontSize: 13,
                ),
              ),
              if (unreadCount != null && unreadCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppTheme.orange500,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThreadsList() {
    return ListView.builder(
      itemCount: _threads.length,
      itemBuilder: (context, index) {
        final thread = _threads[index];
        final unread = (thread['unreadCount'] as int) > 0;
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppTheme.line)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 21,
                  backgroundColor: AppTheme.navyTint,
                  child: Text(
                    thread['avatarChar']!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy700),
                  ),
                ),
                if (unread)
                  Positioned(
                    top: -1,
                    right: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.orange500,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  thread['proName']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy700),
                ),
                Text(
                  thread['time']!,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        thread['woTitle']!,
                        style: const TextStyle(color: AppTheme.teal700, fontSize: 11.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (thread['statusColor'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        thread['status']!,
                        style: TextStyle(
                          color: thread['statusColor'] as Color,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  thread['lastMessage']!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                ),
              ],
            ),
            trailing: unread
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.navy700, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      thread['unreadCount'].toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )
                : const Icon(Icons.chevron_right, color: AppTheme.line),
            onTap: () => _openThread(thread),
          ),
        );
      },
    );
  }

  Widget _buildActivityList() {
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
                  child: Icon(act['icon'] as IconData, color: act['color'] as Color, size: 18),
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
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
                                      children: [
                                        TextSpan(
                                          text: '\$24',
                                          style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange500),
                                        ),
                                        TextSpan(text: ' in service credits'),
                                      ],
                                    ),
                                  )
                                : Text(
                                    act['title']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
                                  ),
                          ),
                          Text(
                            act['time']!,
                            style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        act['sub']!,
                        style: const TextStyle(color: AppTheme.gray, fontSize: 11.5),
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

class ConversationScreen extends StatefulWidget {
  final Map<String, dynamic> thread;

  const ConversationScreen({super.key, required this.thread});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        (widget.thread['messages'] as List<Map<String, String>>).add({
          'sender': 'homeowner',
          'text': text,
          'time': 'Just now',
        });
      });
      _messageController.clear();

      // Auto reply simulation
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            (widget.thread['messages'] as List<Map<String, String>>).add({
              'sender': 'pro',
              'text': 'Got it! TradeWorks dispatcher has log sync. Thanks.',
              'time': 'Just now',
            });
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = widget.thread['messages'] as List<Map<String, dynamic>>;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.navyTint,
              child: Text(
                widget.thread['avatarChar']!,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navy700),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.thread['proName']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.navy700),
                ),
                Text(
                  widget.thread['trade']!,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppTheme.line, height: 0.5),
        ),
      ),
      body: Column(
        children: [
          // 12. Pinned work order context bar
          _buildWorkOrderContextBar(),
          // Chat messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index];
                if (msg['sender'] == 'sys') {
                  return _buildSystemLine(msg['text']);
                }
                final isOwner = msg['sender'] == 'homeowner';
                return _buildMessageBubble(msg['text'], msg['time'], isOwner);
              },
            ),
          ),
          // 16. Composer bar
          _buildComposerBar(),
        ],
      ),
    );
  }

  Widget _buildWorkOrderContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(
        color: AppTheme.navyTint,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.thread['woTitle']!,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.navy700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Fri, Jun 27 · 1:00–3:00 PM · status: ${widget.thread['status']}',
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Work Order Details', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text(
                    'Title: ${widget.thread['woTitle']}\n\n'
                    'Pro: ${widget.thread['proName']}\n'
                    'Specialty: ${widget.thread['trade']}\n'
                    'Status: ${widget.thread['status']}\n\n'
                    'Upfront rates are pre-negotiated by TradeWorks AI dispatcher.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            child: const Text(
              'View work order ›',
              style: TextStyle(color: AppTheme.teal500, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLine(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.navyTint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, color: AppTheme.navy700, size: 13),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(String text, String time, bool isOwner) {
    return Align(
      alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: isOwner ? AppTheme.navy700 : Colors.white,
          border: isOwner ? null : Border.all(color: AppTheme.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isOwner ? 14 : 5),
            bottomRight: Radius.circular(isOwner ? 5 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isOwner ? Colors.white : AppTheme.ink,
                fontSize: 12.5,
                height: 1.38,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: isOwner ? const Color(0xFFB9CAE0) : AppTheme.gray,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Camera access requested for attachments.')),
              );
            },
            child: const SizedBox(
              width: 34,
              height: 34,
              child: Icon(Icons.photo_camera, color: AppTheme.gray, size: 21),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 38,
              alignment: Alignment.center,
              child: TextField(
                controller: _messageController,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Message ${widget.thread['proName']}…',
                  hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                  filled: true,
                  fillColor: AppTheme.pageAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppTheme.line),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppTheme.orange500,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.send, color: Colors.white, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}
