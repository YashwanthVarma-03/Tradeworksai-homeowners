import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class HomeTab extends StatefulWidget {
  final VoidCallback onBookTap;
  final Function(Map<String, String>) onJobTap;
  final VoidCallback onInboxTap;
  final Function(String) onSearchQuery;
  final Function(String) onCategorySelected;

  const HomeTab({
    super.key,
    required this.onBookTap,
    required this.onJobTap,
    required this.onInboxTap,
    required this.onSearchQuery,
    required this.onCategorySelected,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _currentLocation = 'Riverview, FL 33578';
  bool _showMaintenancePrompt = true;
  final TextEditingController _homeSearchController = TextEditingController();

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  void _changeLocationDialog() {
    final controller = TextEditingController(text: _currentLocation);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'City, State or ZIP Code',
            prefixIcon: Icon(Icons.location_on, color: AppTheme.gray),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _currentLocation = controller.text.trim();
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _aiIntakeDialog() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.smart_toy, color: AppTheme.teal500, size: 28),
                SizedBox(width: 12),
                Text(
                  'TradeWorks AI Intake',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.navy700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Describe what you need done in your home. You can also upload a photo or speak.',
              style: TextStyle(color: AppTheme.gray, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. My kitchen sink is leaking under the cabinet...',
                hintStyle: const TextStyle(color: AppTheme.gray, fontSize: 13),
                filled: true,
                fillColor: AppTheme.pageAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_camera, color: AppTheme.teal500),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Camera opened. Photo uploaded successfully.')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: AppTheme.teal500),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Listening... Voice intake captured.')),
                        );
                      },
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
                    final query = controller.text.trim();
                    Navigator.pop(context);
                    if (query.isNotEmpty) {
                      widget.onSearchQuery(query);
                    } else {
                      widget.onBookTap();
                    }
                  },
                  child: const Text('Find Vetted Pro'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showQuoteApprovalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Quote & Details', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: Water heater repair', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Provider: Bay Plumbing Co.'),
            SizedBox(height: 12),
            Text('Rate Cap Quote: \$180.00'),
            Text('Diagnostics & minor leaks resolved up to the cap limit.', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quote approved! Job scheduled for dispatch.'),
                  backgroundColor: AppTheme.success,
                ),
              );
            },
            child: const Text('Approve Quote Cap'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Search-First Hero
          _buildHero(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Browse by Category Grid
                _buildCategoryGrid(),
                const SizedBox(height: 24),

                // 3. Active & Action-Required Section
                _buildActiveJobsSection(),
                const SizedBox(height: 24),

                // 4. Upcoming Section
                _buildUpcomingSection(),
                const SizedBox(height: 24),

                // 5. Service Credits Section
                _buildServiceCreditsSection(),
                const SizedBox(height: 24),

                // 6. For Your Home (Suggested Maintenance)
                if (_showMaintenancePrompt) _buildSuggestedMaintenanceSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B3C6E),
            Color(0xFF235C86),
            Color(0xFF2E86AB),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, Yashwanth',
                    style: AppTheme.headingStyle.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _changeLocationDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFDCEAF4), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _currentLocation,
                            style: const TextStyle(color: Color(0xFFDCEAF4), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, color: Color(0xFFDCEAF4), size: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'What do you need done?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B1A2B).withOpacity(0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: _homeSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                final query = value.trim();
                if (query.isNotEmpty) {
                  widget.onSearchQuery(query);
                }
              },
              decoration: InputDecoration(
                hintText: 'Search a service or pro',
                hintStyle: const TextStyle(color: Color(0xFF8A96A5), fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      final query = _homeSearchController.text.trim();
                      if (query.isNotEmpty) {
                        widget.onSearchQuery(query);
                      }
                    },
                    icon: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.orange500,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'or ',
                style: TextStyle(color: Color(0xFFE3EFF7), fontSize: 13),
              ),
              GestureDetector(
                onTap: _aiIntakeDialog,
                child: const Text(
                  'describe it',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _aiIntakeDialog,
                child: const Row(
                  children: [
                    Icon(Icons.photo_camera, color: Color(0xFFBFDCEC), size: 14),
                    SizedBox(width: 6),
                    Icon(Icons.mic, color: Color(0xFFBFDCEC), size: 14),
                    SizedBox(width: 6),
                    Icon(Icons.keyboard, color: Color(0xFFBFDCEC), size: 14),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '— photo or voice',
                style: TextStyle(color: Color(0xFFE3EFF7), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPopularChip('AC repair'),
                _buildPopularChip('Drain cleaning'),
                _buildPopularChip('House cleaning'),
                _buildPopularChip('Handyman'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopularChip(String label) {
    return GestureDetector(
      onTap: () {
        widget.onSearchQuery(label);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final List<Map<String, dynamic>> cats = [
      {'name': 'HVAC', 'icon': Icons.ac_unit, 'color': AppTheme.teal500, 'bg': AppTheme.tealTint},
      {'name': 'Plumbing', 'icon': Icons.plumbing, 'color': AppTheme.navy700, 'bg': AppTheme.navyTint},
      {'name': 'Electrical', 'icon': Icons.flash_on, 'color': AppTheme.orange500, 'bg': AppTheme.orangeTint},
      {'name': 'Cleaning', 'icon': Icons.cleaning_services, 'color': AppTheme.navy700, 'bg': AppTheme.navyTint},
      {'name': 'Roofing', 'icon': Icons.roofing, 'color': AppTheme.orange500, 'bg': AppTheme.orangeTint},
      {'name': 'Landscaping', 'icon': Icons.nature_people, 'color': AppTheme.teal500, 'bg': AppTheme.tealTint},
      {'name': 'Handyman', 'icon': Icons.build, 'color': AppTheme.orange500, 'bg': AppTheme.orangeTint},
      {'name': 'Painting', 'icon': Icons.format_paint, 'color': AppTheme.teal500, 'bg': AppTheme.tealTint},
      {'name': 'All 31', 'icon': Icons.apps, 'color': Colors.white, 'bg': AppTheme.orange500},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Browse by category',
              style: AppTheme.headingStyle.copyWith(fontSize: 15, color: AppTheme.navy700),
            ),
            GestureDetector(
              onTap: widget.onBookTap,
              child: const Text(
                'See all 31 ›',
                style: TextStyle(color: AppTheme.teal500, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final cat = cats[index];
              final isAll = cat['name'] == 'All 31';
              return GestureDetector(
                onTap: () {
                  if (isAll) {
                    widget.onBookTap();
                  } else {
                    widget.onCategorySelected(cat['name']);
                  }
                },
                child: Container(
                  width: 95,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: cat['bg'],
                    borderRadius: BorderRadius.circular(13),
                    border: isAll ? null : Border.all(color: const Color(0xFF1B3C6E).withOpacity(0.08)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isAll ? Colors.white.withOpacity(0.22) : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(cat['icon'], color: cat['color'], size: 20),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        cat['name'],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAll ? Colors.white : AppTheme.ink,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActiveJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Bookings & Requests',
          style: AppTheme.headingStyle.copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),

        // Action required: Pinned Quote Ready card
        GlassCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.orangeTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.orange500.withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.description, color: AppTheme.orange500, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Quote ready — review now',
                          style: TextStyle(color: AppTheme.orange700, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.push_pin, color: AppTheme.orange500, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Water heater repair',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 2),
              const Text(
                'Bay Plumbing Co.',
                style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _showQuoteApprovalDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.orange500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 38),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Review quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ),

        // Tracking card
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AC Tune-Up',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.tealTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.airport_shuttle, color: AppTheme.teal500, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'En route',
                          style: TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                'Cool Air Pros · Today, 2–4 PM',
                style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              // Timeline progress bar
              Row(
                children: [
                  _buildProgressNode(true),
                  _buildProgressLine(true),
                  _buildProgressNode(true, active: true),
                  _buildProgressLine(false),
                  _buildProgressNode(false),
                  _buildProgressLine(false),
                  _buildProgressNode(false),
                  _buildProgressLine(false),
                  _buildProgressNode(false),
                  _buildProgressLine(false),
                  _buildProgressNode(false),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Live · updated just now',
                    style: TextStyle(color: AppTheme.gray, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressNode(bool done, {bool active = false}) {
    return Container(
      width: active ? 12 : 9,
      height: active ? 12 : 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? Colors.white
            : done
                ? AppTheme.teal500
                : AppTheme.line,
        border: active ? Border.all(color: AppTheme.teal500, width: 3) : null,
      ),
    );
  }

  Widget _buildProgressLine(bool done) {
    return Expanded(
      child: Container(
        height: 2,
        color: done ? AppTheme.teal500 : AppTheme.line,
      ),
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Appointments',
          style: AppTheme.headingStyle.copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppTheme.line, width: 0.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gutter cleaning',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Peak Exteriors · Sat, Jun 28 · 9–11 AM',
                        style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, color: AppTheme.teal700, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Booked',
                        style: TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCreditsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Credits Ledger',
          style: AppTheme.headingStyle.copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.navyTint, AppTheme.tealTint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD5E2EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$420 available',
                style: AppTheme.headingStyle.copyWith(fontSize: 22, color: AppTheme.navy700, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Earned this year: \$400',
                style: TextStyle(color: AppTheme.gray, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('3%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gray)),
                  Text('5%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.teal500)),
                  Text('7%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.gray)),
                ],
              ),
              const SizedBox(height: 4),
              // Custom progress bar with slider marks
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFD5E2EE)),
                    ),
                  ),
                  // Progress Fill (50%)
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Container(
                      height: 9,
                      decoration: const BoxDecoration(
                        color: AppTheme.teal500,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  // Tick at 20%
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.20,
                    child: Container(width: 1.5, height: 13, color: const Color(0xFFB9C8D8)),
                  ),
                  // Tick at 60%
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.60,
                    child: Container(width: 1.5, height: 13, color: const Color(0xFFB9C8D8)),
                  ),
                  // Orange thumb mark at 50%
                  Align(
                    alignment: const Alignment(-0.0, 0),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.orange500, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('\$0', style: TextStyle(fontSize: 10.5, color: AppTheme.gray)),
                  Text('\$5k', style: TextStyle(fontSize: 10.5, color: AppTheme.gray)),
                  Text('\$15k', style: TextStyle(fontSize: 10.5, color: AppTheme.gray)),
                  Text('\$25k', style: TextStyle(fontSize: 10.5, color: AppTheme.gray)),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFFD5E2EE)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'You\'re in the 5% band · \$5,000 to 7% back',
                      style: TextStyle(color: AppTheme.navy700, fontWeight: FontWeight.bold, fontSize: 11.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onBookTap, // Redirect to checkout/rewards via tabs in dashboard
                    child: const Text(
                      'View ›',
                      style: TextStyle(color: AppTheme.teal500, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestedMaintenanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For your home',
          style: AppTheme.headingStyle.copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.tealTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFCFE6EF)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SUGGESTED FOR YOU',
                    style: TextStyle(color: AppTheme.teal500, fontWeight: FontWeight.bold, fontSize: 10.5, letterSpacing: 0.06),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Your AC is about 12 years old. Book a pre-summer tune-up to avoid a mid-July breakdown.',
                    style: TextStyle(color: AppTheme.ink, fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      widget.onCategorySelected('HVAC');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Book a tune-up', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMaintenancePrompt = false;
                    });
                  },
                  child: const Icon(Icons.close, color: AppTheme.gray, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
