import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import 'account/manage_addresses.dart';
import 'booking_success_screen.dart';
import 'login_page.dart';

enum _BookingPage {
  service,
  details,
  pricing,
  urgency,
  schedule,
  location,
  review,
}

class BookFlowScreen extends StatefulWidget {
  final Map<String, dynamic> pro;

  const BookFlowScreen({super.key, required this.pro});

  @override
  State<BookFlowScreen> createState() => _BookFlowScreenState();
}

class _BookFlowScreenState extends State<BookFlowScreen> {
  late final PageController _pageController;
  final _issueController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _onsiteNotesController = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _selectedDetailChips = <String>{};

  final List<XFile> _selectedPhotos = [];
  final List<dynamic> _addresses = [];

  Map<String, dynamic>? _contractorProfile;
  Map<String, dynamic>? _selectedAddressObj;
  String? _contractorId;

  bool _isLoadingAddresses = true;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  String? _slotsError;

  int _pageIndex = 0;
  int _selectedServiceIndex = 0;
  int _selectedPricingIndex = 0;
  int _selectedUrgencyIndex = 0;
  final bool _asap = false;
  String? _selectedDate;
  String? _selectedTime;

  List<String> _dates = [];
  Map<String, List<Map<String, dynamic>>> _slotsByDate = {};

  String? get _selectedPropertyZip =>
      _string(_selectedAddressObj?['zip']) ??
      _string(widget.pro['zip']) ??
      _string(widget.pro['address_zip']);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _issueController.text = _fallbackDescription;
    _loadProfileAndAvailability();
    _loadAddresses();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _issueController.dispose();
    _accessNotesController.dispose();
    _onsiteNotesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _mergedPro {
    return {
      ...widget.pro,
      if (_contractorProfile != null) ..._contractorProfile!,
    };
  }

  String get _proName =>
      _string(_mergedPro['businessName']) ??
      _string(_mergedPro['business_name']) ??
      _string(_mergedPro['name']) ??
      'Book Pro';

  String get _proTrade =>
      _string(_mergedPro['trade']) ??
      _string(_mergedPro['category']) ??
      'Home Service';

  String get _fallbackDescription {
    final summary = _string(widget.pro['summary']);
    if (summary != null && summary.isNotEmpty) return summary;
    return 'Diagnostic and repair request.';
  }

  List<_ServiceOption> get _serviceOptions {
    final rawServices = _readList(
      _contractorProfile?['services'] ??
          _contractorProfile?['service_options'] ??
          widget.pro['services'] ??
          widget.pro['service_options'],
    ) ?? const [];

    final parsed = <_ServiceOption>[];
    for (final item in rawServices) {
      if (item is Map) {
        parsed.add(_ServiceOption.fromMap(Map<String, dynamic>.from(item)));
      } else if (item != null) {
        parsed.add(_ServiceOption.fromString(item.toString(), trade: _proTrade));
      }
    }

    if (parsed.isNotEmpty) return parsed;
    return _fallbackServiceOptions();
  }

  _ServiceOption get _selectedService => _serviceOptions[
      _selectedServiceIndex.clamp(0, _serviceOptions.length - 1)];

  List<_PricingChoice> get _pricingChoices => _selectedService.pricingChoices;

  List<_UrgencyOption> get _urgencyOptions {
    final raw = _readList(
      _contractorProfile?['urgency_tiers'] ??
          _contractorProfile?['response_times'] ??
          _contractorProfile?['service_levels'],
    ) ?? const [];
    final parsed = <_UrgencyOption>[];
    for (final item in raw) {
      if (item is Map) {
        parsed.add(_UrgencyOption.fromMap(Map<String, dynamic>.from(item)));
      }
    }
    if (parsed.isNotEmpty) return parsed;
    return [
      const _UrgencyOption(
        label: 'Standard',
        detail: 'Responds within 48 hours',
        feeLabel: 'Included',
        urgencySlug: 'standard',
        available: true,
      ),
      const _UrgencyOption(
        label: 'Urgent',
        detail: 'Responds within 8 hours',
        feeLabel: '+\$35',
        urgencySlug: 'urgent',
        available: true,
      ),
      const _UrgencyOption(
        label: 'Emergency',
        detail: 'Responds within 2 hours',
        feeLabel: '+\$90',
        urgencySlug: 'emergency',
        available: true,
      ),
    ];
  }

  List<_BookingPage> get _pages {
    return <_BookingPage>[
      _BookingPage.service,
      _BookingPage.details,
      if (_pricingChoices.length > 1) _BookingPage.pricing,
      _BookingPage.urgency,
      _BookingPage.schedule,
      _BookingPage.location,
      _BookingPage.review,
    ];
  }

  _BookingPage get _currentPage => _pages[_pageIndex];

  bool get _isLastPage => _pageIndex == _pages.length - 1;

  int get _currentStepNumber => _pageIndex + 1;

  int get _totalSteps => _pages.length;

