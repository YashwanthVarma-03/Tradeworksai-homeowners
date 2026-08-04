import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'bookings_tab.dart';
import 'inbox_tab.dart';
import 'reward_tab.dart';
import 'profile_tab.dart';
import 'booking_stepper.dart';
import 'category_guides_screen.dart';
import 'support_page.dart';
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
  int _bookingsInitialSegment = 0;
  Key _bookingsTabKey = UniqueKey();

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Booking confirmed!'),
                  ],
                ),
                backgroundColor: AppTheme.success,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'View Booking',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() {
                      _bookingsInitialSegment = 1;
                      _currentIndex = 2; // Switch to Bookings Tab
                      _bookingsTabKey = UniqueKey();
                    });
                  },
                ),
              ),
            );
            // Default behavior if not explicitly clicking 'View Booking':
            setState(() {
              _bookingsInitialSegment = 1; // It goes to scheduled by default too if you want, or stay 0. We'll set 1 for convenience since it's the latest booking.
              _currentIndex = 2;
              _bookingsTabKey = UniqueKey();
            });
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

  Future<void> _openCategoryGuides() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryGuidesScreen(
          onBrowseCategory: (category) async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrowseScreen(initialCategory: category),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = [
      HomeTab(
        onBookTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BrowseScreen()),
          );
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 1;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onJobTap: (job) {
          _showBookingModal(job);
        },
        onInboxTap: () {
          setState(() {
            _currentIndex = 1; // Go to Inbox Tab
          });
        },
        onSearchQuery: (query) async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrowseScreen(initialSearchQuery: query),
            ),
          );
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 1;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onCategorySelected: (cat) async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrowseScreen(initialCategory: cat),
            ),
          );
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 1;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onGuidesTap: _openCategoryGuides,
      ),
      const InboxTab(),
      BookingsTab(
        key: _bookingsTabKey,
        initialSegment: _bookingsInitialSegment,
        onBookNowTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BrowseScreen()),
          );
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 1;
              _currentIndex = 2; // Refresh Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
      ),
      RewardTab(
        onBookTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BrowseScreen()),
          );
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 1;
              _currentIndex = 2; // Go to Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
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
          AnimatedGiftIcon(
            onTap: () {
              _showOffersSheet();
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
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.mail_outline),
                    Positioned(
                      right: -2,
                      top: -2,
                      child: SizedBox(
                        width: 8,
                        height: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.orange500,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                activeIcon: Icon(Icons.mail),
                label: 'Inbox',
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

  void _showOffersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.stars, color: AppTheme.orange500, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Exclusive Offers for You',
                        style: AppTheme.headingStyle.copyWith(fontSize: 18, color: AppTheme.navy700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        _buildOfferCard(
                          title: '\$50 Off Summer HVAC Special',
                          desc: 'Get \$50 off any HVAC repair or maintenance service this month.',
                          code: 'SUMMER50',
                          partner: 'AirFlow HVAC Specialists',
                        ),
                        _buildOfferCard(
                          title: 'Free Water Quality Test',
                          desc: 'Book a plumbing diagnostic and get a water hardness/purity test free.',
                          code: 'PUREWATER',
                          partner: 'Rooter & Plumb Co.',
                        ),
                        _buildOfferCard(
                          title: 'Double Rewards Points',
                          desc: 'Earn 6% back in service credits on your next landscaping booking.',
                          code: 'DOUBLEGREEN',
                          partner: 'TradeWorks Network',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOfferCard({
    required String title,
    required String desc,
    required String code,
    required String partner,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.orangeTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.orange500.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                partner,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.orange700, fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navy700, fontSize: 14.5),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(color: AppTheme.gray, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class BrowseScreen extends StatelessWidget {
  final String? initialSearchQuery;
  final String? initialCategory;

  const BrowseScreen({
    super.key,
    this.initialSearchQuery,
    this.initialCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Browse Services',
          style: AppTheme.headingStyle.copyWith(
            color: AppTheme.navy700,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(color: AppTheme.line, height: 0.5),
        ),
      ),
      body: SunriseBackground(
        child: SafeArea(
          child: SearchTab(
            onBookPro: (pro) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return BookingStepper(
                    proDetails: pro,
                    onBookingComplete: () {
                      Navigator.pop(context); // close stepper
                      Navigator.pop(context, true); // pop BrowseScreen returning true
                      // We can handle redirect via dashboard state if needed, but BrowseScreen handles its own pop
                    },
                  );
                },
              );
            },
            initialSearchQuery: initialSearchQuery,
            initialCategory: initialCategory,
          ),
        ),
      ),
    );
  }
}

class AnimatedGiftIcon extends StatefulWidget {
  final VoidCallback onTap;
  const AnimatedGiftIcon({super.key, required this.onTap});

  @override
  State<AnimatedGiftIcon> createState() => _AnimatedGiftIconState();
}

class _AnimatedGiftIconState extends State<AnimatedGiftIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            double lidOpenProgress = 0.0;
            double wiggleProgress = 0.0;
            final t = _controller.value;

            // Timeline:
            // 0.0 to 0.15: Wiggle
            if (t >= 0.0 && t < 0.15) {
              final wt = t / 0.15;
              // 3 oscillations
              wiggleProgress = math.sin(wt * math.pi * 6);
            }
            // 0.15 to 0.30: Lid open
            else if (t >= 0.15 && t < 0.30) {
              final ot = (t - 0.15) / 0.15;
              lidOpenProgress = Curves.easeOutBack.transform(ot);
            }
            // 0.30 to 0.70: Hold open
            else if (t >= 0.30 && t < 0.70) {
              lidOpenProgress = 1.0;
            }
            // 0.70 to 0.85: Close lid
            else if (t >= 0.70 && t < 0.85) {
              final ct = (t - 0.70) / 0.15;
              lidOpenProgress = 1.0 - Curves.easeIn.transform(ct);
            }
            // 0.85 to 1.0: Idle (0)

            return CustomPaint(
              size: const Size(26, 26),
              painter: GiftBoxPainter(
                lidOpenProgress: lidOpenProgress,
                wiggleProgress: wiggleProgress,
              ),
            );
          },
        ),
      ),
    );
  }
}

