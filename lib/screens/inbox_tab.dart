import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class InboxTab extends StatefulWidget {
  const InboxTab({super.key});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  int _activeSegment = 0; // 0: Messages, 1: AI Stream

  final List<Map<String, dynamic>> _threads = [
    {
      'id': 'thread-1',
      'proName': 'Dave Miller',
      'company': 'Miller Cool Air & Heating',
      'avatarChar': 'D',
      'lastMessage': 'I am on my way. ETA 9:42 PM (12 mins). Let me know if there are gate instructions.',
      'time': '9:30 PM',
      'isUnread': true,
      'messages': [
        {'sender': 'pro', 'text': 'Hi, I will be arriving shortly for your AC diagnostic.', 'time': '9:25 PM'},
        {'sender': 'homeowner', 'text': 'Great! Thank you. I have entered the gate code in the system.', 'time': '9:27 PM'},
        {'sender': 'pro', 'text': 'I am on my way. ETA 9:42 PM (12 mins). Let me know if there are gate instructions.', 'time': '9:30 PM'},
      ]
    },
    {
      'id': 'thread-2',
      'proName': 'Sarah Jenkins',
      'company': 'Jenkins Plumbing Group',
      'avatarChar': 'S',
      'lastMessage': 'Invoice has been sent for the pipe leak fix. Thank you!',
      'time': 'Mar 12',
      'isUnread': false,
      'messages': [
        {'sender': 'pro', 'text': 'Leak is fully repaired. I will submit the work order now.', 'time': '3:40 PM'},
        {'sender': 'homeowner', 'text': 'Awesome work, Sarah.', 'time': '3:42 PM'},
        {'sender': 'pro', 'text': 'Invoice has been sent for the pipe leak fix. Thank you!', 'time': '3:45 PM'},
      ]
    },
    {
      'id': 'thread-3',
      'proName': 'VoltSpark Handyman',
      'company': 'VoltSpark Home Services',
      'avatarChar': 'V',
      'lastMessage': 'Can we schedule the fan install for 2 PM instead?',
      'time': 'Feb 05',
      'isUnread': false,
      'messages': [
        {'sender': 'pro', 'text': 'Can we schedule the fan install for 2 PM instead?', 'time': '9:15 AM'},
      ]
    }
  ];

  final List<Map<String, dynamic>> _aiStreamEvents = [
    {
      'title': 'AI Dispatch: Tech Match Found',
      'desc': 'Matched Dave Miller (Miller Cool Air) for your HVAC emergency diagnostic check. Dispatch ETA is under 12 mins.',
      'time': '9:00 PM',
      'type': 'dispatch',
      'icon': Icons.smart_toy,
      'color': AppTheme.teal500,
    },
    {
      'title': 'Proactive Check-up Triggered',
      'desc': 'AI Assistant detected AC system is 12 years old. Added "Summer AC Check-up" tune-up to your seasonal checklist.',
      'time': '3:15 PM',
      'type': 'checklist',
      'icon': Icons.insights,
      'color': AppTheme.orange500,
    },
    {
      'title': 'Rewards Credited (5% Band)',
      'desc': 'Earned \$7.30 service credits from completed plumbing job (WO-8910). Total reward credits balance updated to \$214.60.',
      'time': 'Mar 12, 2026',
      'type': 'reward',
      'icon': Icons.stars,
      'color': AppTheme.success,
    },
    {
      'title': 'Vetted Insurance Verification Check',
      'desc': 'Verified active state license and \$1M general liability coverage for Jenkins Plumbing Group prior to job start.',
      'time': 'Mar 12, 2026',
      'type': 'security',
      'icon': Icons.verified_user,
      'color': AppTheme.navy700,
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildSegmentedControl(),
          const SizedBox(height: 20),
          Expanded(
            child: _activeSegment == 0 ? _buildThreadsList() : _buildAiStreamList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.pageAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildSegmentItem(0, 'Messages'),
          _buildSegmentItem(1, 'AI Stream'),
        ],
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final isSelected = _activeSegment == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeSegment = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppTheme.navy700 : AppTheme.gray,
              fontSize: 13,
            ),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: thread['isUnread'] ? AppTheme.teal500.withOpacity(0.5) : AppTheme.line.withOpacity(0.5),
              width: thread['isUnread'] ? 1.5 : 0.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: thread['isUnread'] ? AppTheme.teal500 : AppTheme.navy500,
              foregroundColor: Colors.white,
              child: Text(thread['avatarChar']),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  thread['proName'],
                  style: TextStyle(
                    fontWeight: thread['isUnread'] ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.navy700,
                  ),
                ),
                Text(
                  thread['time'],
                  style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread['company'],
                    style: const TextStyle(color: AppTheme.gray, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    thread['lastMessage'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: thread['isUnread'] ? AppTheme.ink : AppTheme.gray,
                      fontSize: 12.5,
                      fontWeight: thread['isUnread'] ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            trailing: thread['isUnread']
                ? Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.orange500,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            onTap: () => _openChatThread(thread),
          ),
        );
      },
    );
  }

  Widget _buildAiStreamList() {
    return ListView.builder(
      itemCount: _aiStreamEvents.length,
      itemBuilder: (context, index) {
        final event = _aiStreamEvents[index];
        return GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (event['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(event['icon'] as IconData, color: event['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            event['title'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy700),
                          ),
                        ),
                        Text(
                          event['time'],
                          style: const TextStyle(color: AppTheme.gray, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event['desc'],
                      style: const TextStyle(color: AppTheme.gray, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openChatThread(Map<String, dynamic> thread) {
    setState(() {
      thread['isUnread'] = false;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final messages = thread['messages'] as List<Map<String, String>>;
        final chatController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  // Title bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppTheme.line, width: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thread['proName'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navy700),
                            ),
                            Text(
                              thread['company'],
                              style: const TextStyle(color: AppTheme.gray, fontSize: 11),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.gray),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Messages list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: messages.length,
                      itemBuilder: (context, idx) {
                        final msg = messages[idx];
                        final isOwner = msg['sender'] == 'homeowner';
                        return Align(
                          alignment: isOwner ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isOwner ? AppTheme.navy700 : AppTheme.pageAlt,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isOwner ? 16 : 0),
                                bottomRight: Radius.circular(isOwner ? 0 : 16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isOwner ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  msg['text']!,
                                  style: TextStyle(
                                    color: isOwner ? Colors.white : AppTheme.ink,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  msg['time']!,
                                  style: TextStyle(
                                    color: isOwner ? Colors.white.withOpacity(0.7) : AppTheme.gray,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Input bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppTheme.line, width: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: chatController,
                            decoration: InputDecoration(
                              hintText: 'Type your message...',
                              hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 13),
                              filled: true,
                              fillColor: AppTheme.pageAlt,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.send, color: AppTheme.teal500),
                          onPressed: () {
                            if (chatController.text.trim().isNotEmpty) {
                              final text = chatController.text.trim();
                              setModalState(() {
                                messages.add({
                                  'sender': 'homeowner',
                                  'text': text,
                                  'time': 'Just now',
                                });
                              });
                              chatController.clear();

                              // Auto reply simulation
                              Future.delayed(const Duration(seconds: 2), () {
                                if (context.mounted) {
                                  setModalState(() {
                                    messages.add({
                                      'sender': 'pro',
                                      'text': 'Got it! The TradeWorks AI Receptionist has updated my schedule. See you soon.',
                                      'time': 'Just now',
                                    });
                                  });
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}