  Future<void> _loadProfileAndAvailability() async {
    try {
      final slug = _profileSlug();
      if (slug != null && slug.isNotEmpty) {
        final data = await HomeownerService.instance.getContractorProfile(slug);
        if (mounted) {
          final profile = data['profile'] as Map<String, dynamic>? ?? data;
          final resolvedId = _extractContractorId(profile) ??
              _string(widget.pro['contractorId']) ??
              _string(widget.pro['contractor_id']) ??
              await _resolveContractorIdForBooking(slug);
          setState(() {
            _contractorProfile = profile;
            _contractorId = resolvedId;
            _issueController.text = _fallbackDescription;
          });
        }
      } else {
        if (mounted) setState(() {});
      }
      await _refreshAvailability();
    } catch (_) {
      if (mounted) {
        final fallbackSlug = _profileSlug();
        final resolvedId = fallbackSlug == null
            ? null
            : await _resolveContractorIdForBooking(fallbackSlug);
        setState(() {
          _contractorId = _string(widget.pro['contractorId']) ??
              _string(widget.pro['contractor_id']) ??
              resolvedId;
        });
      }
      await _refreshAvailability();
    }
  }

  Future<String?> _resolveContractorIdForBooking(String slug) async {
    final normalizedSlug = slug.trim().toLowerCase();
    if (normalizedSlug.isEmpty) return null;

    final zip = _string(_selectedAddressObj?['zip']) ??
        _string(widget.pro['zip']) ??
        _string(widget.pro['address_zip']) ??
        '33578';
    final categorySlug = _categorySlugForSearch(
      _string(widget.pro['category']) ?? _proTrade,
    );
    if (categorySlug == null) return null;

    try {
      final searchResult = await HomeownerService.instance.searchPros(
        zip: zip,
        categorySlug: categorySlug,
      );
      final results = searchResult['results'] as List? ?? const [];
      for (final result in results) {
        if (result is! Map) continue;
        final map = Map<String, dynamic>.from(result);
        final resultSlug = _string(map['slug'])?.toLowerCase();
        final businessSlug = _string(map['businessName'])
            ?.toLowerCase()
            .replaceAll(' ', '-');
        if (resultSlug == normalizedSlug || businessSlug == normalizedSlug) {
          return _string(map['contractorId']) ??
              _string(map['contractor_id']) ??
              _string(map['id']);
        }
      }
    } catch (_) {}

    return null;
  }