class GiftBoxPainter extends CustomPainter {
  final double lidOpenProgress; // 0.0 to 1.0
  final double wiggleProgress;  // -1.0 to 1.0

  GiftBoxPainter({required this.lidOpenProgress, required this.wiggleProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    canvas.save();
    canvas.scale(w / 24.0, h / 24.0);

    // Apply wiggle around the bottom center (12, 22)
    if (wiggleProgress != 0) {
      canvas.translate(12, 22);
      canvas.rotate(wiggleProgress * 0.08); // max angle ~4.5 degrees
      canvas.translate(-12, -22);
    }

    final redPaint = Paint()
      ..color = const Color(0xFFD32F2F) // Red box color (standard red/gold requested)
      ..style = PaintingStyle.fill;

    final goldPaint = Paint()
      ..color = const Color(0xFFFFC107) // Gold strip / ribbon color
      ..style = PaintingStyle.fill;

    final goldStrokePaint = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // 1. Draw Box Body: centered horizontally from x=5 to x=19 (width=14), y=11 to y=21 (height=10)
    final bodyRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(5, 11, 14, 10),
      const Radius.circular(1.2),
    );
    canvas.drawRRect(bodyRect, redPaint);

    // Draw vertical ribbon in the center of body (x=10.5 to x=13.5)
    final bodyRibbon = const Rect.fromLTWH(10.5, 11, 3, 10);
    canvas.drawRect(bodyRibbon, goldPaint);

    // 2. Draw Box Lid & Bow (which will animate)
    canvas.save();

    // Lid closed bounds: x=3.5 to x=20.5 (width=17), y=8 to y=11 (height=3)
    // Pivot at bottom-right of the lid: (19, 11)
    final double lift = lidOpenProgress * 4.0;
    final double rotate = lidOpenProgress * -0.22; // rotate up/left

    final double px = 17.5;
    final double py = 11.0;

    canvas.translate(px, py);
    canvas.rotate(rotate);
    canvas.translate(-px, -py - lift);

    // Draw Lid Rect
    final lidRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 8.0, 17, 3),
      const Radius.circular(0.8),
    );
    canvas.drawRRect(lidRect, redPaint);

    // Lid Ribbon
    final lidRibbon = const Rect.fromLTWH(10.5, 8.0, 3, 3);
    canvas.drawRect(lidRibbon, goldPaint);

    // Draw Bow Loops
    // Left loop (curve from center (12, 8) up left and back)
    final leftLoopPath = Path()
      ..moveTo(12, 8.0)
      ..cubicTo(8, 4.0, 8, 8.0, 12, 8.0)
      ..close();
    canvas.drawPath(leftLoopPath, goldStrokePaint);

    // Right loop (curve from center (12, 8) up right and back)
    final rightLoopPath = Path()
      ..moveTo(12, 8.0)
      ..cubicTo(16, 4.0, 16, 8.0, 12, 8.0)
      ..close();
    canvas.drawPath(rightLoopPath, goldStrokePaint);

    // Bow Center Knot
    final knot = RRect.fromRectAndRadius(
      const Rect.fromLTWH(11.0, 7.0, 2, 1.5),
      const Radius.circular(0.5),
    );
    canvas.drawRRect(knot, goldPaint);

    canvas.restore(); // restore lid transforms
    canvas.restore(); // restore wiggle transforms
  }

  @override
  bool shouldRepaint(covariant GiftBoxPainter oldDelegate) {
    return oldDelegate.lidOpenProgress != lidOpenProgress ||
        oldDelegate.wiggleProgress != wiggleProgress;
  }
}
