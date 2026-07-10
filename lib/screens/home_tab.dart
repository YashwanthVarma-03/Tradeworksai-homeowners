import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/auth_service.dart';
import '../services/homeowner_service.dart';

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

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  String _currentLocation = 'Set your address';
  bool _showMaintenancePrompt = false;
  final TextEditingController _homeSearchController = TextEditingController();
  final FocusNode _homeSearchFocus = FocusNode();
  bool _isSearchFocused = false;

  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _activeJobs = [];
  List<dynamic> _upcomingJobs = [];
  String? _userName;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeSearchFocus.addListener(() {
      if (mounted) {
        setState(() => _isSearchFocused = _homeSearchFocus.hasFocus);
      }
    });
    _fetchHomeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchHomeData(showLoading: false);
    }
  }

  Future<void> _fetchHomeData({bool showLoading = true}) async {
    if (!mounted) return;
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (showLoading || (_activeJobs.isEmpty && _upcomingJobs.isEmpty)) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      _errorMessage = null;
    }
    try {
      final woFuture = HomeownerService.instance.fetchWorkOrders();
      final profileFuture = HomeownerService.instance.fetchProfile();

      final results = await Future.wait([woFuture, profileFuture]);
      final woData = results[0];
      final profileData = results[1];

      if (mounted) {
        setState(() {
          // Parse work orders
          final tabs = woData['tabs'];
          if (tabs != null) {
            _activeJobs = tabs['active'] ?? [];
            _upcomingJobs = tabs['scheduled'] ?? [];
          }

          // Parse profile addresses to set currentLocation
          final addresses = profileData['addresses'] as List? ??
              profileData['profile']?['addresses'] as List?;
          if (addresses != null && addresses.isNotEmpty) {
            final defaultAddr = addresses.firstWhere(
              (a) => a['isDefault'] == true || a['isDefault'] == 'true',
              orElse: () => addresses.first,
            );
            if (defaultAddr != null) {
              _currentLocation =
                  '${defaultAddr['city']}, ${defaultAddr['state']} ${defaultAddr['zip']}';
            }
          }

          final profile = profileData['profile'];
          if (profile != null) {
            final gName = profile['givenName'] ?? '';
            final fName = profile['familyName'] ?? '';
            final un = profile['userName'] ?? '';
            if (un.isNotEmpty) {
              _userName = un;
            } else if (gName.isNotEmpty || fName.isNotEmpty) {
              _userName = '$gName $fName'.trim();
            }
          }

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

  String? _resolveContractorId(Map<String, dynamic> job) {
    final candidates = [
      job['contractorId'],
      job['contractor_id'],
      job['pro']?['contractorId'],
      job['pro']?['contractor_id'],
      job['pro']?['id'],
      job['pro']?['userId'],
      job['contractor']?['id'],
      job['contractor']?['contractorId'],
      job['contractor']?['contractor_id'],
    ];
    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return null;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  String _formatDateTimeString(String? isoString) {
    if (isoString == null) return 'TBD';
    try {
      final dt = DateTime.parse(isoString);
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      final wd = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      final day = dt.day;

      int hour = dt.hour;
      final ampm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;
      final min =
          dt.minute == 0 ? '' : ':${dt.minute.toString().padLeft(2, '0')}';

      return '$wd, $month $day · $hour$min $ampm';
    } catch (_) {
      return isoString;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeSearchController.dispose();
    _homeSearchFocus.dispose();
    super.dispose();
  }

  void _changeLocationDialog() {
    final controller = TextEditingController(text: _currentLocation);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Location',
            style: TextStyle(fontWeight: FontWeight.bold)),
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.navy700),
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
                hintText:
                    'e.g. My kitchen sink is leaking under the cabinet...',
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
                      icon: const Icon(Icons.photo_camera,
                          color: AppTheme.teal500),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Camera opened. Photo uploaded successfully.')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: AppTheme.teal500),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Listening... Voice intake captured.')),
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

  void _showQuoteApprovalDialog(Map<String, dynamic> job) {
    final proName = job['pro']?['businessName'] ?? 'Contractor';
    final service = job['serviceCategory'] ?? 'Service';
    final quoteAmount = job['quoteAmount'] ?? 0.0;
    final scope = job['quoteScope'] ?? 'Diagnostics & minor repairs';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Review Quote & Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: $service',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Provider: $proName'),
            const SizedBox(height: 12),
            Text('Rate Cap Quote: \$${quoteAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text(scope,
                style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              navigator.pop();
              try {
                await HomeownerService.instance.respondToQuote(
                  workOrderId: job['workOrderId'] is int
                      ? job['workOrderId']
                      : int.parse(job['workOrderId'].toString()),
                  accept: false,
                  reason: 'homeowner_declined',
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Quote declined successfully.'),
                      backgroundColor: AppTheme.error),
                );
                _fetchHomeData(showLoading: false);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.error),
                );
              }
            },
            child:
                const Text('Decline', style: TextStyle(color: AppTheme.error)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              navigator.pop();
              try {
                final startsAt = job['proposedStart'] ??
                    job['scheduledStart'] ??
                    DateTime.now()
                        .add(const Duration(days: 1))
                        .toIso8601String();
                final endsAt = job['proposedEnd'] ??
                    job['scheduledEnd'] ??
                    DateTime.now()
                        .add(const Duration(days: 1, hours: 2))
                        .toIso8601String();
                final contractorId = _resolveContractorId(job);

                await HomeownerService.instance.respondToQuote(
                  workOrderId: job['workOrderId'] is int
                      ? job['workOrderId']
                      : int.parse(job['workOrderId'].toString()),
                  accept: true,
                  startsAt: startsAt,
                  endsAt: endsAt,
                  contractorId: contractorId,
                );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(
                    content:
                        Text('Quote approved. Your work order is booked.'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                _fetchHomeData(showLoading: false);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.error),
                );
              }
            },
            child: const Text('Approve Quote Cap'),
          ),
        ],
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
                onPressed: _fetchHomeData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchHomeData,
      color: AppTheme.orange500,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(),

            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttentionStrip(),
                  if (_attentionWork != null) const SizedBox(height: 18),
                  _buildCategoryGrid(),
                  const SizedBox(height: 24),
                  _buildSuggestedMaintenanceSection(),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Map<String, dynamic>? get _attentionWork {
    for (final dynamic item in _activeJobs) {
      if (item is! Map) continue;
      final status = item['status']?.toString().toLowerCase() ?? '';
      if (status.contains('quote') ||
          status.contains('review') ||
          status.contains('payment') ||
          status.contains('approval') ||
          status.contains('action')) {
        return Map<String, dynamic>.from(item);
      }
    }
    return null;
  }

  int get _attentionCount => _activeJobs.where((dynamic item) {
        if (item is! Map) return false;
        final status = item['status']?.toString().toLowerCase() ?? '';
        return status.contains('quote') ||
            status.contains('review') ||
            status.contains('payment') ||
            status.contains('approval') ||
            status.contains('action');
      }).length;

  Widget _buildAttentionStrip() {
    final job = _attentionWork;
    if (job == null) return const SizedBox.shrink();
    final service = job['serviceCategory']?.toString() ?? 'Work order';
    final proName = job['pro']?['businessName']?.toString() ?? 'Your pro';
    final extra = _attentionCount > 1 ? ' - +${_attentionCount - 1} more' : '';

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _showQuoteApprovalDialog(job),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.orangeTint,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppTheme.orange500.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.orange500.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.orange500,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.priority_high,
                  color: AppTheme.navy700, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$service needs your review',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$proName$extra',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.navy700),
          ],
        ),
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
                    '${_getGreeting()}, ${_userName ?? AuthService.instance.userName ?? 'Homeowner'}',
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFDCEAF4), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _currentLocation,
                            style: const TextStyle(
                                color: Color(0xFFDCEAF4),
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down,
                              color: Color(0xFFDCEAF4), size: 12),
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
                hintStyle:
                    const TextStyle(color: Color(0xFF8A96A5), fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                      child: const Icon(Icons.arrow_forward,
                          color: Colors.white, size: 16),
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
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _aiIntakeDialog,
                child: const Row(
                  children: [
                    Icon(Icons.photo_camera,
                        color: Color(0xFFBFDCEC), size: 14),
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
      {
        'name': 'HVAC',
        'icon': Icons.ac_unit,
        'color': AppTheme.teal500,
        'bg': AppTheme.tealTint
      },
      {
        'name': 'Plumbing',
        'icon': Icons.plumbing,
        'color': AppTheme.navy700,
        'bg': AppTheme.navyTint
      },
      {
        'name': 'Electrical',
        'icon': Icons.flash_on,
        'color': AppTheme.orange500,
        'bg': AppTheme.orangeTint
      },
      {
        'name': 'Cleaning',
        'icon': Icons.cleaning_services,
        'color': AppTheme.navy700,
        'bg': AppTheme.navyTint
      },
      {
        'name': 'Roofing',
        'icon': Icons.roofing,
        'color': AppTheme.orange500,
        'bg': AppTheme.orangeTint
      },
      {
        'name': 'Landscaping',
        'icon': Icons.nature_people,
        'color': AppTheme.teal500,
        'bg': AppTheme.tealTint
      },
      {
        'name': 'Handyman',
        'icon': Icons.build,
        'color': AppTheme.orange500,
        'bg': AppTheme.orangeTint
      },
      {
        'name': 'Painting',
        'icon': Icons.format_paint,
        'color': AppTheme.teal500,
        'bg': AppTheme.tealTint
      },
      {
        'name': 'All 31',
        'icon': Icons.apps,
        'color': Colors.white,
        'bg': AppTheme.orange500
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Browse by category',
              style: AppTheme.headingStyle
                  .copyWith(fontSize: 15, color: AppTheme.navy700),
            ),
            GestureDetector(
              onTap: widget.onBookTap,
              child: const Text(
                'See all 31 ›',
                style: TextStyle(
                    color: AppTheme.teal500,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5),
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
                    border: isAll
                        ? null
                        : Border.all(
                            color: const Color(0xFF1B3C6E).withOpacity(0.08)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isAll
                              ? Colors.white.withOpacity(0.22)
                              : Colors.white,
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
    if (_activeJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Bookings & Requests',
          style: AppTheme.headingStyle
              .copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        ..._activeJobs.map((job) {
          final status = job['status']?.toString().toLowerCase() ?? '';
          final isQuoteReady =
              status.contains('quote') || status.contains('review');

          if (isQuoteReady) {
            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.orangeTint,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppTheme.orange500.withOpacity(0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description,
                                color: AppTheme.orange500, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Quote ready — review now',
                              style: TextStyle(
                                  color: AppTheme.orange700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.push_pin,
                          color: AppTheme.orange500, size: 16),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    job['serviceCategory'] ?? 'Service Request',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    job['pro']?['businessName'] ?? 'Assigning Contractor...',
                    style:
                        const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _showQuoteApprovalDialog(job),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(120, 38),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Review quote',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            );
          } else {
            final proName = job['pro']?['businessName'] ?? 'Assigning Pro...';
            final service = job['serviceCategory'] ?? 'Service Request';
            final scheduledStartStr = job['scheduledStart'] != null
                ? _formatDateTimeString(job['scheduledStart'])
                : 'TBD';

            final timeline = job['timeline'] ?? {};
            final accepted = timeline['acceptedAt'] != null;
            final enRoute = timeline['enRouteAt'] != null;
            final arrived = timeline['arrivedAt'] != null;
            final inProgress = timeline['inProgressAt'] != null;
            final wrappingUp = timeline['contractorCompletedAt'] != null;
            final completed = timeline['completedAt'] != null;

            int activeStep = -1;
            if (completed) {
              activeStep = 5;
            } else if (wrappingUp) {
              activeStep = 4;
            } else if (inProgress) {
              activeStep = 3;
            } else if (arrived) {
              activeStep = 2;
            } else if (enRoute) {
              activeStep = 1;
            } else if (accepted) {
              activeStep = 0;
            }

            return GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        service,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.tealTint,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.airport_shuttle,
                                color: AppTheme.teal500, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              job['status'] ?? 'Active',
                              style: const TextStyle(
                                  color: AppTheme.teal700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$proName · $scheduledStartStr',
                    style:
                        const TextStyle(color: AppTheme.gray, fontSize: 12.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildProgressNode(accepted || activeStep > 0,
                          active: activeStep == 0),
                      _buildProgressLine(enRoute || activeStep > 1),
                      _buildProgressNode(enRoute || activeStep > 1,
                          active: activeStep == 1),
                      _buildProgressLine(arrived || activeStep > 2),
                      _buildProgressNode(arrived || activeStep > 2,
                          active: activeStep == 2),
                      _buildProgressLine(inProgress || activeStep > 3),
                      _buildProgressNode(inProgress || activeStep > 3,
                          active: activeStep == 3),
                      _buildProgressLine(wrappingUp || activeStep > 4),
                      _buildProgressNode(wrappingUp || activeStep > 4,
                          active: activeStep == 4),
                      _buildProgressLine(completed || activeStep > 5),
                      _buildProgressNode(completed || activeStep > 5,
                          active: activeStep == 5),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: AppTheme.success, shape: BoxShape.circle),
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
            );
          }
        }),
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
    if (_upcomingJobs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming Appointments',
          style: AppTheme.headingStyle
              .copyWith(fontSize: 15, color: AppTheme.navy700),
        ),
        const SizedBox(height: 12),
        ..._upcomingJobs.map((job) {
          final proName = job['pro']?['businessName'] ?? 'Vetted Pro';
          final service = job['serviceCategory'] ?? 'Service';
          final scheduledStartStr = job['scheduledStart'] != null
              ? _formatDateTimeString(job['scheduledStart'])
              : 'TBD';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$proName · $scheduledStartStr',
                          style: const TextStyle(
                              color: AppTheme.gray, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.tealTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppTheme.teal700, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          job['status'] ?? 'Booked',
                          style: const TextStyle(
                              color: AppTheme.teal700,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSuggestedMaintenanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'For your home',
          style: AppTheme.headingStyle
              .copyWith(fontSize: 15, color: AppTheme.navy700),
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
                    style: TextStyle(
                        color: AppTheme.teal500,
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        letterSpacing: 0.06),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Your AC is about 12 years old. Book a pre-summer tune-up to avoid a mid-July breakdown.',
                    style: TextStyle(
                        color: AppTheme.ink, fontSize: 13.5, height: 1.5),
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Book a tune-up',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
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
                  child:
                      const Icon(Icons.close, color: AppTheme.gray, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
