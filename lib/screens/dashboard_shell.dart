import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'bookings_tab.dart';
import 'inbox_tab.dart';
import 'reward_tab.dart';
import 'profile_tab.dart';
import 'booking_stepper.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      HomeTab(
        onBookTap: () {
          setState(() {
            _currentIndex = 1; // Go to Search Tab
          });
        },
        onJobTap: (job) {
          // Open job booking stepper mockup or navigate
          _showBookingModal(job);
        },
      ),
      SearchTab(
        onBookPro: (pro) {
          _showBookingModal(pro);
        },
      ),
      BookingsTab(
        onBookNowTap: () {
          setState(() {
            _currentIndex = 1; // Go to Search Tab
          });
        },
      ),
      RewardTab(
        onBookTap: () {
          setState(() {
            _currentIndex = 1; // Go to Search Tab
          });
        },
      ),
      ProfileTab(
        onLogout: () {
          Navigator.pop(context); // Go back to LandingPage
        },
      ),
    ];
  }

  void _showBookingModal(Map<String, String> pro) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BookingStepper(
          proDetails: pro,
          onBookingComplete: () {
            Navigator.pop(context);
            setState(() {
              _currentIndex = 2; // Switch to bookings tab
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Booking confirmed! Dispatcher is matching.'),
                  ],
                ),
                backgroundColor: AppTheme.success,
                duration: Duration(seconds: 4),
              ),
            );
          },
        );
      },
    );
  }

  void _showInboxModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Inbox & Messages',
                      style: AppTheme.headingStyle.copyWith(
                        fontSize: 18,
                        color: AppTheme.navy700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.gray),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              const Expanded(
                child: InboxTab(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.network(
              'https://www.tradeworksai.com/images/bot%7Bfavicon%7D.png',
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.smart_toy,
                color: AppTheme.orange500,
                size: 24,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TradeWorks ',
              style: AppTheme.headingStyle.copyWith(
                color: AppTheme.navy700,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: AppTheme.orangeTint,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.orange500, width: 1),
              ),
              child: Text(
                'AI',
                style: AppTheme.headingStyle.copyWith(
                  color: AppTheme.orange500,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail_outline, color: AppTheme.navy700),
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.orange500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              _showInboxModal();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppTheme.navy700),
            onPressed: () {
              // Open assistance modal
              _showAssistModal();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SunriseBackground(
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _tabs,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: AppTheme.orange500,
            unselectedItemColor: AppTheme.gray,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.search_outlined),
                activeIcon: Icon(Icons.search),
                label: 'Browse',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today_outlined),
                activeIcon: Icon(Icons.calendar_today),
                label: 'Bookings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.stars_outlined),
                activeIcon: Icon(Icons.stars),
                label: 'Rewards',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssistModal() {
    final List<bool> faqExpanded = List.generate(4, (_) => false);
    final List<Map<String, String>> faqs = [
      {
        'q': 'How does the TradeWorks One network work?',
        'a': 'You join for free, browse vetted and insured home service professionals across 31 categories, and see upfront pricing before you book. You book directly on their calendar, and you earn 3–7% cash back in service credits on every completed job.'
      },
      {
        'q': 'What are the homeowner rewards bands?',
        'a': 'Membership earns service credits marginal by spend: 3% on the first \$5,000 of annual spend, 5% on spend from \$5,000–\$15,000, and 7% from \$15,000–\$25,000. Credits can be redeemed toward any future services on the network.'
      },
      {
        'q': 'How are contractors vetted?',
        'a': 'Every contractor in the network is verified for active state licenses and general liability insurance before taking any job. We verify credentials so you don\'t have to chase proof of coverage.'
      },
      {
        'q': 'What is GEO/AEO optimization?',
        'a': 'Generative Engine Optimization (GEO) and Answer Engine Optimization (AEO) are strategies to optimize your contractor website so it gets cited by AI search tools like ChatGPT, Claude, Perplexity, and Google AI Overviews, ensuring your business stays visible where modern buyers search.'
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.line,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.smart_toy, color: AppTheme.teal500, size: 28),
                          SizedBox(width: 12),
                          Text(
                            'TradeWorks AI Assistant',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.navy700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Need help matching with a contractor or booking a service? Tap below to text or call the live AI dispatcher.',
                        style: TextStyle(color: AppTheme.gray, fontSize: 13, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: HoverButton(
                              text: 'Text Dispatcher',
                              onPressed: () {
                                Navigator.pop(context);
                                _showInboxModal();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Calling AI Dispatcher line... (555-0199)')),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppTheme.navy700),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('Call Dispatcher', style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Text(
                        'Frequently Asked Questions',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy700),
                      ),
                      const SizedBox(height: 12),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: faqs.length,
                        itemBuilder: (context, index) {
                          final faq = faqs[index];
                          final isExpanded = faqExpanded[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.pageAlt.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.line.withOpacity(0.3)),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  title: Text(
                                    faq['q']!,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy700),
                                  ),
                                  trailing: AnimatedRotation(
                                    turns: isExpanded ? 0.125 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.add,
                                      color: isExpanded ? AppTheme.orange500 : AppTheme.navy700,
                                      size: 20,
                                    ),
                                  ),
                                  onTap: () {
                                    setModalState(() {
                                      faqExpanded[index] = !isExpanded;
                                    });
                                  },
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      faq['a']!,
                                      style: const TextStyle(color: AppTheme.ink, fontSize: 12, height: 1.4),
                                    ),
                                  ),
                                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                                  duration: const Duration(milliseconds: 200),
                                )
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
