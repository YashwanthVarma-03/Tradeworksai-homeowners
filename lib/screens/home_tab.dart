import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../utils/app_error_utils.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../widgets/offline_state.dart';

enum _AiAssistMode { camera, voice }

class HomeTab extends StatefulWidget {
  final VoidCallback onBookTap;
  final Function(Map<String, String>) onJobTap;
  final VoidCallback onInboxTap;
  final Function(String) onSearchQuery;
  final Function(String) onCategorySelected;
  final VoidCallback onGuidesTap;

  const HomeTab({
    super.key,
    required this.onBookTap,
    required this.onJobTap,
    required this.onInboxTap,
    required this.onSearchQuery,
    required this.onCategorySelected,
    required this.onGuidesTap,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  String _currentLocation = 'Set your address';
  String? _userName;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  List<dynamic> _activeJobs = [];
  List<dynamic> _upcomingJobs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchHomeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchHomeData(showLoading: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchHomeData({bool showLoading = true}) async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    if (showLoading || (_activeJobs.isEmpty && _upcomingJobs.isEmpty)) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        HomeownerService.instance.fetchWorkOrders(),
        HomeownerService.instance.fetchProfile(),
      ]);

      final woData = results[0] as Map<String, dynamic>;
      final profileData = results[1] as Map<String, dynamic>;

      final tabs = woData['tabs'];
      final profile = profileData['profile'];
      final addresses = (profileData['addresses'] as List?) ??
          (profile is Map ? profile['addresses'] as List? : null);

      if (!mounted) return;
      setState(() {
        if (tabs is Map) {
          _activeJobs = tabs['active'] ?? [];
          _upcomingJobs = tabs['scheduled'] ?? [];
        }

        if (addresses != null && addresses.isNotEmpty) {
          final defaultAddr = addresses.firstWhere(
            (a) => a is Map && (a['isDefault'] == true || a['isDefault'] == 'true'),
            orElse: () => addresses.first,
          );
          if (defaultAddr is Map) {
            final city = defaultAddr['city']?.toString() ?? '';
            final state = defaultAddr['state']?.toString() ?? '';
            final zip = defaultAddr['zip']?.toString() ?? '';
            final location = [city, state, zip].where((p) => p.isNotEmpty).join(' ');
            _currentLocation = location.isEmpty ? _currentLocation : location;
          }
        }

        if (profile is Map) {
          final given = profile['givenName']?.toString().trim() ?? '';
          final family = profile['familyName']?.toString().trim() ?? '';
          final userName = profile['userName']?.toString().trim() ?? '';
          _userName = userName.isNotEmpty
              ? userName
              : [given, family].where((v) => v.isNotEmpty).join(' ');
        }

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppErrorUtils.friendlyMessage(e);
        _isLoading = false;
      });
    } finally {
      _isRefreshing = false;
    }
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _text(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
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
                setState(() => _currentLocation = controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    widget.onSearchQuery(query);
  }

  Future<void> _openCameraIntake() async {
    await _showAiAssistSheet(initialMode: _AiAssistMode.camera);
  }

  Future<void> _openVoiceIntake() async {
    await _showAiAssistSheet(initialMode: _AiAssistMode.voice);
  }

  Future<void> _showAiAssistSheet({required _AiAssistMode initialMode}) async {
    final noteController = TextEditingController(text: _searchController.text);
    final noteFocusNode = FocusNode();
    XFile? selectedPhoto;
    String? errorMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> capturePhoto() async {
              try {
                final photo = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 85,
                );
                if (photo == null) return;
                setModalState(() {
                  selectedPhoto = photo;
                  errorMessage = null;
                });
              } catch (_) {
                setModalState(() {
                  errorMessage =
                      'Unable to open the camera. Check camera permission and try again.';
                });
              }
            }

            void submit() {
              final query = noteController.text.trim();
              if (query.isEmpty) {
                setModalState(() {
                  errorMessage = 'Add a short description before continuing.';
                });
                return;
              }

              setState(() {
                _searchController.text = query;
              });
              Navigator.of(sheetContext).pop();
              widget.onSearchQuery(query);
            }

            final isCameraMode = initialMode == _AiAssistMode.camera;
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, bottomInset + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AppTheme.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isCameraMode ? 'Camera intake' : 'Voice intake',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCameraMode
                          ? 'Take a photo, add a short note, and continue to matching pros.'
                          : 'Describe the issue in a few words and continue to matching pros.',
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.gray,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: noteController,
                      focusNode: noteFocusNode,
                      autofocus: initialMode == _AiAssistMode.voice,
                      minLines: 4,
                      maxLines: 5,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: isCameraMode
                            ? 'What is going on at home?'
                            : 'Describe what you need help with.',
                        filled: true,
                        fillColor: const Color(0xFFF7FAFD),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(color: AppTheme.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              const BorderSide(color: AppTheme.teal700, width: 1.2),
                        ),
                        contentPadding: const EdgeInsets.all(18),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: capturePhoto,
                            icon: const Icon(Icons.photo_camera_outlined),
                            label: Text(
                              selectedPhoto == null ? 'Add photo' : 'Retake photo',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navy700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: const BorderSide(color: AppTheme.line),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              FocusScope.of(context).requestFocus(noteFocusNode);
                            },
                            icon: const Icon(Icons.mic_none),
                            label: const Text('Use voice'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navy700,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: const BorderSide(color: AppTheme.line),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (selectedPhoto != null) ...[
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(
                          File(selectedPhoto!.path),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    if (errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFD),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            color: AppTheme.navy700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orange500,
                          foregroundColor: AppTheme.navy700,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Find pros',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
    noteFocusNode.dispose();
  }

  void _showQuoteApprovalDialog(Map<String, dynamic> job) {
    final service = job['serviceCategory']?.toString() ?? 'Work order';
    final proName = job['pro']?['businessName']?.toString() ?? 'Your pro';
    final quoteAmount = job['quoteAmount'] ?? 0.0;
    final scope = job['quoteScope']?.toString() ?? 'Diagnostics & minor repairs';

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
            Text('Rate Cap Quote: \$${quoteAmount.toString()}'),
            const SizedBox(height: 8),
            Text(scope, style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SunriseBackground(
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(color: AppTheme.orange500),
                SizedBox(height: 12),
                Text(
                  'Loading your home',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SunriseBackground(
        child: SafeArea(
          child: OfflineState(
            onRetry: _fetchHomeData,
            message: _errorMessage,
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3C6E), Color(0xFF235C86), Color(0xFF2E86AB)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _changeLocationDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on,
                      color: Color(0xFFE6F2F7), size: 13),
                  const SizedBox(width: 5),
                  Text(
                    _currentLocation,
                    style: const TextStyle(
                      color: Color(0xFFE6F2F7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down,
                      color: Color(0xFFE6F2F7), size: 13),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'What do you need done?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
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
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: _openSearch,
              decoration: InputDecoration(
                hintText: 'Search a service or pro',
                hintStyle:
                    const TextStyle(color: Color(0xFF8A96A5), fontSize: 15),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                suffixIcon: SizedBox(
                  width: 136,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Describe with a photo',
                        onPressed: _openCameraIntake,
                        icon: const Icon(Icons.photo_camera_outlined,
                            color: AppTheme.teal700, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Describe with voice',
                        onPressed: _openVoiceIntake,
                        icon: const Icon(Icons.mic_none,
                            color: AppTheme.teal700, size: 20),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => _openSearch(_searchController.text),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppTheme.orange500,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.arrow_forward,
                                color: AppTheme.navy700, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_searchFocusNode.hasFocus) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPopularChip('Drain cleaning', recent: true),
                _buildPopularChip('AC tune-up', recent: true),
                _buildPopularChip('AC repair'),
                _buildPopularChip('Drain cleaning'),
                _buildPopularChip('House cleaning'),
                _buildPopularChip('Handyman'),
                _buildPopularChip('Water heater'),
                _buildPopularChip('Roof leak'),
                _buildPopularChip('Lawn cleanup'),
                _buildPopularChip('Appliance repair'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPopularChip(String label, {bool recent = false}) {
    return GestureDetector(
      onTap: () => _openSearch(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: recent ? const Color(0xFFDDF0F6) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Text(
          recent ? 'Recent: $label' : label,
          style: TextStyle(
            color: recent ? AppTheme.teal700 : Colors.white,
            fontSize: 12,
            fontWeight: recent ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final categories = const [
      'HVAC',
      'Plumbing',
      'Electrical',
      'Cleaning',
      'Roofing',
      'Lawn',
      'Handyman',
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
                  .copyWith(fontSize: 16, color: AppTheme.navy700),
            ),
            GestureDetector(
              onTap: () => widget.onCategorySelected('All'),
              child: const Text(
                'See all 31 >',
                style: TextStyle(
                  color: AppTheme.teal700,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 380 ? 3 : 4;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: categories.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: crossAxisCount == 4 ? 0.92 : 0.95,
              ),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return InkWell(
                    onTap: () => widget.onCategorySelected('All'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.orange500,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apps, color: Colors.white, size: 20),
                          SizedBox(height: 7),
                          Text(
                            'All 31',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return TradeWorksCategoryTile(
                  label: categories[index],
                  onTap: () => widget.onCategorySelected(categories[index]),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildSuggestedHomeCard() {
    final hasColdStart =
        _currentLocation == 'Set your address' && _activeJobs.isEmpty && _upcomingJobs.isEmpty;

    if (hasColdStart) {
      return GlassCard(
        borderRadius: 15,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GET TAILORED SUGGESTIONS',
              style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 10.5,
                letterSpacing: 0.06,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell us about your home',
              style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Add your systems and their install dates, and we'll flag maintenance before it becomes a breakdown.",
              style: TextStyle(color: AppTheme.gray, fontSize: 12.3, height: 1.45),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _changeLocationDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navy700,
                side: const BorderSide(color: AppTheme.navy700),
                minimumSize: const Size(140, 38),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Add your home details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return GlassCard(
      borderRadius: 15,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUGGESTED FOR YOU',
            style: TextStyle(
              color: AppTheme.teal500,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              letterSpacing: 0.06,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your AC is about 12 years old. Book a pre-summer tune-up to avoid a mid-July breakdown.',
            style: TextStyle(
              color: AppTheme.ink,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Based on the install date on your AC',
            style: TextStyle(color: AppTheme.gray, fontSize: 12.2, height: 1.45),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => widget.onCategorySelected('HVAC'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.orange500,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Book a tune-up',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _changeLocationDialog,
            child: const Text(
              'Not right? Update',
              style: TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionStrip() {
    final job = _attentionWork;
    if (job == null) return const SizedBox.shrink();

    final service = job['serviceCategory']?.toString() ?? 'Work order';
    final proName = job['pro']?['businessName']?.toString() ?? 'Your pro';
    final extra = _attentionCount > 1 ? ' +${_attentionCount - 1} more' : '';

    return InkWell(
      onTap: () => _showQuoteApprovalDialog(job),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
              width: 32,
              height: 32,
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
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoading();
    }
    if (_errorMessage != null) {
      return _buildError();
    }

    return RefreshIndicator(
      onRefresh: _fetchHomeData,
      color: AppTheme.orange500,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAttentionStrip(),
                    if (_attentionWork != null) const SizedBox(height: 14),
                    _buildCategoryGrid(),
                    const SizedBox(height: 18),
                    _buildSuggestedHomeCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