  String? _categorySlugForSearch(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('hvac') ||
        lower.contains('air') ||
        lower.contains('cool') ||
        lower.contains('heat')) {
      return 'hvac';
    }
    if (lower.contains('plumb') ||
        lower.contains('drain') ||
        lower.contains('water')) {
      return 'plumbing';
    }
    if (lower.contains('electr') ||
        lower.contains('outlet') ||
        lower.contains('fan') ||
        lower.contains('panel')) {
      return 'electrical';
    }
    if (lower.contains('handyman')) {
      return 'handyman';
    }
    if (lower.contains('roof')) {
      return 'roofing';
    }
    if (lower.contains('lawn') || lower.contains('landscap')) {
      return 'landscaping';
    }
    if (lower.contains('appliance')) {
      return 'appliance-repair';
    }
    if (lower.contains('water treatment')) {
      return 'water-treatment';
    }
    if (lower.contains('window') || lower.contains('door')) {
      return 'windows-doors';
    }
    if (lower.contains('lock')) {
      return 'locksmith';
    }
    return null;
  }

  Future<void> _loadAddresses() async {
    if (!mounted) return;
    setState(() => _isLoadingAddresses = true);
    try {
      final profileResp = await HomeownerService.instance.fetchProfile();
      final List<dynamic> addressList = _readList(profileResp['addresses']) ??
          _readList(profileResp['profile']?['addresses']) ??
          [];
      if (mounted) {
        final shouldRefreshAvailability =
            _contractorId != null && _contractorId!.isNotEmpty;
        setState(() {
          _addresses
            ..clear()
            ..addAll(addressList);
          _isLoadingAddresses = false;
          if (_addresses.isNotEmpty) {
            _selectedAddressObj = _addresses.firstWhere(
              (a) => a['isDefault'] == true || a['isDefault'] == 'true',
              orElse: () => _addresses.first,
            );
          }
        });
        if (shouldRefreshAvailability) {
          await _refreshAvailability();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _refreshAvailability() async {
    final contractorId = _contractorId;
    if (contractorId == null || contractorId.isEmpty) {
      if (mounted) {
        setState(() {
          _slotsError = 'This contractor is missing booking details right now.';
        });
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
    });

    try {
      final now = DateTime.now();
      final fromDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final future = now.add(const Duration(days: 7));
      final toDate =
          '${future.year}-${future.month.toString().padLeft(2, '0')}-${future.day.toString().padLeft(2, '0')}';

      final data = await HomeownerService.instance.getContractorAvailability(
        contractorId: contractorId,
        urgency: _selectedUrgency.urgencySlug,
        fromDate: fromDate,
        toDate: toDate,
        propertyZip: _selectedPropertyZip,
        durationMinutes: _selectedService.durationMinutes,
        serviceName: _selectedService.title,
        serviceCategory: _proTrade,
        workOrderType: _selectedPricingChoice.workOrderType,
      );

      final slotsList = _readList(data['slots']) ?? [];
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
        _buildSlots(slotsList);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
        _slotsError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _buildSlots(List<dynamic> slotsList) {
    _dates = [];
    _slotsByDate = {};
    final seenSlotKeys = <String>{};

    for (final slot in slotsList) {
      if (slot is! Map) continue;
      final startStr = _string(slot['start']);
      if (startStr == null) continue;
      try {
        final dt = DateTime.parse(startStr).toLocal();
        final dateKey = _formatDate(dt);
        final endStr = _string(slot['end']);
        final endDt = endStr != null
            ? DateTime.tryParse(endStr)?.toLocal()
            : dt.add(const Duration(hours: 2));
        final timeLabel =
            _formatArrivalWindow(dt, endDt ?? dt.add(const Duration(hours: 2)));
        final slotKey = '$dateKey|$timeLabel';
        if (!seenSlotKeys.add(slotKey)) {
          continue;
        }
        _dates.add(dateKey);
        _slotsByDate.putIfAbsent(dateKey, () => []);
        _slotsByDate[dateKey]!.add({
          'label': timeLabel,
          'slot': Map<String, dynamic>.from(slot),
        });
      } catch (_) {}
    }

    _dates = _dates.toSet().toList();
    if (_dates.isNotEmpty) {
      _selectedDate = _dates.first;
      final nextSlots = _slotsByDate[_selectedDate] ?? [];
      _selectedTime = nextSlots.isNotEmpty ? nextSlots.first['label'] as String : null;
    }
  }

  Future<void> _pickPhotos() async {
    final images = await _picker.pickMultiImage();
    if (images.isEmpty || !mounted) return;
    setState(() => _selectedPhotos.addAll(images));
  }

  Future<void> _goToPage(int index) async {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _pageIndex = index);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToNext() {
    if (_pageIndex < _pages.length - 1) {
      _goToPage(_pageIndex + 1);
    }
  }

  void _goBack() {
    if (_pageIndex > 0) {
      _goToPage(_pageIndex - 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _dismissWithDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 500) {
      Navigator.maybePop(context);
    }
  }

  Future<void> _autoAdvance() async {
    await Future.delayed(const Duration(milliseconds: 180));
    if (mounted) {
      _goToNext();
    }
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final contractorId = _contractorId ??
          _string(widget.pro['contractorId']) ??
          _string(widget.pro['contractor_id']);
      if (contractorId == null || contractorId.isEmpty) {
        throw Exception('This contractor is missing booking details right now.');
      }
      final service = _selectedService;
      final selectedPricing = _selectedPricingChoice;

      String? startsAt;
      String? endsAt;
      if (!_asap &&
          _selectedDate != null &&
          _slotsByDate.containsKey(_selectedDate)) {
        final slotsForDate = _slotsByDate[_selectedDate];
        if (slotsForDate != null && slotsForDate.isNotEmpty) {
          final chosen = slotsForDate.firstWhere(
            (s) => s['label'] == _selectedTime,
            orElse: () => slotsForDate.first,
          );
          final slot = chosen['slot'] as Map<String, dynamic>?;
          startsAt = _string(slot?['start']);
          endsAt = _string(slot?['end']);
        }
      }
      startsAt ??= DateTime.now().add(const Duration(days: 1)).toIso8601String();
      endsAt ??=
          DateTime.parse(startsAt).add(const Duration(hours: 2)).toIso8601String();

      final address = _selectedAddressObj;
      final street = _string(address?['street']) ?? '124 Skyview Lane';
      final city = _string(address?['city']) ?? 'Tampa';
      final state = _string(address?['state']) ?? 'FL';
      final zip = _string(address?['zip']) ?? '33578';

      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': service.title,
        'service_description':
            _issueController.text.trim().isNotEmpty ? _issueController.text.trim() : service.subtitle,
        'address_street': street,
        'address_city': city,
        'address_state': state,
        'address_zip': zip,
        'work_order_type': selectedPricing.workOrderType,
        'access_notes': _accessNotesController.text.trim(),
        'service_details': service.title,
        'attached_photos': _selectedPhotos.map((p) => p.path).toList(),
        'selected_pricing_label': selectedPricing.label,
      };

      final response = await HomeownerService.instance.commitBooking(
        contractorId: contractorId,
        action: selectedPricing.workOrderType == 'quote_request'
            ? 'quote_request'
            : 'commit',
        urgency: _selectedUrgency.urgencySlug,
        booking: bookingData,
        startsAt: startsAt,
        endsAt: endsAt,
      );

      if (!mounted) return;
      final viewed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            woNumber: response['woNumber']?.toString(),
            scheduledStart: response['scheduledStart']?.toString() ?? startsAt,
          ),
        ),
      );
      if (viewed == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      final errStr = e.toString().replaceAll('Exception: ', '');
      if (errStr.contains('verification_required') && mounted) {
        try {
          await HomeownerService.instance
              .sendVerificationEmail(AuthService.instance.userEmail ?? '');
        } catch (_) {}
        _showVerificationDialog();
      } else if (mounted) {
        final message = HomeownerService.instance.bookingErrorMessage(e);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Booking Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showVerificationDialog() {
    final codeController = TextEditingController();
    bool verifying = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.orange500, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Verify Email',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.navy700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We sent a 6-digit code to ${AuthService.instance.userEmail ?? 'your email'}. Enter it below to secure your account and confirm booking.',
                    style: const TextStyle(fontSize: 13, color: AppTheme.ink, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        letterSpacing: 8,
                      ),
                      counterText: '',
                      errorText: localError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.line),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.orange500),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: verifying ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.gray)),
                ),
                ElevatedButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDlgState(() => localError = 'Please enter a 6-digit code');
                            return;
                          }
                          setDlgState(() {
                            verifying = true;
                            localError = null;
                          });
                          try {
                            await HomeownerService.instance.confirmVerification(code);
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (mounted) _submitBooking();
                          } catch (err) {
                            setDlgState(() {
                              verifying = false;
                              localError = err.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: verifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.navy700,
                          ),
                        )
                      : const Text('Verify & Book', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _UrgencyOption get _selectedUrgency =>
      _urgencyOptions[_selectedUrgencyIndex.clamp(0, _urgencyOptions.length - 1)];

  _PricingChoice get _selectedPricingChoice =>
      _pricingChoices[_selectedPricingIndex.clamp(0, _pricingChoices.length - 1)];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: AppTheme.pageAlt,
        body: SafeArea(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onVerticalDragEnd: _dismissWithDrag,
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4DAE2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                _buildHeader(),
                _buildProgress(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      if (index != _pageIndex) {
                        setState(() => _pageIndex = index);
                      }
                    },
                    itemBuilder: (context, index) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: _buildStepFor(_pages[index]),
                      );
                    },
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: AppTheme.navy700),
            onPressed: _goBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book $_proName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isLastPage ? 'Last step' : 'Step $_currentStepNumber of $_totalSteps',
                  style: const TextStyle(
                    color: AppTheme.teal700,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_currentPage == _BookingPage.review)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.orangeTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.verified,
                color: AppTheme.orange500,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final on = index <= _pageIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: index == _totalSteps - 1 ? 0 : 4),
              height: 4,
              decoration: BoxDecoration(
                color: on ? AppTheme.teal500 : AppTheme.line.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepFor(_BookingPage page) {
    switch (page) {
      case _BookingPage.service:
        return _buildServiceStep();
      case _BookingPage.details:
        return _buildDetailsStep();
      case _BookingPage.pricing:
        return _buildPricingStep();
      case _BookingPage.urgency:
        return _buildUrgencyStep();
      case _BookingPage.schedule:
        return _buildScheduleStep();
      case _BookingPage.location:
        return _buildLocationStep();
      case _BookingPage.review:
        return _buildReviewStep();
    }
  }

  Widget _buildServiceStep() {
    return _stepShell(
      title: 'What do you need?',
      subtitle: 'Prices are $_proName\'s own. You\'ll see the full amount before you confirm.',
      child: Column(
        children: _serviceOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          final selected = index == _selectedServiceIndex;
          return _selectionCard(
            selected: selected,
            onTap: () {
              setState(() {
                _selectedServiceIndex = index;
                _selectedPricingIndex = 0;
                _issueController.text = service.subtitle.isNotEmpty
                    ? service.subtitle
                    : _fallbackDescription;
              });
              _refreshAvailability();
              _autoAdvance();
            },
            title: service.title,
            subtitle: service.subtitle,
            trailing: service.priceLabel,
            trailingSub: service.pricingDetail,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDetailsStep() {
    final chips = _detailChipsForTrade(_proTrade);
    return _stepShell(
      title: 'Tell us about the job',
      subtitle: 'Structured details help the pro arrive with the right parts and make the price more accurate.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick details',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: chips
                .map(
                  (label) => ChoiceChip(
                    selected: _selectedDetailChips.contains(label),
                    label: Text(label),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedDetailChips.add(label);
                        } else {
                          _selectedDetailChips.remove(label);
                        }
                      });
                    },
                    side: const BorderSide(color: AppTheme.line),
                    backgroundColor: Colors.white,
                    selectedColor: AppTheme.tealTint,
                    labelStyle: const TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          _fieldLabel('Describe the problem'),
          _textField(
            controller: _issueController,
            hint: 'E.g. Upstairs is not cooling, started Sunday.',
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          _fieldLabel('Photos (optional)'),
          GestureDetector(
            onTap: _pickPhotos,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.pageAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.line),
              ),
              child: Column(
                children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppTheme.gray, size: 30),
                  const SizedBox(height: 8),
                  Text(
                    _selectedPhotos.isEmpty
                        ? 'Tap to upload photos'
                        : 'Tap to add more photos (${_selectedPhotos.length} added)',
                    style: const TextStyle(color: AppTheme.gray, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPhotos
                  .map(
                    (photo) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(photo.path),
                            width: 76,
                            height: 76,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -5,
                          top: -5,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedPhotos.remove(photo));
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingStep() {
    return _stepShell(
      title: 'How this is priced',
      subtitle:
          'Choose the pricing path for this service. You will always see the full amount or approval rule before you confirm.',
      child: Column(
        children: _pricingChoices.asMap().entries.map((entry) {
          final index = entry.key;
          final pricing = entry.value;
          final selected = index == _selectedPricingIndex;
          return _selectionCard(
            selected: selected,
            onTap: () {
              setState(() => _selectedPricingIndex = index);
              _autoAdvance();
            },
            title: pricing.label,
            subtitle: pricing.detail,
            trailing: pricing.priceText,
            trailingSub: pricing.secondaryText,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildUrgencyStep() {
    return _stepShell(
      title: 'How soon do you need this?',
      subtitle: 'These options and fees are set by $_proName. Other pros differ.',
      child: Column(
        children: _urgencyOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final tier = entry.value;
          final selected = index == _selectedUrgencyIndex;
          return Opacity(
            opacity: tier.available ? 1 : 0.42,
            child: _selectionCard(
              selected: selected && tier.available,
              onTap: tier.available
                  ? () {
                      setState(() => _selectedUrgencyIndex = index);
                      _refreshAvailability();
                      _autoAdvance();
                    }
                  : null,
              title: tier.label,
              subtitle: tier.detail,
              trailing: tier.feeLabel,
              trailingSub: tier.available ? 'Set by $_proName' : 'Unavailable right now',
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildScheduleStep() {
    return _stepShell(
      title: 'When works for you?',
      subtitle: 'Live from $_proName\'s calendar. Times are in your property\'s timezone.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Pick a day'),
          const SizedBox(height: 8),
          if (_isLoadingSlots)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.orange500)),
            )
          else if (_slotsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_slotsError!, style: const TextStyle(color: AppTheme.error)),
                if (_slotsError!.toLowerCase().contains('unauthenticated') &&
                    !AuthService.instance.isAuthenticated) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                      if (mounted) {
                        _refreshAvailability();
                      }
                    },
                    child: const Text('Sign in to see live slots'),
                  ),
                ],
              ],
            )
          else if (_dates.isEmpty)
            const Text('No arrival windows are available.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dates.map((date) {
                final selected = date == _selectedDate;
                return ChoiceChip(
                  selected: selected,
                  label: Text(date),
                  selectedColor: AppTheme.navy700,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.navy700,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? AppTheme.navy700 : AppTheme.line),
                  onSelected: (_) {
                    setState(() {
                      _selectedDate = date;
                      final nextSlots = _slotsByDate[date] ?? [];
                      _selectedTime =
                          nextSlots.isNotEmpty ? nextSlots.first['label'] as String : null;
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          _fieldLabel('Pick an arrival window'),
          const SizedBox(height: 8),
          if (_selectedDate == null || (_slotsByDate[_selectedDate] ?? []).isEmpty)
            const Text('No arrival windows are available.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (_slotsByDate[_selectedDate] ?? []).map((slotMap) {
                final label = slotMap['label'] as String;
                final selected = _selectedTime == label;
                return ChoiceChip(
                  selected: selected,
                  label: Text(label),
                  selectedColor: AppTheme.teal500,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.navy700,
                    fontWeight: FontWeight.w700,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? AppTheme.teal500 : AppTheme.line),
                  onSelected: (_) {
                    setState(() {
                      _selectedTime = label;
                    });
                    _autoAdvance();
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.pageAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'The pro will message you with a tighter ETA on the day. Live status starts once the work order is booked.',
              style: TextStyle(color: AppTheme.gray, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return _stepShell(
      title: 'Where & anything we should know',
      subtitle: 'Separate the job description from access instructions. Photos and notes stay attached to the work order.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Service address'),
          const SizedBox(height: 8),
          if (_isLoadingAddresses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppTheme.orange500)),
            )
          else if (_selectedAddressObj == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F4),
                border: Border.all(color: AppTheme.error.withOpacity(0.35)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No address saved',
                    style: TextStyle(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('You must add an address before booking.'),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _openManageAddresses,
                    child: const Text('Add an Address'),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: _openManageAddresses,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.tealTint,
                  border: Border.all(color: AppTheme.teal500, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home, color: AppTheme.teal700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_selectedAddressObj?['label'] ?? 'Home'} · ${_selectedAddressObj?['street']}, ${_selectedAddressObj?['city']}, ${_selectedAddressObj?['state']} ${_selectedAddressObj?['zip']}',
                        style: const TextStyle(
                          color: AppTheme.navy700,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const Text(
                      'Change',
                      style: TextStyle(
                        color: AppTheme.teal700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          _fieldLabel('Describe the problem'),
          _textField(
            controller: _issueController,
            hint: 'Upstairs is not cooling, started Sunday.',
            maxLines: 3,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Gate / access code'),
          _textField(
            controller: _accessNotesController,
            hint: 'e.g. #4233',
            maxLines: 1,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Getting in & on-site notes'),
          _textField(
            controller: _onsiteNotesController,
            hint: 'Parking, pets, where the unit is...',
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Photos'),
          if (_selectedPhotos.isEmpty)
            GestureDetector(
              onTap: _pickPhotos,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppTheme.line),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Tap to add photos',
                    style: TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedPhotos.map(
                  (photo) => ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(photo.path),
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _pickPhotos,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.line),
                    ),
                    child: const Icon(Icons.add, color: AppTheme.teal700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final pricing = _selectedPricingChoice;
    final estimatedCredits = ((pricing.amount ?? _selectedService.amount ?? 149) * 0.05).round();

    return _stepShell(
      title: 'Review & confirm',
      subtitle: 'Confirm the details below to book.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Pro', _proName, action: 'Change'),
          _summaryRow('Service', _selectedService.title, action: 'Change'),
          _summaryRow('Pricing', pricing.label),
          _summaryRow('Urgency', _selectedUrgency.label, action: 'Change'),
          _summaryRow(
            'When',
            _asap
                ? 'As soon as possible'
                : (_selectedDate != null && _selectedTime != null)
                    ? '$_selectedDate, $_selectedTime'
                    : 'Anytime',
            action: 'Change',
          ),
          _summaryRow(
            'Where',
            '${_selectedAddressObj?['label'] ?? 'Home'} · ${_selectedAddressObj?['street'] ?? 'Address'}',
            action: 'Change',
          ),
          _summaryRow(
            'Details',
            '${_issueController.text.trim().isEmpty ? _selectedService.subtitle : _issueController.text.trim()}${_selectedPhotos.isNotEmpty ? '\n${_selectedPhotos.length} photos' : ''}',
            multiline: true,
          ),
          if (_onsiteNotesController.text.trim().isNotEmpty)
            _summaryRow(
              'Access',
              _onsiteNotesController.text.trim(),
              multiline: true,
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.navyTint,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pricing.priceText,
                  style: const TextStyle(
                    color: AppTheme.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pricing.priceHeadline,
                  style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'You pay $_proName directly · \$0 markup, no platform fee.',
                  style: const TextStyle(color: AppTheme.ink, height: 1.4),
                ),
                const SizedBox(height: 10),
                Text(
                  'You\'ll earn about \$$estimatedCredits in service credits when this job is completed.',
                  style: const TextStyle(
                    color: AppTheme.teal700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'We will quickly verify your email to finish.',
            style: TextStyle(color: AppTheme.gray, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _stepShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.navy700,
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.gray,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        child,
      ],
    );
  }

  Widget _buildFooter() {
    final label = _isLastPage
        ? 'Confirm booking'
        : (_currentPage == _BookingPage.location ? 'Review booking' : 'Continue');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: Row(
        children: [
          if (_pageIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _goBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.line),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    color: AppTheme.navy700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_pageIndex > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_isLastPage) {
                        _submitBooking();
                      } else {
                        _goToNext();
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.orange500,
                foregroundColor: AppTheme.navy700,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.navy700,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectionCard({
    required String title,
    required String subtitle,
    required String trailing,
    required String trailingSub,
    required VoidCallback? onTap,
    required bool selected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.tealTint : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppTheme.teal500 : AppTheme.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _radio(selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? AppTheme.teal700 : AppTheme.navy700,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    trailing,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppTheme.navy700,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trailingSub,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppTheme.gray,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radio(bool selected) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppTheme.teal500 : AppTheme.line,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.teal500,
                ),
              ),
            )
          : null,
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.navy700,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.teal500),
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    String? action,
    bool multiline = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8EDF3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.gray,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: multiline ? 3 : 1,
              overflow: multiline ? TextOverflow.ellipsis : TextOverflow.visible,
              style: const TextStyle(
                color: AppTheme.navy700,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 8),
            Text(
              action,
              style: const TextStyle(
                color: AppTheme.teal700,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openManageAddresses() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(builder: (_) => const ManageAddressesScreen()),
    );
    if (!mounted) return;
    await _loadAddresses();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final check = DateTime(dt.year, dt.month, dt.day);
    if (check == today) return 'Today';
    if (check == tomorrow) return 'Tomorrow';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _formatArrivalWindow(DateTime start, DateTime end) {
    String format(DateTime dt) {
      var hour = dt.hour;
      final isPm = hour >= 12;
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '$hour${isPm ? ' PM' : ' AM'}';
    }

    return '${format(start)}-${format(end)}';
  }

  List<String> _detailChipsForTrade(String trade) {
    final lower = trade.toLowerCase();
    if (lower.contains('hvac') || lower.contains('air') || lower.contains('cool')) {
      return const ['Central air', 'Heat pump', 'Mini-split', 'Not cooling', 'Short cycling'];
    }
    if (lower.contains('plumb') || lower.contains('water')) {
      return const ['Drain', 'Leak under sink', 'Water heater', 'Toilet', 'Shower'];
    }
    if (lower.contains('electr') || lower.contains('light')) {
      return const ['Outlet', 'Light fixture', 'Breaker', 'Ceiling fan', 'Panel'];
    }
    return const ['Inspect', 'Repair', 'Install', 'Replace', 'Not sure'];
  }

  List<_ServiceOption> _fallbackServiceOptions() {
    final trade = _proTrade.toLowerCase();
    if (trade.contains('hvac') || trade.contains('air') || trade.contains('cool')) {
      return const [
        _ServiceOption(
          title: 'AC repair (diagnose + fix)',
          subtitle: 'Not cooling, short cycling, leaking',
          amount: 149,
          priceLabel: 'From \$149',
          pricingLabel: 'Upfront price',
          pricingDetail: 'Best for routine, pre-priced work.',
          durationMinutes: 120,
          pricingChoices: [
            _PricingChoice(
              label: 'Upfront price',
              detail: 'See the price before you book.',
              amount: 149,
              priceText: 'From \$149',
              priceHeadline: '\$149',
              workOrderType: 'rate_card',
              secondaryText: 'Upfront price',
            ),
            _PricingChoice(
              label: 'You approve the cap',
              detail: 'Diagnose first, then approve a not-to-exceed cap before work begins.',
              amount: 89,
              priceText: '\$89 diagnostic',
              priceHeadline: 'You approve the cap',
              workOrderType: 'nte',
              secondaryText: 'Diagnostic waived if approved',
            ),
            _PricingChoice(
              label: 'Free estimate',
              detail: 'Review itemized estimates from 1–2 vetted pros and pick one.',
              amount: null,
              priceText: 'Free estimate',
              priceHeadline: 'Free estimate',
              workOrderType: 'quote_request',
              secondaryText: '1–2 pro review',
            ),
          ],
        ),
      ];
    }

    if (trade.contains('plumb')) {
      return const [
        _ServiceOption(
          title: 'Drain cleaning',
          subtitle: 'Clogged drain, leak repair, faucet trouble',
          amount: 119,
          priceLabel: 'From \$119',
          pricingLabel: 'Upfront price',
          pricingDetail: 'Common plumbing repairs',
          durationMinutes: 90,
          pricingChoices: [
            _PricingChoice(
              label: 'Upfront price',
              detail: 'Flat service price shown before booking.',
              amount: 119,
              priceText: 'From \$119',
              priceHeadline: '\$119',
              workOrderType: 'rate_card',
              secondaryText: 'Upfront price',
            ),
            _PricingChoice(
              label: 'You approve the cap',
              detail: 'Inspect first, then approve the cap.',
              amount: 89,
              priceText: '\$89 diagnostic',
              priceHeadline: 'You approve the cap',
              workOrderType: 'nte',
              secondaryText: 'Diagnostic waived if approved',
            ),
          ],
        ),
      ];
    }

    return [
      _ServiceOption(
        title: 'Service visit',
        subtitle: _fallbackDescription,
        amount: _readInt(widget.pro['fromPrice']) ?? 149,
        priceLabel: 'From \$${_readInt(widget.pro['fromPrice']) ?? 149}',
        pricingLabel: 'Upfront price',
        pricingDetail: 'See the full price before you confirm.',
        durationMinutes: 120,
        pricingChoices: [
          _PricingChoice(
            label: 'Upfront price',
            detail: 'See the price before you book.',
            amount: _readInt(widget.pro['fromPrice']) ?? 149,
            priceText: 'From \$${_readInt(widget.pro['fromPrice']) ?? 149}',
            priceHeadline: '\$${_readInt(widget.pro['fromPrice']) ?? 149}',
            workOrderType: _string(widget.pro['workOrderType']) ?? 'rate_card',
            secondaryText: 'Upfront price',
          ),
        ],
      ),
    ];
  }

  List<dynamic>? _readList(dynamic value) {
    if (value is List) return value;
    return null;
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  int? _readInt(dynamic value) {
    final text = _string(value);
    if (text == null) return null;
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  String? _extractContractorId(Map<String, dynamic> source) {
    for (final key in const [
      'contractorId',
      'contractor_id',
      'proId',
      'pro_id',
      'assignedContractorId',
      'assigned_contractor_id',
    ]) {
      final value = _string(source[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _profileSlug() {
    final direct = _string(widget.pro['slug']) ?? _string(widget.pro['profileSlug']);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final businessName =
        _string(widget.pro['businessName']) ?? _string(widget.pro['business_name']);
    if (businessName == null || businessName.isEmpty) {
      return null;
    }

    final normalized = businessName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return normalized.isEmpty ? null : normalized;
  }
}

class _ServiceOption {
  final String title;
  final String subtitle;
  final int? amount;
  final String priceLabel;
  final String pricingLabel;
  final String pricingDetail;
  final int? durationMinutes;
  final List<_PricingChoice> pricingChoices;

  const _ServiceOption({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.priceLabel,
    required this.pricingLabel,
    required this.pricingDetail,
    required this.durationMinutes,
    required this.pricingChoices,
  });

  factory _ServiceOption.fromString(String value, {required String trade}) {
    final lower = value.toLowerCase();
    if (trade.toLowerCase().contains('hvac') && lower.contains('repair')) {
      return _ServiceOption(
        title: value,
        subtitle: 'Not cooling, short cycling, leaking',
        amount: 149,
        priceLabel: 'From \$149',
        pricingLabel: 'Upfront price',
        pricingDetail: 'See the price before you book.',
        durationMinutes: 120,
        pricingChoices: const [
          _PricingChoice(
            label: 'Upfront price',
            detail: 'See the price before you book.',
            amount: 149,
            priceText: 'From \$149',
            priceHeadline: '\$149',
            workOrderType: 'rate_card',
            secondaryText: 'Upfront price',
          ),
        ],
      );
    }
    return _ServiceOption(
      title: value,
      subtitle: 'Service request',
      amount: 129,
      priceLabel: 'From \$129',
      pricingLabel: 'Upfront price',
      pricingDetail: 'See the price before you book.',
      durationMinutes: 120,
      pricingChoices: const [
        _PricingChoice(
          label: 'Upfront price',
          detail: 'See the price before you book.',
          amount: 129,
          priceText: 'From \$129',
          priceHeadline: '\$129',
          workOrderType: 'rate_card',
          secondaryText: 'Upfront price',
        ),
      ],
    );
  }

  factory _ServiceOption.fromMap(Map<String, dynamic> map) {
    final choices = <_PricingChoice>[];
    final rawChoices = map['pricing_options'] ??
        map['pricingOptions'] ??
        map['pricing_paths'] ??
        map['pricingPaths'];
    if (rawChoices is List) {
      for (final choice in rawChoices) {
        if (choice is Map) {
          choices.add(_PricingChoice.fromMap(Map<String, dynamic>.from(choice)));
        } else if (choice != null) {
          choices.add(_PricingChoice(
            label: choice.toString(),
            detail: '',
            amount: null,
            priceText: choice.toString(),
            priceHeadline: choice.toString(),
            workOrderType: 'rate_card',
            secondaryText: '',
          ));
        }
      }
    }

    final price = _parseInt(map['fromPrice'] ?? map['price'] ?? map['amount']);
    final workOrderType = _string(map['workOrderType']) ?? 'rate_card';
    final durationMinutes = _parseInt(
      map['duration_minutes'] ?? map['durationMinutes'] ?? map['duration'],
    );
    final title = _string(map['name']) ??
        _string(map['title']) ??
        _string(map['service_name']) ??
        'Service';
    final subtitle = _string(map['description']) ??
        _string(map['summary']) ??
        _string(map['details']) ??
        'Service request';

    if (choices.isEmpty) {
      choices.add(
        _PricingChoice(
          label: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? 'You approve the cap'
                  : 'Upfront price',
          detail: workOrderType == 'quote_request'
              ? 'Review itemized estimates from 1–2 vetted pros and pick one.'
              : workOrderType == 'nte'
                  ? 'Diagnose first, then approve a not-to-exceed cap before work begins.'
                  : 'See the price before you book.',
          amount: price,
          priceText: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? '\$89 diagnostic'
                  : 'From \$${price ?? 149}',
          priceHeadline: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? 'You approve the cap'
                  : '\$${price ?? 149}',
          workOrderType: workOrderType,
          secondaryText: workOrderType == 'quote_request'
              ? '1–2 pro review'
              : workOrderType == 'nte'
                  ? 'Diagnostic waived if approved'
                  : 'Upfront price',
        ),
      );
    }

    return _ServiceOption(
      title: title,
      subtitle: subtitle,
      amount: price,
      priceLabel: choices.first.priceText,
      pricingLabel: _string(map['pricing_label']) ??
          _string(map['pricingLabel']) ??
          choices.first.label,
      pricingDetail: _string(map['pricing_detail']) ??
          _string(map['pricingDetail']) ??
          choices.first.detail,
      durationMinutes: durationMinutes,
      pricingChoices: choices,
    );
  }

  static int? _parseInt(dynamic value) {
    final text = value?.toString();
    if (text == null) return null;
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }
}

class _PricingChoice {
  final String label;
  final String detail;
  final int? amount;
  final String priceText;
  final String priceHeadline;
  final String workOrderType;
  final String secondaryText;

  const _PricingChoice({
    required this.label,
    required this.detail,
    required this.amount,
    required this.priceText,
    required this.priceHeadline,
    required this.workOrderType,
    required this.secondaryText,
  });

  factory _PricingChoice.fromMap(Map<String, dynamic> map) {
    final label = _string(map['label']) ?? _string(map['name']) ?? 'Option';
    final detail = _string(map['detail']) ?? _string(map['description']) ?? '';
    final amount = _parseInt(map['price'] ?? map['amount']);
    final workOrderType =
        _string(map['workOrderType']) ?? _string(map['type']) ?? 'rate_card';
    final headline = _string(map['headline']) ??
        _string(map['priceHeadline']) ??
        (amount != null ? '\$$amount' : label);
    final priceText =
        _string(map['priceText']) ?? (amount != null ? 'From \$$amount' : label);
    final secondaryText =
        _string(map['secondaryText']) ?? _string(map['subtitle']) ?? '';
    return _PricingChoice(
      label: label,
      detail: detail,
      amount: amount,
      priceText: priceText,
      priceHeadline: headline,
      workOrderType: workOrderType,
      secondaryText: secondaryText,
    );
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int? _parseInt(dynamic value) {
    final text = value?.toString();
    if (text == null) return null;
    return int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  }
}

class _UrgencyOption {
  final String label;
  final String detail;
  final String feeLabel;
  final String urgencySlug;
  final bool available;

  const _UrgencyOption({
    required this.label,
    required this.detail,
    required this.feeLabel,
    required this.urgencySlug,
    required this.available,
  });

  factory _UrgencyOption.fromMap(Map<String, dynamic> map) {
    final label = _string(map['label']) ?? _string(map['name']) ?? 'Standard';
    final detail = _string(map['detail']) ??
        _string(map['description']) ??
        _string(map['responseWindow']) ??
        'Set by the pro';
    final feeLabel = _string(map['feeLabel']) ??
        _string(map['fee_label']) ??
        _string(map['price']) ??
        'Included';
    final urgencySlug =
        _string(map['urgencySlug']) ?? _string(map['urgency_slug']) ?? label.toLowerCase();
    final available = map['available'] != false && map['isAvailable'] != false;
    return _UrgencyOption(
      label: label,
      detail: detail,
      feeLabel: feeLabel,
      urgencySlug: urgencySlug,
      available: available,
    );
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }
}
