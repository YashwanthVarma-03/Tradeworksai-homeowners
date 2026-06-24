import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import 'login_page.dart';
import 'signup_page.dart';

class OnboardingSlider extends StatefulWidget {
  const OnboardingSlider({super.key});

  @override
  State<OnboardingSlider> createState() => _OnboardingSliderState();
}

class _OnboardingSliderState extends State<OnboardingSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SunriseBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Page View
              PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildAnimatedPage(0, _buildHeroSlide(theme, isDark)),
                  _buildAnimatedPage(1, _buildCategoriesSlide(theme, isDark)),
                  _buildAnimatedPage(2, _buildVettingSlide(theme, isDark)),
                  _buildAnimatedPage(3, _buildRewardsSlide(theme, isDark)),
                  _buildAnimatedPage(4, _buildStartSlide(theme, isDark)),
                ],
              ),

              // Skip Button (Top Right) - Hide on last slide
              if (_currentPage < _numPages - 1)
                Positioned(
                  top: 10,
                  right: 16,
                  child: TextButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        _numPages - 1,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : AppTheme.navy700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),

              // Bottom control strip (Indicator + Navigation)
              Positioned(
                bottom: 24,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Indicator Dots
                    Row(
                      children: List.generate(_numPages, (index) => _buildIndicatorDot(index)),
                    ),

                    // Next / Start Button
                    if (_currentPage < _numPages - 1)
                      TextButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.orange500,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorDot(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _currentPage == index;
    return AnimatedScale(
      scale: isSelected ? 1.25 : 0.9,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        height: 8.0,
        width: isSelected ? 24.0 : 8.0,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.orange500 : AppTheme.line.withOpacity(isDark ? 0.35 : 0.65),
          borderRadius: BorderRadius.circular(4.0),
        ),
      ),
    );
  }

  Widget _buildAnimatedPage(int index, Widget child) {
    return child;
  }

  // --- SLIDE 1: HERO VIEW ---
  Widget _buildHeroSlide(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://www.tradeworksai.com/images/bot%7Bfavicon%7D.png',
                height: 48,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.smart_toy,
                  color: AppTheme.orange500,
                  size: 48,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TradeWorksAI',
                style: AppTheme.headingStyle.copyWith(
                  color: isDark ? Colors.white : AppTheme.navy700,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            'One Network for Every Home Service',
            textAlign: TextAlign.center,
            style: AppTheme.textTheme.displayMedium?.copyWith(
              fontSize: 28,
              color: isDark ? Colors.white : AppTheme.navy700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Browse vetted, insured home-service pros across 31 categories, see upfront pricing, and book on their calendar. Earn 3–7% cashback rewards back.',
            textAlign: TextAlign.center,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : AppTheme.gray,
              fontSize: 14.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildMetricChip('31+', 'Categories', isDark),
              _buildMetricChip('3–7%', 'Service Cashback', isDark),
              _buildMetricChip('\$0', 'Platform Fees', isDark),
              _buildMetricChip('24/7', 'AI Assistant Dispatch', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String val, String label, bool isDark) {
    return Container(
      width: 135,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2E4A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3E5A) : AppTheme.line.withOpacity(0.5),
        ),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.teal500 : AppTheme.navy700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.gray,
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 2: 31 SERVICE CATEGORIES ---
  Widget _buildCategoriesSlide(ThemeData theme, bool isDark) {
    final categories = [
      {'name': 'Plumbing', 'desc': 'Drain clearing, leaks, toilet replacement', 'icon': Icons.plumbing},
      {'name': 'HVAC', 'desc': 'AC repair, tune-ups, mini-split installation', 'icon': Icons.ac_unit},
      {'name': 'Handyman', 'desc': 'Furniture assembly, TV mounting, fixtures', 'icon': Icons.build},
      {'name': 'Landscaping', 'desc': 'Lawn mowing, sprinkler repair, sod install', 'icon': Icons.nature_people},
      {'name': 'Cleaning', 'desc': 'Standard house cleaning, deep washing', 'icon': Icons.cleaning_services},
      {'name': 'Electrical', 'desc': 'Wiring, outlets, EV charger installation', 'icon': Icons.flash_on},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '31 Service Categories',
            style: AppTheme.textTheme.headlineLarge?.copyWith(
              fontSize: 22,
              color: isDark ? Colors.white : AppTheme.navy700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upfront, direct pricing on every routine maintenance and repair task.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.gray,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        color: AppTheme.teal500,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: isDark ? Colors.white : AppTheme.navy700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat['desc'] as String,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : AppTheme.gray,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 32), // Space for bottom controls
        ],
      ),
    );
  }

  // --- SLIDE 3: VETTED SECURITY ---
  Widget _buildVettingSlide(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vetted & Insured Trades',
            style: AppTheme.textTheme.headlineLarge?.copyWith(
              fontSize: 22,
              color: isDark ? Colors.white : AppTheme.navy700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We verify qualifications so you do not have to chase proof of coverage.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.gray,
            ),
          ),
          const SizedBox(height: 24),
          _buildCheckRow(
            Icons.verified,
            'Active State License Checks',
            'Every technician is verified for active trade-specific credentials prior to entry.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildCheckRow(
            Icons.shield,
            'General Liability Coverage Checks',
            'Pros are backed by verified \$1M general liability coverage to guarantee complete safety.',
            isDark,
          ),
          const SizedBox(height: 16),
          _buildCheckRow(
            Icons.price_check,
            'Upfront Pre-negotiated Rates',
            'No bidding wars, no quote markup. You pay the transparent rate card direct to the contractor.',
            isDark,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCheckRow(IconData icon, String title, String desc, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.orange500, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppTheme.navy700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : AppTheme.gray,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- SLIDE 4: REWARDS BAND ---
  Widget _buildRewardsSlide(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Homeowner Rewards Ledger',
            style: AppTheme.textTheme.headlineLarge?.copyWith(
              fontSize: 22,
              color: isDark ? Colors.white : AppTheme.navy700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Membership is free and earns you service credits on completed jobs marginally based on annual spend.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.gray,
            ),
          ),
          const SizedBox(height: 24),
          _buildBandTierCard('Band 1: 3% Back', 'On the first \$5,000 of annual spend.', '3%', isDark),
          const SizedBox(height: 12),
          _buildBandTierCard('Band 2: 5% Back', 'On annual spend from \$5,000 to \$15,000.', '5%', isDark),
          const SizedBox(height: 12),
          _buildBandTierCard('Band 3: 7% Back', 'On annual spend from \$15,000 to \$25,000.', '7%', isDark),
          const SizedBox(height: 12),
          Text(
            '* Expire 24 months after earning. Redeemable towards any service on the network.',
            style: TextStyle(
              fontSize: 10.5,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white54 : AppTheme.gray,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBandTierCard(String title, String desc, String percent, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 12,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppTheme.tealTint,
              shape: BoxShape.circle,
            ),
            child: Text(
              percent,
              style: const TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : AppTheme.navy700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white70 : AppTheme.gray,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- SLIDE 5: LOGIN / SIGNUP CAROUSEL ---
  Widget _buildStartSlide(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.tradeworksai.com/images/bot%7Bfavicon%7D.png',
            height: 80,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.smart_toy,
              color: AppTheme.orange500,
              size: 80,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TradeWorksAI',
            style: AppTheme.headingStyle.copyWith(
              color: isDark ? Colors.white : AppTheme.navy700,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'The On-demand network built exclusively for homeowners.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.gray, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 48),
          HoverButton(
            text: 'Log In',
            onPressed: () {
              Navigator.push(
                context,
                createPremiumRoute(const LoginPage()),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                createPremiumRoute(const SignupPage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: isDark ? Colors.white : AppTheme.navy700,
              shadowColor: Colors.transparent,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? Colors.white54 : AppTheme.navy700, width: 2),
              ),
            ),
            child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
