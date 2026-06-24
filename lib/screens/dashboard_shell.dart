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
import 'onboarding_slider.dart';
import '../services/auth_service.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _currentIndex = 0;
  String? _searchQuery;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
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
    final List<Widget> tabs = [
      HomeTab(
        onBookTap: () {
          setState(() {
            _searchQuery = null;
            _selectedCategory = null;
            _currentIndex = 1; // Go to Search Tab
          });
        },
        onJobTap: (job) {
          _showBookingModal(job);
        },
        onInboxTap: _showInboxModal,
        onSearchQuery: (query) {
          setState(() {
            _searchQuery = query;
            _selectedCategory = null;
            _currentIndex = 1;
          });
        },
        onCategorySelected: (cat) {
          setState(() {
            _selectedCategory = cat;
            _searchQuery = null;
            _currentIndex = 1;
          });
        },
      ),
      SearchTab(
        onBookPro: (pro) {
          _showBookingModal(pro);
        },
        initialSearchQuery: _searchQuery,
        initialCategory: _selectedCategory,
      ),
      BookingsTab(
        onBookNowTap: () {
          setState(() {
            _searchQuery = null;
            _selectedCategory = null;
            _currentIndex = 1; // Go to Search Tab
          });
        },
      ),
      RewardTab(
        onBookTap: () {
          setState(() {
            _searchQuery = null;
            _selectedCategory = null;
            _currentIndex = 1; // Go to Search Tab
          });
        },
      ),
      ProfileTab(
        onLogout: () async {
          await AuthService.instance.logout();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              createPremiumRoute(const OnboardingSlider()),
              (route) => false,
            );
          }
        },
        onRewardsTap: () {
          setState(() {
            _currentIndex = 3; // Go to Rewards Tab
          });
        },
      ),
    ];

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
            children: tabs,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final Set<String> expandedQuestions = {};

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                Widget buildFAQItem(String question, String answer) {
                  final isExpanded = expandedQuestions.contains(question);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.pageAlt.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.line.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          title: Text(
                            question,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy700),
                          ),
                          trailing: AnimatedRotation(
                            turns: isExpanded ? 0.125 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.add,
                              color: isExpanded ? AppTheme.orange500 : AppTheme.navy700,
                              size: 18,
                            ),
                          ),
                          onTap: () {
                            setModalState(() {
                              if (isExpanded) {
                                expandedQuestions.remove(question);
                              } else {
                                expandedQuestions.add(question);
                              }
                            });
                          },
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Text(
                              answer,
                              style: const TextStyle(color: AppTheme.ink, fontSize: 12.5, height: 1.45),
                            ),
                          ),
                          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  );
                }

                Widget buildFAQHeader(String title) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 18.0, bottom: 8.0, left: 4.0),
                    child: Text(
                      title,
                      style: AppTheme.headingStyle.copyWith(
                        fontSize: 13.5,
                        color: const Color(0xFF1B3C6E),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.04,
                      ),
                    ),
                  );
                }

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
                      const SizedBox(height: 16),
                      Text(
                        'Frequently Asked Questions',
                        style: AppTheme.headingStyle.copyWith(fontSize: 16, color: AppTheme.navy700),
                      ),
                      const SizedBox(height: 4),

                      buildFAQHeader('🏡 Home & Search Page FAQs'),
                      buildFAQItem(
                        'How does the TradeWorks One network work?',
                        'You join for free, browse vetted and insured home service professionals across 31 categories, and see upfront pricing before you book. You book directly on their calendar, and you earn 3–7% cash back in service credits on every completed job.',
                      ),
                      buildFAQItem(
                        'How are contractors vetted?',
                        'Every contractor in the network is verified for active state licenses and general liability insurance before taking any job. We verify credentials so you don\'t have to chase proof of coverage.',
                      ),
                      buildFAQItem(
                        'What is GEO/AEO optimization?',
                        'Generative Engine Optimization (GEO) and Answer Engine Optimization (AEO) are strategies to optimize your contractor website so it gets cited by AI search tools like ChatGPT, Claude, Perplexity, and Google AI Overviews, ensuring your business stays visible where modern buyers search.',
                      ),

                      buildFAQHeader('📅 Bookings Page FAQs'),
                      buildFAQItem(
                        'Can I cancel or reschedule a booking?',
                        'Yes, you can cancel or reschedule any future booked job before the work begins for free with no homeowner fees. Cancellations or reschedules are handled directly via the Bookings tab.',
                      ),

                      buildFAQHeader('🏆 Rewards Page FAQs'),
                      buildFAQItem(
                        'How do TradeWorks service credits work?',
                        'Earn 3% → 5% → 7% back as you spend more in a year — each rate applies only to spend within its YTD band (no retroactive re-crediting). Credits are service credits that apply toward any booking (never count as new spend). They are non-cashable and non-transferable, and reset every January 1.',
                      ),
                      buildFAQItem(
                        'Do my service credits expire?',
                        'Yes, each service credit expires 24 months after you earn it. Check your Rewards Tab ledger to see credit-specific expiry logs.',
                      ),
                      buildFAQItem(
                        'How do I redeem my service credits?',
                        'Credits apply automatically to your next booking. To redeem, just reach out to support and we\'ll apply them for you. In-app redemption is coming soon as a fast-follow feature.',
                      ),

                      buildFAQHeader('👤 Profile & Home Profile FAQs'),
                      buildFAQItem(
                        'How is my Home Profile information used?',
                        'We use your home profile (square footage, year built, bedrooms, bathrooms, HVAC, water heater, roof ages) to suggest timely maintenance and pre-fill your bookings. It is kept secure and isn\'t shared beyond the specific pro you book.',
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
