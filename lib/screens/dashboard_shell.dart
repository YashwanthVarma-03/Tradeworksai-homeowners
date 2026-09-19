import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import 'book_flow.dart';
import 'account/home_profile.dart';
import 'home_tab.dart';
import 'search_tab.dart';
import 'bookings_tab.dart';
import 'reward_tab.dart';
import 'profile_tab.dart';
import 'category_guides_screen.dart';
import 'inbox_tab.dart';
import 'guest_experience.dart';
import 'login_page.dart';
import 'signup_page.dart';
import 'support_page.dart';
import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../services/service_location.dart';
import '../widgets/main_bottom_navigation.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _bookingsInitialSegment = 0;
  Key _bookingsTabKey = UniqueKey();
  Timer? _backgroundSyncTimer;

  @override
  void initState() {
    super.initState();
    // A manually entered ZIP is only a one-page search override. Starting a
    // new shell (app launch, login, or logout) must never inherit it.
    unawaited(ServiceLocation.clear());
    AppTabNavigation.requestedTab.addListener(_applyRequestedTab);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService.instance.isAuthenticated) {
        unawaited(HomeownerService.instance.primeAuthenticatedCache());
        _startBackgroundSync();
      }
    });
  }

  @override
  void dispose() {
    _backgroundSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    AppTabNavigation.requestedTab.removeListener(_applyRequestedTab);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (AuthService.instance.isAuthenticated) {
        unawaited(HomeownerService.instance.syncInBackground());
        _startBackgroundSync();
      }
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundSyncTimer?.cancel();
      _backgroundSyncTimer = null;
    }
  }

  void _startBackgroundSync() {
    if (!AuthService.instance.isAuthenticated) return;
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(HomeownerService.instance.syncInBackground());
    });
  }

  void _applyRequestedTab() {
    final index = AppTabNavigation.requestedTab.value;
    if (index == null || !mounted || index < 0 || index > 4) return;
    _selectTab(index);
    AppTabNavigation.requestedTab.value = null;
  }

  void _selectTab(int index) {
    if (index == _currentIndex) return;
    if (AuthService.instance.isAuthenticated) {
      unawaited(ServiceLocation.clear());
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _resetAuthenticatedLocation() async {
    if (AuthService.instance.isAuthenticated) {
      await ServiceLocation.clear();
    }
  }

  Future<void> _openBookingFlow(
    Map<String, dynamic> pro, {
    bool popCurrentRouteOnSuccess = false,
  }) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BookFlowScreen(pro: Map<String, dynamic>.from(pro)),
      ),
    );

    if (result == BookFlowExit.changeContractor) return;
    final booked = result == true;
    if (!booked || !mounted) return;
    if (popCurrentRouteOnSuccess && Navigator.canPop(context)) {
      Navigator.pop(context, true);
      return;
    }

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
            unawaited(ServiceLocation.clear());
            setState(() {
              _bookingsInitialSegment = 0;
              _currentIndex = 2;
              _bookingsTabKey = UniqueKey();
            });
          },
        ),
      ),
    );

    unawaited(ServiceLocation.clear());
    setState(() {
      _bookingsInitialSegment = 0;
      _currentIndex = 2;
      _bookingsTabKey = UniqueKey();
    });
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
                builder: (context) => BrowseScreen(
                  initialCategory: category,
                  showAppBar: true,
                ),
              ),
            );
            await _resetAuthenticatedLocation();
          },
        ),
      ),
    );
    await _resetAuthenticatedLocation();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = !AuthService.instance.isAuthenticated;
    void openLogin() => Navigator.push(
          context,
          createPremiumRoute(const LoginPage()),
        );
    void openSignup() => Navigator.push(
          context,
          createPremiumRoute(const SignupPage()),
        );
    Future<void> openBrowse({String? query, String? category}) async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BrowseScreen(
            initialSearchQuery: query,
            initialCategory: category,
            initialAllShowsCategories: category == 'All',
            showAppBar: true,
          ),
        ),
      );
    }

    if (isGuest) {
      final guestTabs = <Widget>[
        HomeTab(
          isGuest: true,
          onBookTap: () => openBrowse(),
          onJobTap: (_) {},
          onInboxTap: () {},
          onHelpTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SupportPage()),
            );
          },
          onSearchQuery: (query) => openBrowse(query: query),
          onCategorySelected: (category) => openBrowse(category: category),
          onGuidesTap: _openCategoryGuides,
          onManageHomeTap: openSignup,
          onCreateAccount: openSignup,
          onSignIn: openLogin,
        ),
        const BrowseScreen(),
        GuestGateTab(
          icon: Icons.calendar_today_outlined,
          title: 'Sign in to view bookings',
          message:
              'Create an account to book services, track your work orders, and manage appointments.',
          onCreateAccount: openSignup,
          onSignIn: openLogin,
        ),
        GuestGateTab(
          icon: Icons.card_giftcard_outlined,
          title: 'Sign in to earn rewards',
          message:
              'Create an account to earn 3–7% back as service credits on every booking.',
          onCreateAccount: openSignup,
          onSignIn: openLogin,
        ),
        GuestGateTab(
          icon: Icons.person_outline,
          title: 'Sign in to your account',
          message:
              'Create an account to manage your profile, payment methods, home details, and preferences.',
          onCreateAccount: openSignup,
          onSignIn: openLogin,
        ),
      ];
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
            child: IndexedStack(index: _currentIndex, children: guestTabs)),
        bottomNavigationBar: MainBottomNavigation(
          currentIndex: _currentIndex,
          onTap: _selectTab,
        ),
      );
    }
    final List<Widget> tabs = [
      HomeTab(
        onBookTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BrowseScreen(showAppBar: true),
            ),
          );
          await _resetAuthenticatedLocation();
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 0;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onJobTap: (_) {
          unawaited(ServiceLocation.clear());
          setState(() {
            _bookingsInitialSegment = 0;
            _currentIndex = 2;
            _bookingsTabKey = UniqueKey();
          });
        },
        onInboxTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InboxScreen()),
          );
        },
        onHelpTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SupportPage()),
          );
        },
        onSearchQuery: (query) async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrowseScreen(
                initialSearchQuery: query,
                showAppBar: true,
              ),
            ),
          );
          await _resetAuthenticatedLocation();
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 0;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onCategorySelected: (cat) async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BrowseScreen(
                initialCategory: cat,
                initialAllShowsCategories: cat == 'All',
                showAppBar: true,
              ),
            ),
          );
          await _resetAuthenticatedLocation();
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 0;
              _currentIndex = 2; // Bookings Tab
              _bookingsTabKey = UniqueKey();
            });
          }
        },
        onGuidesTap: _openCategoryGuides,
        onManageHomeTap: () async {
          final addresses = List<dynamic>.from(
              HomeownerService.instance.cachedAddresses ?? const []);
          if (addresses.isEmpty) {
            unawaited(ServiceLocation.clear());
            setState(() {
              _currentIndex = 4;
            });
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeProfileScreen(addresses: addresses),
            ),
          );
        },
      ),
      const BrowseScreen(),
      BookingsTab(
        key: _bookingsTabKey,
        initialSegment: _bookingsInitialSegment,
        onBookNowTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BrowseScreen(showAppBar: true),
            ),
          );
          await _resetAuthenticatedLocation();
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 0;
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
            MaterialPageRoute(
              builder: (context) => const BrowseScreen(showAppBar: true),
            ),
          );
          await _resetAuthenticatedLocation();
          if (booked == true) {
            setState(() {
              _bookingsInitialSegment = 0;
              _currentIndex = 2;
              _bookingsTabKey = UniqueKey();
            });
          }
        },
      ),
      ProfileTab(
        onLogout: () async {
          await ServiceLocation.clear();
          await AuthService.instance.logout();
          if (context.mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              createPremiumRoute(const DashboardShell()),
              (route) => false,
            );
          }
        },
        onRewardsTap: () {
          unawaited(ServiceLocation.clear());
          setState(() {
            _currentIndex = 3; // Rewards Tab
          });
        },
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          if (_currentIndex != 0) {
            _selectTab(0);
          } else {
            SystemNavigator.pop();
          }
        },
        child: SunriseBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: tabs,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: MainBottomNavigation(
        currentIndex: _currentIndex,
        onTap: _selectTab,
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
                      const Icon(Icons.stars,
                          color: AppTheme.orange500, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Exclusive Offers for You',
                        style: AppTheme.headingStyle
                            .copyWith(fontSize: 18, color: AppTheme.navy700),
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
                          desc:
                              'Get \$50 off any HVAC repair or maintenance service this month.',
                          code: 'SUMMER50',
                          partner: 'AirFlow HVAC Specialists',
                        ),
                        _buildOfferCard(
                          title: 'Free Water Quality Test',
                          desc:
                              'Book a plumbing diagnostic and get a water hardness/purity test free.',
                          code: 'PUREWATER',
                          partner: 'Rooter & Plumb Co.',
                        ),
                        _buildOfferCard(
                          title: 'Double Rewards Points',
                          desc:
                              'Earn 6% back in service credits on your next landscaping booking.',
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
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.orange700,
                    fontSize: 11),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.orange500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.navy700,
                fontSize: 14.5),
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
  final bool initialAllShowsCategories;
  final bool showAppBar;

  const BrowseScreen({
    super.key,
    this.initialSearchQuery,
    this.initialCategory,
    this.initialAllShowsCategories = false,
    this.showAppBar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: showAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
                onPressed: () => Navigator.pop(context),
              ),
              elevation: 0,
              backgroundColor: Colors.white,
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(0.5),
                child:
                    Divider(height: 0.5, thickness: 0.5, color: AppTheme.line),
              ),
            )
          : null,
      body: SunriseBackground(
        child: SafeArea(
          top: !showAppBar,
          child: SearchTab(
            onBookPro: (pro) async {
              final result = await Navigator.push<Object?>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BookFlowScreen(pro: Map<String, dynamic>.from(pro)),
                ),
              );
              if (result == BookFlowExit.changeContractor) return;
              final booked = result == true;
              if (booked && context.mounted) {
                Navigator.pop(context, true);
              }
            },
            initialSearchQuery: initialSearchQuery,
            initialCategory: initialCategory,
            initialAllShowsCategories: initialAllShowsCategories,
            showSectionBackButton: !showAppBar,
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

class _AnimatedGiftIconState extends State<AnimatedGiftIcon>
    with SingleTickerProviderStateMixin {
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
  final double wiggleProgress; // -1.0 to 1.0

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
      ..color =
          const Color(0xFFD32F2F) // Red box color (standard red/gold requested)
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
