import '../widgets/loading_skeleton.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../utils/booking_timing.dart';
import '../services/intake_service.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../services/stream_service.dart';
import '../theme.dart';
import '../ui/tw.dart';
import '../utils/display_format.dart';
import '../utils/transaction_id.dart';
import '../widgets/app_notification.dart';
import 'account/manage_addresses.dart';
import 'booking_success_screen.dart';

enum BookFlowExit { changeContractor }

enum _BookingPage {
  service,
  details,
  urgency,
  schedule,
  review,
}

class BookFlowScreen extends StatefulWidget {
  final Map<String, dynamic> pro;
  final String? initialDescription;

  const BookFlowScreen({
    super.key,
    required this.pro,
    this.initialDescription,
  });

  /// The booking flow is a bottom sheet over the screen that opened it
  /// (C01–C05). Non-opaque so the profile shows under the dimmed strip.
  static Route<T> route<T>({
    required Map<String, dynamic> pro,
    String? initialDescription,
  }) {
    return PageRouteBuilder<T>(
      opaque: false,
      barrierColor: AppTheme.navy.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => BookFlowScreen(
        pro: pro,
        initialDescription: initialDescription,
      ),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  State<BookFlowScreen> createState() => _BookFlowScreenState();
}

class _BookFlowScreenState extends State<BookFlowScreen> {

  late final PageController _pageController;
  final _issueController = TextEditingController();
  final _creditAmountController = TextEditingController();
  final _accessCodeController = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _selectedDetailChips = <String>{};
  late final String _bookingTransactionId = TransactionId.create('booking');
  late final String _creditRequestId = TransactionId.uuid();

  final List<XFile> _selectedPhotos = [];
  final List<dynamic> _addresses = [];

  Map<String, dynamic>? _contractorProfile;
  Map<String, dynamic>? _contractorProfileResponse;
  Map<String, dynamic>? _selectedAddressObj;
  String? _contractorId;
  final Map<String, String> _urgencyAvailabilityDetails = {};
  final Map<String, String> _urgencyAvailabilityPrices = {};
  final Map<String, bool> _urgencyAvailabilityStates = {};
  Map<String, dynamic>? _selectedAvailability;

  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  bool _exitRequested = false;
  bool _returnToReviewAfterEdit = false;
  bool _useServiceCredits = false;
  String? _slotsError;
  String? _profileLoadError;
  double? _availableServiceCredits;

  int _pageIndex = 0;
  int _selectedServiceIndex = 0;
  int _selectedPricingIndex = 0;
  int _selectedUrgencyIndex = -1;
  int _availabilityGeneration = 0;
  final Map<String, String> _uploadedBookingPhotos = {};
  String? _bookingIntakeToken;
  String? _selectedDate;
  String? _selectedTime;

  List<String> _dates = [];
  Map<String, List<Map<String, dynamic>>> _slotsByDate = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _issueController.text = widget.initialDescription?.trim() ?? '';
    if (!AuthService.instance.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.maybePop(context);
      });
      return;
    }
    _loadProfileAndAvailability();
    _loadAddresses();
    _loadServiceCredits();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _issueController.dispose();
    _creditAmountController.dispose();
    _accessCodeController.dispose();
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
      '';

  String get _proTrade =>
      _string(_mergedPro['trade']) ?? _string(_mergedPro['category']) ?? '';

  String get _backendDescription =>
      _string(_mergedPro['summary']) ??
      _string(_mergedPro['overview']) ??
      _string(_mergedPro['description']) ??
      '';

  int? get _backendFromPrice =>
      _readInt(_mergedPro['fromPrice']) ??
      _readInt(_mergedPro['from_price']) ??
      _readInt(_mergedPro['startingPrice']) ??
      _readInt(_mergedPro['starting_price']) ??
      _readInt(_mergedPro['price']) ??
      _readInt(_mergedPro['amount']) ??
      _readInt(_mergedPro['rateAmount']) ??
      _readInt(_mergedPro['rate_amount']) ??
      _readInt(_mergedPro['minCharge']) ??
      _readInt(_mergedPro['min_charge']) ??
      _readInt(_mergedPro['upfrontPrice']) ??
      _readInt(_mergedPro['upfront_price']);

  bool get _hasBookableService => _selectedService.title.trim().isNotEmpty;

  void _changeContractor() {
    Navigator.of(context).pop(BookFlowExit.changeContractor);
  }

  List<_ServiceOption> get _serviceOptions {
    final parsed = <_ServiceOption>[];
    final seen = <String>{};
    for (final item in _backendItemsFor(const [
      'services',
      'service_options',
      'serviceOptions',
      'bookable_services',
      'bookableServices',
      'rate_card',
      'rateCard',
      'upfront_pricing',
      'upfrontPricing',
      'pricing',
      'pricing_options',
      'pricingOptions',
      'service_prices',
      'servicePrices',
    ])) {
      // Only services the pro can take bookings for: not pending admin
      // approval, not switched off (Oct 1).
      if (item is Map && !_isBookableServiceRecord(item)) continue;
      final option = item is Map
          ? _ServiceOption.fromMap(Map<String, dynamic>.from(item))
          : _ServiceOption.fromString(item.toString(), trade: _proTrade);
      final key =
          '${option.title.toLowerCase()}|${option.priceLabel.toLowerCase()}';
      if (option.title.trim().isNotEmpty && seen.add(key)) {
        parsed.add(option);
      }
    }

    if (parsed.isNotEmpty) return parsed;
    return [_backendServiceOption()];
  }

  _ServiceOption _backendServiceOption() {
    final title = _string(_mergedPro['selectedService']) ??
        _string(_mergedPro['serviceName']) ??
        _string(_mergedPro['service_name']) ??
        _string(_mergedPro['service']) ??
        _string(_mergedPro['jobType']) ??
        _string(_mergedPro['job_type']) ??
        _proTrade;
    final price = _backendFromPrice;
    final workOrderType = _string(_mergedPro['workOrderType']) ??
        _string(_mergedPro['work_order_type']) ??
        'rate_card';
    final explicitPriceText = _moneyText(
      _string(_mergedPro['fromPriceLabel']) ??
          _string(_mergedPro['priceText']) ??
          _string(_mergedPro['price_text']) ??
          _string(_mergedPro['priceLabel']),
    );
    final priceText = _formatPriceLabel(price).isNotEmpty
        ? _formatPriceLabel(price)
        : explicitPriceText;
    final pricingDetail = _string(_mergedPro['pricingDetail']) ??
        _string(_mergedPro['pricing_detail']) ??
        _string(_mergedPro['fromUnit']) ??
        _string(_mergedPro['from_unit']) ??
        _string(_mergedPro['rateLabel']) ??
        _string(_mergedPro['rate_label']) ??
        _string(_mergedPro['rateUnit']) ??
        _string(_mergedPro['rate_unit']) ??
        _string(_mergedPro['priceType']) ??
        _string(_mergedPro['priceLabel']) ??
        '';

    return _ServiceOption(
      title: title,
      subtitle: _backendDescription,
      amount: price,
      priceLabel: priceText,
      pricingLabel: _string(_mergedPro['pricingLabel']) ??
          _string(_mergedPro['pricing_label']) ??
          '',
      pricingDetail: pricingDetail,
      durationMinutes: _readInt(_mergedPro['durationMinutes']) ??
          _readInt(_mergedPro['duration_minutes']) ??
          _readInt(_mergedPro['duration']),
      pricingChoices: [
        _PricingChoice(
          label: _pricingTypeLabel(workOrderType),
          detail: pricingDetail,
          amount: price,
          priceText: priceText,
          priceHeadline: price == null ? priceText : formatUsd(price),
          workOrderType: workOrderType,
          secondaryText: pricingDetail,
        ),
      ],
      detailChips: const [],
    );
  }

  bool _isBookableServiceRecord(Map item) {
    for (final key in const [
      'active',
      'is_active',
      'isActive',
      'enabled',
      'bookable',
      'is_bookable',
      'isBookable',
    ]) {
      if (item[key] == false) return false;
    }
    final status =
        '${item['status'] ?? item['approval_status'] ?? item['approvalStatus'] ?? ''}'
            .toLowerCase()
            .trim();
    return !(status.startsWith('pending') ||
        const {'off', 'inactive', 'disabled', 'rejected', 'paused'}
            .contains(status));
  }

  String _serviceType(_ServiceOption service) => service.pricingChoices.isEmpty
      ? 'rate_card'
      : service.pricingChoices.first.workOrderType;

  /// The line under a service name says what kind of price it is (Oct 1).
  String _serviceTypeLine(_ServiceOption service) {
    switch (_serviceType(service)) {
      case 'nte':
        return 'You approve the cap';
      case 'quote_request':
        return 'The pro sends you an estimate';
      default:
        return 'Upfront price';
    }
  }

  /// "$129.00", "$89.00 diagnostic" or "Free visit" — never "From".
  String _servicePriceText(_ServiceOption service) {
    final type = _serviceType(service);
    if (type == 'quote_request') return 'Free visit';
    final amount = service.amount;
    if (amount == null) return '';
    final price = formatUsd(amount);
    return type == 'nte' ? '$price diagnostic' : price;
  }

  /// "$189.00" — never "From" (Batch 19 F2).
  String _formatPriceLabel(int? price) {
    if (price == null) return '';
    return formatUsd(price);
  }

  String _moneyText(String? value) {
    if (value == null) return '';
    final lower = value.toLowerCase();
    if (value.contains(r'$') ||
        lower.contains('free') ||
        lower.startsWith('from ')) {
      return _withoutFrom(value);
    }
    return '';
  }

  String _basePricingLabel() {
    final servicePrice = _moneyText(_selectedService.priceLabel);
    final base = servicePrice.isNotEmpty
        ? servicePrice
        : _formatPriceLabel(_backendFromPrice);
    return _priceAmountOnly(base);
  }

  String _websiteFromPriceValue() {
    final amount = _basePricingLabel().replaceFirst(
      RegExp(r'^from\s+', caseSensitive: false),
      '',
    );
    if (amount.isEmpty) return '';

    final unit = _basePricingUnitLabel();
    return unit.isEmpty ? amount : '$amount · $unit';
  }

  String _basePricingUnitLabel() {
    final base = _basePricingLabel();
    if (base.isEmpty) return '';

    final unit = _string(_mergedPro['fromUnit']) ??
        _string(_mergedPro['from_unit']) ??
        _selectedService.pricingDetail;
    if (unit.isEmpty ||
        unit.contains(r'$') ||
        unit.toLowerCase().startsWith('from ') ||
        base.toLowerCase().contains(unit.toLowerCase())) {
      return '';
    }
    return unit;
  }

  String _priceAmountOnly(String value) {
    final parts = value.split('·');
    return parts.first.trim();
  }

  String _urgencyCardPriceText(_UrgencyOption tier) {
    final fee = tier.feeLabel.trim();
    final isStandard = tier.urgencySlug.toLowerCase() == 'standard';
    if (!isStandard && !tier.available) return 'Not offered';
    if (fee.isEmpty || fee.toLowerCase() == 'included') {
      return isStandard ? 'Included' : '';
    }
    return fee;
  }

  /// The response promise per level (Oct 1): 48 / 24 / 4 hours.
  String _responseWindow(String slug) {
    switch (slug.toLowerCase()) {
      case 'emergency':
        return 'Within 4 hours';
      case 'urgent':
        return 'Within 24 hours';
      default:
        return 'Within 48 hours';
    }
  }

  String _selectedEmergencySurchargeLabel() {
    if (_selectedUrgency.urgencySlug.toLowerCase() != 'emergency') return '';
    final fee = _selectedUrgency.feeLabel.trim();
    if (fee.isEmpty || fee.toLowerCase() == 'included') return '';
    if (fee.startsWith('+')) return fee;
    if (fee.startsWith(r'$')) return '+$fee';
    return fee;
  }

  _ServiceOption get _selectedService => _serviceOptions[
      _selectedServiceIndex.clamp(0, _serviceOptions.length - 1)];

  List<_PricingChoice> get _pricingChoices => _selectedService.pricingChoices;

  List<_UrgencyOption> get _urgencyOptions {
    final optionsByUrgency = <String, _UrgencyOption>{};
    for (final item in _backendItemsFor(const [
      'urgency_tiers',
      'urgencyTiers',
      'urgencies',
      'urgency_options',
      'urgencyOptions',
      'response_times',
      'responseTimes',
      'response_options',
      'responseOptions',
      'service_levels',
      'serviceLevels',
      'availability_options',
      'availabilityOptions',
      'availability',
      'booking_availability',
      'bookingAvailability',
      'booking_tiers',
      'bookingTiers',
      'priorities',
      'priority_options',
      'priorityOptions',
      'service_level_options',
      'serviceLevelOptions',
    ])) {
      if (item is! Map) continue;
      final option = _UrgencyOption.fromMap(Map<String, dynamic>.from(item));
      final urgency = _canonicalUrgencySlug(option.urgencySlug);
      if (option.label.isNotEmpty && !optionsByUrgency.containsKey(urgency)) {
        optionsByUrgency[urgency] = option.copyWith(urgencySlug: urgency);
      }
    }
    return const ['standard', 'urgent', 'emergency']
        .map((urgency) =>
            optionsByUrgency[urgency] ?? _fallbackUrgencyOption(urgency))
        .map(_withLiveUrgencySummary)
        .toList();
  }

  String _canonicalUrgencySlug(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('emerg')) return 'emergency';
    if (normalized.contains('urgent')) return 'urgent';
    return 'standard';
  }

  _UrgencyOption _fallbackUrgencyOption(String slug) {
    final responseTime = _string(_mergedPro['responseTime']) ??
        _string(_mergedPro['nextAvailable']) ??
        '';
    switch (slug) {
      case 'urgent':
        return _UrgencyOption(
          label: 'Urgent',
          detail: _UrgencyOption.formatDetail(
            _string(_mergedPro['urgentResponseTime']) ??
                _string(_mergedPro['urgent_response_time']) ??
                _string(_mergedPro['urgentNextAvailable']) ??
                _string(_mergedPro['urgent_next_available']) ??
                'Within 24 hours',
          ),
          feeLabel: _urgencyFallbackPriceText('urgent'),
          urgencySlug: 'urgent',
          available: true,
        );
      case 'emergency':
        return _UrgencyOption(
          label: 'Emergency',
          detail: _UrgencyOption.formatDetail(
            _string(_mergedPro['emergencyResponseTime']) ??
                _string(_mergedPro['emergency_response_time']) ??
                _string(_mergedPro['emergencyNextAvailable']) ??
                _string(_mergedPro['emergency_next_available']) ??
                'Within 4 hours',
          ),
          feeLabel: _urgencyFallbackPriceText('emergency'),
          urgencySlug: 'emergency',
          available: true,
        );
      default:
        return _UrgencyOption(
          label: 'Standard',
          detail: _UrgencyOption.formatDetail(
            responseTime.isNotEmpty ? responseTime : 'Within 48 hours',
          ),
          feeLabel: _urgencyFallbackPriceText('standard'),
          urgencySlug: 'standard',
          available: true,
        );
    }
  }

  _UrgencyOption _withLiveUrgencySummary(_UrgencyOption option) {
    final key = option.urgencySlug.toLowerCase();
    final live = option.copyWith(
      detail: _urgencyAvailabilityDetails[key],
      feeLabel: _urgencyAvailabilityPrices[key],
      available: _urgencyAvailabilityStates[key],
    );
    if (key == 'standard') return live;
    // Urgent and Emergency need a fee to be offered (Oct 1). No fee, or no
    // answer yet from the pro's availability, means not available — never
    // "Included", never available by default.
    final fee = live.feeLabel.trim().toLowerCase();
    final hasFee = fee.isNotEmpty &&
        fee != 'included' &&
        readAmount(fee) != null &&
        readAmount(fee)! > 0;
    final confirmed = _urgencyAvailabilityStates[key] == true;
    return live.copyWith(available: hasFee && confirmed);
  }

  String _urgencyFallbackPriceText(String urgency) {
    final camelPrefix = '${urgency[0].toLowerCase()}${urgency.substring(1)}';
    final snakePrefix = urgency.toLowerCase();
    final explicit = _mergedPro['${camelPrefix}PriceLabel'] ??
        _mergedPro['${snakePrefix}_price_label'] ??
        _mergedPro['${camelPrefix}FeeLabel'] ??
        _mergedPro['${snakePrefix}_fee_label'] ??
        _mergedPro['${camelPrefix}Price'] ??
        _mergedPro['${snakePrefix}_price'] ??
        _mergedPro['${camelPrefix}PriceAmount'] ??
        _mergedPro['${snakePrefix}_price_amount'] ??
        _mergedPro['${camelPrefix}Fee'] ??
        _mergedPro['${snakePrefix}_fee'] ??
        _mergedPro['${camelPrefix}FeeAmount'] ??
        _mergedPro['${snakePrefix}_fee_amount'] ??
        _mergedPro['${camelPrefix}Surcharge'] ??
        _mergedPro['${snakePrefix}_surcharge'] ??
        _mergedPro['${camelPrefix}SurchargeAmount'] ??
        _mergedPro['${snakePrefix}_surcharge_amount'] ??
        _mergedPro['${camelPrefix}AdditionalFee'] ??
        _mergedPro['${snakePrefix}_additional_fee'] ??
        _mergedPro['${camelPrefix}AdditionalFeeAmount'] ??
        _mergedPro['${snakePrefix}_additional_fee_amount'];
    final formatted =
        _UrgencyOption.formatMoneyLabel(explicit, plusForPlainNumber: true);
    if (formatted.isNotEmpty) return formatted;
    return urgency.toLowerCase() == 'standard' ? 'Included' : '';
  }

  bool get _picksOwnTime => _selectedUrgency.urgencySlug == 'standard';

  bool _stepIsAnswered(_BookingPage page) {
    if (page == _BookingPage.urgency) return _selectedUrgencyIndex >= 0;
    if (page == _BookingPage.schedule)
      return !_isLoadingSlots && _selectedTime != null;
    if (page == _BookingPage.review)
      return _selectedUrgencyIndex >= 0 &&
          (!_picksOwnTime || _selectedTime != null);
    return true;
  }

  /// "By Wed, Oct 14, 9:20 AM", or "Today, by 5:40 PM" (decisions and seed
  /// date format).
  String _deadlineText() {
    final hours = BookingTiming.hours(_selectedUrgency.urgencySlug);
    if (hours == null) return '';
    final now = DateTime.now();
    final at = now.add(Duration(hours: hours));
    if (DateUtils.isSameDay(at, now)) {
      return 'Today, by ${DateFormat('h:mm a').format(at)}';
    }
    return 'By ${DateFormat('EEE, MMM d, h:mm a').format(at)}';
  }

  List<_BookingPage> get _pages {
    return <_BookingPage>[
      _BookingPage.service,
      _BookingPage.details,
      _BookingPage.urgency,
      if (_picksOwnTime) _BookingPage.schedule,
      _BookingPage.review,
    ];
  }

  bool get _isLastPage => _pageIndex == _pages.length - 1;

  int get _currentStepNumber => _pageIndex + 1;

  List<String> get _searchPhotoUrls {
    final urls = <String>[];

    void addUrl(dynamic raw) {
      final value = _string(raw);
      if (value == null || !value.startsWith('http') || urls.contains(value)) {
        return;
      }
      urls.add(value);
    }

    void collect(dynamic source) {
      final items = _readList(source) ?? const [];
      for (final item in items) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          addUrl(
            map['url'] ??
                map['imageUrl'] ??
                map['image_url'] ??
                map['photoUrl'] ??
                map['photo_url'] ??
                map['thumbnailUrl'] ??
                map['thumbnail_url'] ??
                map['signedUrl'] ??
                map['signed_url'],
          );
        } else {
          addUrl(item);
        }
      }
    }

    collect(_mergedPro['photos']);
    collect(_mergedPro['media']);
    collect(_mergedPro['projectPhotos']);
    collect(_mergedPro['project_photos']);
    collect(_mergedPro['gallery']);
    collect(_mergedPro['portfolio']);

    return urls.take(3).toList();
  }

  Future<void> _loadProfileAndAvailability() async {
    try {
      final slug = _profileSlug();
      if (slug != null && slug.isNotEmpty) {
        final data = await HomeownerService.instance.getContractorProfile(slug);
        if (mounted) {
          final profile = _extractContractorProfile(data);
          final resolvedId = _extractContractorId(profile) ??
              _string(widget.pro['contractorId']) ??
              _string(widget.pro['contractor_id']) ??
              await _resolveContractorIdForBooking(slug);
          setState(() {
            _contractorProfileResponse = data;
            _contractorProfile = profile;
            _contractorId = resolvedId;
          });
        }
      } else {
        if (mounted) setState(() {});
      }
      await _refreshAvailability();
      await _hydrateUrgencySummaries();
    } catch (e) {
      if (mounted) {
        final fallbackSlug = _profileSlug();
        final resolvedId = fallbackSlug == null
            ? null
            : await _resolveContractorIdForBooking(fallbackSlug);
        setState(() {
          _contractorId = _string(widget.pro['contractorId']) ??
              _string(widget.pro['contractor_id']) ??
              resolvedId;
          _profileLoadError = e.toString().replaceAll('Exception: ', '');
        });
      }
      await _refreshAvailability();
      await _hydrateUrgencySummaries();
    }
  }

  Future<String?> _resolveContractorIdForBooking(String slug) async {
    final normalizedSlug = slug.trim().toLowerCase();
    if (normalizedSlug.isEmpty) return null;

    final zip = _string(_selectedAddressObj?['zip']) ??
        _string(widget.pro['zip']) ??
        _string(widget.pro['address_zip']);
    if (zip == null) return null;
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
        final businessSlug =
            _string(map['businessName'])?.toLowerCase().replaceAll(' ', '-');
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
          if (_addresses.isNotEmpty) {
            _selectedAddressObj = _addresses.firstWhere(
              (a) => a['isDefault'] == true || a['isDefault'] == 'true',
              orElse: () => _addresses.first,
            );
          }
        });
        _prefillAccessCode();
        if (shouldRefreshAvailability) {
          await _refreshAvailability();
          await _hydrateUrgencySummaries();
        }
      }
    } catch (_) {
      if (mounted) {}
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
    final selectedUrgencyKey = _selectedUrgency.urgencySlug.toLowerCase();
    final generation = ++_availabilityGeneration;

    setState(() {
      _isLoadingSlots = true;
      _slotsError = null;
      _selectedAvailability = null;
      _buildSlots(const []);
    });

    try {
      final range = _availabilityDateRange();

      final data = await HomeownerService.instance.getContractorAvailability(
        contractorId: contractorId,
        serviceId: _selectedService.serviceId,
        urgency: _selectedUrgency.urgencySlug,
        fromDate: range.$1,
        toDate: range.$2,
      );

      final slotsList = BookingTiming.eligible(
          _readList(data['slots']) ?? [], selectedUrgencyKey);
      final selectedDetail = _firstAvailabilityDetail(slotsList);
      final selectedPrice = _availabilityPriceText(
        data,
        urgencySlug: _selectedUrgency.urgencySlug,
      );
      if (!mounted || generation != _availabilityGeneration) return;
      setState(() {
        _isLoadingSlots = false;
        _selectedAvailability = Map<String, dynamic>.from(data);
        if (selectedDetail != null) {
          _urgencyAvailabilityDetails[selectedUrgencyKey] = selectedDetail;
        }
        if (selectedPrice.isNotEmpty) {
          _urgencyAvailabilityPrices[selectedUrgencyKey] = selectedPrice;
        }
        _urgencyAvailabilityStates[selectedUrgencyKey] =
            _availabilityCanBook(data, slotsList, selectedUrgencyKey);
        _buildSlots(slotsList);
      });
    } catch (e) {
      if (!mounted || generation != _availabilityGeneration) return;
      setState(() {
        _isLoadingSlots = false;
        _selectedAvailability = null;
        _urgencyAvailabilityStates[selectedUrgencyKey] = false;
        _buildSlots(const []);
        _slotsError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _hydrateUrgencySummaries() async {
    final contractorId = _contractorId;
    if (contractorId == null || contractorId.isEmpty || !mounted) return;

    final range = _availabilityDateRange();
    final options = _urgencyOptions;
    final details = <String, String>{};
    final prices = <String, String>{};
    final states = <String, bool>{};

    await Future.wait(options.map((option) async {
      final key = option.urgencySlug.toLowerCase();
      try {
        final data = await HomeownerService.instance.getContractorAvailability(
          contractorId: contractorId,
          serviceId: _selectedService.serviceId,
          urgency: option.urgencySlug,
          fromDate: range.$1,
          toDate: range.$2,
        );
        final slotsList =
            BookingTiming.eligible(_readList(data['slots']) ?? [], key);
        final detail = _firstAvailabilityDetail(slotsList);
        final price = _availabilityPriceText(
          data,
          urgencySlug: option.urgencySlug,
        );
        if (detail != null) details[key] = detail;
        if (price.isNotEmpty) prices[key] = price;
        states[key] = _availabilityCanBook(data, slotsList, key);
      } catch (_) {
        // The selected urgency fetch still controls the schedule page.
      }
    }));

    if (!mounted || (details.isEmpty && prices.isEmpty && states.isEmpty))
      return;
    setState(() {
      _urgencyAvailabilityDetails.addAll(details);
      _urgencyAvailabilityPrices.addAll(prices);
      _urgencyAvailabilityStates.addAll(states);
    });
  }

  (String, String) _availabilityDateRange() {
    // Matches the website's UTC Y-M-D request window exactly.
    final now = DateTime.now().toUtc();
    final from = DateTime.utc(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 14));
    String format(DateTime value) =>
        '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
    return (format(from), format(to));
  }

  bool _availabilityCanBook(
    Map<String, dynamic> data,
    List<dynamic> slots,
    String urgency,
  ) {
    if (data['paused'] == true) return false;
    if (urgency == 'emergency' && data['emergencyEligible'] == false) {
      return false;
    }
    return slots.whereType<Map>().isNotEmpty;
  }

  String? _firstAvailabilityDetail(List<dynamic> slotsList) {
    final slots = slotsList.whereType<Map>().toList()
      ..sort((left, right) {
        final leftRaw = _availabilityStartText(left);
        final rightRaw = _availabilityStartText(right);
        final leftTime =
            DateTime.tryParse(leftRaw ?? '')?.millisecondsSinceEpoch ?? 0;
        final rightTime =
            DateTime.tryParse(rightRaw ?? '')?.millisecondsSinceEpoch ?? 0;
        return leftTime.compareTo(rightTime);
      });
    if (slots.isEmpty) return null;
    final detail = _UrgencyOption.formatDetail(
      _availabilityStartText(slots.first),
    );
    return detail.isEmpty ? null : detail;
  }

  String? _availabilityStartText(Map slot) {
    return _string(
      slot['start'] ??
          slot['startsAt'] ??
          slot['starts_at'] ??
          slot['start_at'] ??
          slot['windowStart'] ??
          slot['window_start'] ??
          slot['startLocal'] ??
          slot['start_local'],
    );
  }

  String _availabilityPriceText(
    Map<String, dynamic> data, {
    required String urgencySlug,
  }) {
    final option = _UrgencyOption.fromMap(data);
    if (option.feeLabel.isNotEmpty) return option.feeLabel;
    dynamic feeSource;
    for (final value in [
      data['urgencyFee'],
      data['urgency_fee'],
      data['fee'],
      data['feeAmount'],
      data['fee_amount'],
      data['surcharge'],
      data['surchargeAmount'],
      data['surcharge_amount'],
      data['additionalFee'],
      data['additional_fee'],
      data['additionalFeeAmount'],
      data['additional_fee_amount'],
    ]) {
      if (value != null) {
        feeSource = value;
        break;
      }
    }
    final feeLabel = _UrgencyOption.formatMoneyLabel(
      feeSource,
      plusForPlainNumber: true,
    );
    if (feeLabel.isNotEmpty) return feeLabel;
    if (data['included'] == true ||
        data['isIncluded'] == true ||
        data['is_included'] == true) {
      return 'Included';
    }
    if (urgencySlug.toLowerCase() == 'emergency' &&
        data['emergencyEligible'] == false) {
      return '';
    }
    return urgencySlug.toLowerCase() == 'standard' ? 'Included' : '';
  }

  void _buildSlots(List<dynamic> slotsList) {
    _dates = [];
    _slotsByDate = {};
    _selectedDate = null;
    _selectedTime = null;
    final seenSlotKeys = <String>{};

    final sortableSlots = slotsList.whereType<Map>().toList()
      ..sort((left, right) {
        final leftTime =
            _slotDateTime(left, 'start')?.millisecondsSinceEpoch ?? 0;
        final rightTime =
            _slotDateTime(right, 'start')?.millisecondsSinceEpoch ?? 0;
        return leftTime.compareTo(rightTime);
      });
    for (final slot in sortableSlots) {
      final dt = _slotDateTime(slot, 'start');
      if (dt == null) continue;
      final dateKey = _formatDate(dt);
      final endDt = _slotDateTime(slot, 'end');
      if (endDt == null) continue;
      final timeLabel = _formatArrivalWindow(dt, endDt);
      final slotKey = '$dateKey|$timeLabel';
      if (!seenSlotKeys.add(slotKey)) continue;
      _dates.add(dateKey);
      _slotsByDate.putIfAbsent(dateKey, () => []);
      if (_slotsByDate[dateKey]!.length >= 4) continue;
      _slotsByDate[dateKey]!.add({
        'label': timeLabel,
        'slot': Map<String, dynamic>.from(slot),
      });
    }

    _dates = _dates.toSet().toList();
    if (_dates.isNotEmpty) {
      _selectedDate = _dates.first;
      _selectedTime = null;
    }
  }

  DateTime? _slotDateTime(Map slot, String boundary) {
    final raw = _string(
      boundary == 'start'
          ? slot['start'] ?? slot['startsAt'] ?? slot['starts_at']
          : slot['end'] ?? slot['endsAt'] ?? slot['ends_at'],
    );
    if (raw == null) return null;

    // The availability API returns ISO values in the property's timezone.
    // Keep their wall-clock time, as the website does, instead of converting
    // them to the device timezone.
    final wallClock = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})',
    ).firstMatch(raw);
    if (wallClock != null) {
      return DateTime(
        int.parse(wallClock.group(1)!),
        int.parse(wallClock.group(2)!),
        int.parse(wallClock.group(3)!),
        int.parse(wallClock.group(4)!),
        int.parse(wallClock.group(5)!),
      );
    }

    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;

    final dateRaw = _string(slot['date'] ?? slot['day'] ?? slot['dateKey']);
    if (dateRaw == null) return null;
    final date = DateTime.tryParse(dateRaw);
    if (date == null) return null;
    final time = raw.contains('T') ? raw.split('T').last.trim() : raw;
    final match =
        RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([AaPp][Mm])?$').firstMatch(time);
    if (match == null) return null;

    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final period = match.group(3)?.toLowerCase();
    if (period == 'pm' && hour < 12) hour += 12;
    if (period == 'am' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return DateTime(date.year, date.month, date.day, hour, minute);
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

  void _editFromReview(int index) {
    _returnToReviewAfterEdit = true;
    _goToPage(index);
  }

  void _goToNext() {
    if (_returnToReviewAfterEdit && !_isLastPage) {
      _returnToReviewAfterEdit = false;
      _goToPage(_pages.length - 1);
      return;
    }
    if (_pageIndex < _pages.length - 1) {
      _goToPage(_pageIndex + 1);
    }
  }

  void _goBack() {
    if (_isSubmitting) {
      AppNotification.showInfo(
        context,
        'Please wait while your booking is being confirmed.',
      );
      return;
    }
    if (_returnToReviewAfterEdit) {
      _returnToReviewAfterEdit = false;
      _goToPage(_pages.length - 1);
      return;
    }
    if (_pageIndex > 0) {
      _goToPage(_pageIndex - 1);
    } else {
      Navigator.pop(context);
    }
  }

  void _closeFlow() {
    if (_isSubmitting) {
      AppNotification.showInfo(
        context,
        'Please wait while your booking is being confirmed.',
      );
      return;
    }
    setState(() => _exitRequested = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _submitBooking() async {
    if (_isSubmitting) return;
    if (!_stepIsAnswered(_BookingPage.review)) {
      AppNotification.showInfo(
          context, 'Choose a response time and arrival window first.');
      return;
    }
    if (!AuthService.instance.isAuthenticated) {
      AppNotification.showInfo(
        context,
        'Please log in from the contractor profile to start a booking.',
      );
      setState(() => _exitRequested = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.maybePop(context);
      });
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final contractorId = _contractorId ??
          _string(widget.pro['contractorId']) ??
          _string(widget.pro['contractor_id']);
      if (contractorId == null || contractorId.isEmpty) {
        throw Exception(
            'This contractor is missing booking details right now.');
      }
      final service = _selectedService;
      final selectedPricing = _selectedPricingChoice;

      String? startsAt;
      String? endsAt;
      if (_picksOwnTime &&
          _selectedDate != null &&
          _slotsByDate.containsKey(_selectedDate)) {
        final slotsForDate = _slotsByDate[_selectedDate];
        if (slotsForDate != null && slotsForDate.isNotEmpty) {
          final chosen = slotsForDate.firstWhere(
            (s) => s['label'] == _selectedTime,
          );
          final slot = chosen['slot'] as Map<String, dynamic>?;
          startsAt = _string(slot?['start']);
          endsAt = _string(slot?['end']);
        }
      }
      if (!_picksOwnTime) {
        final range = _availabilityDateRange();
        final live = await HomeownerService.instance.getContractorAvailability(
            contractorId: contractorId,
            serviceId: service.serviceId,
            urgency: _selectedUrgency.urgencySlug,
            fromDate: range.$1,
            toDate: range.$2,
            forceRefresh: true);
        final slots = BookingTiming.eligible(
            live['slots'] as List? ?? [], _selectedUrgency.urgencySlug);
        if (slots.isEmpty)
          throw Exception(
              'This pro has no availability within the response deadline. Choose another response time or pro.');
        startsAt = BookingTiming.start(slots.first)!.toIso8601String();
        endsAt = BookingTiming.end(slots.first)!.toIso8601String();
      }
      if ((startsAt == null || endsAt == null) &&
          selectedPricing.workOrderType != 'quote_request') {
        throw Exception('Select an available calendar slot before booking.');
      }

      final address = _selectedAddressObj;
      final street = _string(address?['street']);
      final city = _string(address?['city']);
      final state = _string(address?['state']);
      final zip = _string(address?['zip']);
      if (street == null || city == null || state == null || zip == null) {
        throw Exception('Select a saved property address before booking.');
      }

      if (_selectedPhotos.isNotEmpty) {
        _bookingIntakeToken ??= await IntakeService.instance.newSessionToken();
        for (final photo in _selectedPhotos) {
          if (_uploadedBookingPhotos.containsKey(photo.path)) continue;
          final ref = await IntakeService.instance
              .uploadPhoto(file: photo, sessionToken: _bookingIntakeToken);
          _bookingIntakeToken = await IntakeService.instance.getSessionToken();
          _uploadedBookingPhotos[photo.path] = ref;
        }
        final intakeResult = await IntakeService.instance.assist(
            text: _issueController.text.trim().isEmpty
                ? service.title
                : _issueController.text.trim(),
            zip: zip,
            sessionToken: _bookingIntakeToken,
            photoRefs: _selectedPhotos
                .map((photo) => _uploadedBookingPhotos[photo.path]!)
                .toList());
        _bookingIntakeToken =
            intakeResult['sessionToken']?.toString() ?? _bookingIntakeToken;
      } else {
        _bookingIntakeToken = null;
        _uploadedBookingPhotos.clear();
      }
      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': service.title,
        'service_description': _issueController.text.trim(),
        'address_id': address?['id'],
        'address_street': street,
        'address_city': city,
        'address_state': state,
        'address_zip': zip,
        'work_order_type': selectedPricing.workOrderType,
        'service_details': service.title,
        if (_bookingIntakeToken != null)
          'intake_session_token': _bookingIntakeToken,
        'selected_pricing_label':
            _pricingTypeLabel(selectedPricing.workOrderType),
        'credit_request_id': _creditRequestId,
        if (_accessCodeController.text.trim().isNotEmpty)
          'access_code': _accessCodeController.text.trim(),
        if (selectedPricing.amount != null)
          'upfront_price': selectedPricing.amount,
        if (selectedPricing.workOrderType != 'quote_request' &&
            _appliedServiceCredits(selectedPricing.amount) > 0)
          'service_credits_applied':
              _appliedServiceCredits(selectedPricing.amount),
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
        transactionId: _bookingTransactionId,
      );

      if (!mounted) return;
      final workOrder = _workOrderFromBookingResponse(
        response,
        contractorId: contractorId,
        startsAt: startsAt,
        endsAt: endsAt,
        address: address!,
        service: service,
        pricing: selectedPricing,
      );
      final messagingUserId =
          StreamService.instance.resolveMessagingUserId(_mergedPro) ??
              StreamService.instance
                  .resolveMessagingUserId(_contractorProfileResponse) ??
              StreamService.instance.resolveMessagingUserId(workOrder);
      Navigator.of(context).pushReplacement<void, Object?>(
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            woNumber: workOrder['woNumber']?.toString(),
            scheduledStart: workOrder['scheduledStart']?.toString() ?? startsAt,
            scheduledEnd: workOrder['scheduledEnd']?.toString() ?? endsAt,
            contractorName: _proName,
            trade: _proTrade,
            service: service.title,
            address: [
              _string(address['street']),
              _string(address['city']),
              [_string(address['state']), _string(address['zip'])]
                  .whereType<String>()
                  .join(' '),
            ].whereType<String>().where((p) => p.isNotEmpty).join(', '),
            price: _workOrderPriceText(workOrder, selectedPricing),
            contractorId: messagingUserId,
            workOrder: workOrder,
          ),
        ),
      );
      return;
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              title: Row(
                children: [
                  const Icon(Icons.shield_outlined,
                      color: AppTheme.navy, size: 24),
                  const SizedBox(width: TwSpace.s8),
                  Expanded(child: Text('Verify your email', style: TwType.h3())),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We sent a 6-digit code to ${AuthService.instance.userEmail ?? 'your email'}. Enter it below to secure your account and confirm booking.',
                    style: TwType.bodySm(),
                  ),
                  const SizedBox(height: TwSpace.s16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: TwType.title().copyWith(
                      fontSize: 18,
                      letterSpacing: 8,
                    ),
                    textAlign: TextAlign.center,
                    decoration: TwInputs.decoration(
                      hint: '000000',
                      counterText: '',
                      errorText: localError,
                    ),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed:
                      verifying ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length != 6) {
                            setDlgState(() =>
                                localError = 'Please enter a 6-digit code');
                            return;
                          }
                          setDlgState(() {
                            verifying = true;
                            localError = null;
                          });
                          try {
                            await HomeownerService.instance
                                .confirmVerification(code);
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);
                            if (mounted) _submitBooking();
                          } catch (err) {
                            setDlgState(() {
                              verifying = false;
                              localError =
                                  err.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange,
                    foregroundColor: AppTheme.onOrange,
                    minimumSize: const Size(120, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                    ),
                  ),
                  child: verifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.onOrange,
                          ),
                        )
                      : const Text('Verify & Book'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _UrgencyOption get _selectedUrgency => _urgencyOptions[
      _selectedUrgencyIndex.clamp(0, _urgencyOptions.length - 1)];

  _PricingChoice get _selectedPricingChoice => _pricingChoices[
      _selectedPricingIndex.clamp(0, _pricingChoices.length - 1)];

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAuthenticated) {
      return const Scaffold(
        backgroundColor: AppTheme.pageBackground,
        body: SizedBox.shrink(),
      );
    }
    final media = MediaQuery.of(context);
    final strip = media.padding.top + 36;
    final minStrip = media.size.height * 0.08;
    final gutter = TwLayout.gutter(context);
    return PopScope(
      canPop: _exitRequested || (!_isSubmitting && _pageIndex == 0),
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            // The dimmed strip above the sheet. Tapping it closes the flow.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeFlow,
              child: SizedBox(
                width: double.infinity,
                height: strip > minStrip ? strip : minStrip,
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: TwLayout.maxContent),
                  child: SizedBox.expand(
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                        boxShadow: AppTheme.floatShadow,
                      ),
                      child: Column(
                        children: [
                          _buildSheetHeader(),
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
                                  padding:
                                      EdgeInsets.fromLTRB(gutter, 0, gutter, 24),
                                  child: _buildStepFor(_pages[index]),
                                );
                              },
                            ),
                          ),
                          _buildSheetFooter(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sheet header (C01–C05): grabber, "Book Pro: {pro}" with "Step n of N",
  /// and one bar segment per step — done and current segments are blue.
  Widget _buildSheetHeader() {
    final total = _pages.length;
    final pro = _proName.isEmpty ? 'this pro' : _proName;
    final gutter = TwLayout.gutter(context);
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Book Pro: $pro',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.h3(),
                ),
              ),
              const SizedBox(width: TwSpace.s12),
              Text(
                'Step $_currentStepNumber of $total',
                style: TwType.label(color: AppTheme.blue),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'Booking progress, step $_currentStepNumber of $total',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i < _currentStepNumber
                            ? AppTheme.blue
                            : AppTheme.cardBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Back (secondary) + Continue (primary). Step 1 has Continue only.
  Widget _buildSheetFooter() {
    final label = _isLastPage
        ? 'Confirm booking'
        : (_returnToReviewAfterEdit ? 'Save changes' : 'Continue');
    final canContinue = !_isSubmitting && _stepIsAnswered(_pages[_pageIndex]);
    final gutter = TwLayout.gutter(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
        boxShadow: AppTheme.floatShadow,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 14, gutter, 14),
          child: Row(
            children: [
              if (_pageIndex > 0) ...[
                SizedBox(
                  width: 104,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _goBack,
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: TwSpace.s12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canContinue
                        ? () {
                            if (_isLastPage) {
                              _submitBooking();
                            } else {
                              _goToNext();
                            }
                          }
                        : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.onOrange,
                            ),
                          )
                        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadServiceCredits() async {
    try {
      final response = await HomeownerService.instance.fetchRewards();
      final rawBalance = _findBackendValue(response, const [
        'balance',
        'rewardsBalance',
        'serviceCredits',
        'service_credits',
        'availableBalance',
        'available_balance',
      ]);
      final balance = rawBalance is num
          ? rawBalance.toDouble()
          : double.tryParse(
              (rawBalance?.toString() ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
            );
      if (mounted && balance != null && balance >= 0) {
        setState(() => _availableServiceCredits = balance);
      }
    } catch (_) {
      // The confirmation remains bookable when credits cannot be retrieved.
    }
  }

  dynamic _findBackendValue(dynamic value, List<String> keys) {
    if (value is! Map) return null;
    for (final key in keys) {
      final item = value[key];
      if (item != null) return item;
    }
    for (final item in value.values) {
      if (item is Map) {
        final found = _findBackendValue(item, keys);
        if (found != null) return found;
      }
    }
    return null;
  }

  Widget _bookingStepHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: TwSpace.s12),
        Text(
          title,
          style: TwType.h1Sm(),
        ),
        const SizedBox(height: TwSpace.s8),
        Text(subtitle, style: TwType.bodySm(color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildStepFor(_BookingPage page) {
    switch (page) {
      case _BookingPage.service:
        return _buildServiceStep();
      case _BookingPage.details:
        return _buildDetailsStep();
      case _BookingPage.urgency:
        return _buildUrgencyStep();
      case _BookingPage.schedule:
        return _buildScheduleStep();
      case _BookingPage.review:
        return _buildReviewAndConfirm();
    }
  }

  Widget _buildServiceStep() {
    final options = _serviceOptions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bookingStepHeader(
            title: 'Confirm your service',
            subtitle: 'Based on your search. You can change it below.',
          ),
          const SizedBox(height: TwSpace.s20),
          if (_profileLoadError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: TwSpace.s12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.amberTint,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Text(
                "Couldn't load this pro's full service list: $_profileLoadError",
                style: TwType.meta(color: AppTheme.ink),
              ),
            ),
          if (!_hasBookableService)
            _bookingStepEmptyService(1)
          else
            ...List.generate(options.length, (index) {
              final service = options[index];
              return _bookingStepServiceTile(
                service: service,
                selected: index == _selectedServiceIndex,
                onTap: () => _selectBookingService(index, service),
              );
            }),
          if (_hasBookableService &&
              options.any((option) => _serviceType(option) == 'nte'))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'With a cap, the final price may be lower — never higher.',
                style: TwType.caption(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bookingStepEmptyService(double scale) {
    return SizedBox(
      width: double.infinity,
      child: TwCard(
        child: Text(
          'No bookable service was returned by the backend for this contractor.',
          style: TwType.bodySm(color: AppTheme.ink),
        ),
      ),
    );
  }

  void _selectBookingService(int index, _ServiceOption service) {
    setState(() {
      _selectedServiceIndex = index;
      _selectedPricingIndex = 0;
      _urgencyAvailabilityDetails.clear();
      _urgencyAvailabilityPrices.clear();
      _urgencyAvailabilityStates.clear();
    });
    _refreshAvailability();
    _hydrateUrgencySummaries();
  }

  /// "$129.00", "$89.00 diagnostic" (the word smaller, C01) or "Free visit".
  Widget? _servicePriceWidget(_ServiceOption service) {
    final text = _servicePriceText(service);
    if (text.isEmpty) return null;
    final amountStyle =
        TwType.title(color: AppTheme.navy).copyWith(fontWeight: FontWeight.w700);
    if (_serviceType(service) == 'nte' && text.endsWith(' diagnostic')) {
      return Text.rich(
        TextSpan(
          text: text.substring(0, text.length - ' diagnostic'.length),
          style: amountStyle,
          children: [
            TextSpan(
              text: ' diagnostic',
              style: TwType.caption(color: AppTheme.body)
                  .copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        textAlign: TextAlign.right,
      );
    }
    return Text(text, textAlign: TextAlign.right, style: amountStyle);
  }

  Widget _bookingStepServiceTile({
    required _ServiceOption service,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TwSelectTile(
        selected: selected,
        onTap: onTap,
        title: service.title,
        subtitle: _serviceTypeLine(service),
        trailing: _servicePriceWidget(service),
      ),
    );
  }

  Widget _buildDetailsStep() {
    final backendChips = _detailChipsForTrade(_proTrade);
    final chips = backendChips;
    final searchPhotos = _searchPhotoUrls;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bookingStepHeader(
            title: 'Anything else we should know?',
            subtitle:
                'Optional — add details or photos to help ${_proName.isNotEmpty ? _proName : 'the pro'} prepare. You can also skip this step.',
          ),
          const SizedBox(height: TwSpace.s20),
          const TwFieldLabel('Details'),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 120),
            child: TextField(
              controller: _issueController,
              minLines: 4,
              maxLines: 8,
              style: TwType.body(color: AppTheme.ink),
              decoration: TwInputs.decoration(
                hint: 'AC isn\'t cooling properly',
              ),
            ),
          ),
          const SizedBox(height: TwSpace.s20),
          if (searchPhotos.isNotEmpty) ...[
            const TwFieldLabel('Photos from your search'),
            const SizedBox(height: 2),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: searchPhotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Image.network(
                      searchPhotos[index],
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: AppTheme.subtle,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: TwSpace.s16),
          ],
          InkWell(
            onTap: _pickPhotos,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: _DashedOutline(
              color: AppTheme.blue,
              borderRadius: AppTheme.radius,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_a_photo_outlined,
                      color: AppTheme.blue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Add photos of the issue',
                        style: TwType.link(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPhotos.map((photo) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radius),
                      child: Image.file(
                        File(photo.path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -14,
                      top: -14,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () =>
                            setState(() => _selectedPhotos.remove(photo)),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                color: AppTheme.navy,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: TwSpace.s20),
            const TwFieldLabel('Common issues'),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((label) {
                final selected = _selectedDetailChips.contains(label);
                return TwPill(
                  label: label,
                  selected: selected,
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedDetailChips.remove(label);
                      } else {
                        _selectedDetailChips.add(label);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUrgencyStep() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bookingStepHeader(
            title: 'When do you need this?',
            subtitle:
                'These options and fees are set by $_proName. Other pros differ.',
          ),
          if (_selectedUrgencyIndex >= 0 && !_picksOwnTime)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                    '${_deadlineText()} · $_proName’s commitment for this job',
                    style: TwType.meta())),
          const SizedBox(height: TwSpace.s20),
          ..._urgencyOptions.asMap().entries.map((entry) {
            final index = entry.key;
            final tier = entry.value;
            final selected = index == _selectedUrgencyIndex;
            final priceText = _urgencyCardPriceText(tier);
            final isIncluded = priceText.toLowerCase() == 'included';
            return Opacity(
              opacity: tier.available ? 1 : 0.42,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TwSelectTile(
                  selected: selected,
                  onTap: () {
                    if (!tier.available) return;
                    setState(() {
                      _selectedUrgencyIndex = index;
                      _selectedTime = null;
                      if (_pageIndex >= _pages.length)
                        _pageIndex = _pages.length - 1;
                    });
                    _refreshAvailability();
                  },
                  title: tier.label,
                  subtitle: _responseWindow(tier.urgencySlug),
                  trailing: priceText.isEmpty
                      ? null
                      : Text(
                          priceText,
                          textAlign: TextAlign.right,
                          style: isIncluded
                              ? TwType.bodySm(color: AppTheme.green)
                                  .copyWith(fontWeight: FontWeight.w600)
                              : TwType.title(color: AppTheme.ink)
                                  .copyWith(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            );
          }),
          const SizedBox(height: TwSpace.s4),
          SizedBox(
            width: double.infinity,
            child: TwFactPanel(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppTheme.navy, size: 20),
                    const SizedBox(width: TwSpace.s12),
                    Expanded(
                        child: Text(
                            'The Urgent or Emergency fee goes to $_proName. TradeWorks adds no markup and no platform fee.',
                            style: TwType.meta(color: AppTheme.body))),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleStep() {
    final slots = _selectedDate == null
        ? const <Map<String, dynamic>>[]
        : _slotsByDate[_selectedDate] ?? const <Map<String, dynamic>>[];
    final windowColumns = TwLayout.stackRows(context) ? 1 : 2;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _bookingStepHeader(
          title: 'Pick your arrival window',
          subtitle: 'Choose one of $_proName’s available arrival windows.',
        ),
        const SizedBox(height: TwSpace.s20),
        if (_isLoadingSlots)
          const LoadingSkeleton(
              layout: SkeletonLayout.form, label: 'Loading arrival windows')
        else if (_slotsError != null)
          Text(_slotsError!, style: TwType.bodySm(color: AppTheme.error))
        else if (_selectedAvailability?['paused'] == true)
          Text(
            'This pro has paused new bookings. Try another contractor.',
            style: TwType.bodySm(color: AppTheme.textSecondary),
          )
        else if (_selectedUrgency.urgencySlug.toLowerCase() == 'emergency' &&
            _selectedAvailability?['emergencyEligible'] == false)
          Text(
            'This pro can’t take an emergency booking. Pick another response time or another pro.',
            style: TwType.bodySm(color: AppTheme.textSecondary),
          )
        else if (_dates.isEmpty)
          Text(
            'No availability in this window — try another pro or a different response time.',
            style: TwType.bodySm(color: AppTheme.textSecondary),
          )
        else ...[
          const TwFieldLabel('Day'),
          const SizedBox(height: TwSpace.s4),
          SizedBox(
            height: TwDayTile.heightOf(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final date = _dates[index];
                final selected = date == _selectedDate;
                final info = _dateTileInfo(date);
                return TwDayTile(
                  top: info.$1,
                  bottom: info.$2,
                  selected: selected,
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _selectedTime = null;
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          TwFieldLabel('Arrival window · ${_fullDateLabel(_selectedDate)}'),
          const SizedBox(height: TwSpace.s4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: windowColumns,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 48),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final label = slot['label']?.toString() ?? '';
              final selected = label == _selectedTime;
              return TwPill(
                label: label,
                selected: selected,
                square: true,
                height: 48,
                onTap: () => setState(() => _selectedTime = label),
              );
            },
          ),
          const SizedBox(height: TwSpace.s12),
          Text(
            'The window you pick is booked on $_proName’s calendar.',
            style: TwType.caption(),
          ),
        ],
      ]),
    );
  }

  /// "Wed, Oct 14" for a date key, even when its tile says "Tomorrow".
  String _fullDateLabel(String? date) {
    if (date == null) return '';
    final slots = _slotsByDate[date] ?? const <Map<String, dynamic>>[];
    final slot = slots.isEmpty ? null : slots.first['slot'];
    final parsed = slot is Map ? _slotDateTime(slot, 'start') : null;
    return parsed == null ? date : DateFormat('EEE, MMM d').format(parsed);
  }

  (String, String) _dateTileInfo(String date) {
    final slots = _slotsByDate[date] ?? const <Map<String, dynamic>>[];
    final slot = slots.isEmpty ? null : slots.first['slot'];
    final parsed = slot is Map ? _slotDateTime(slot, 'start') : null;
    if (parsed == null) return (date, '');
    const months = [
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
    // Top line: "Today", "Tomorrow" or the weekday — never the date again.
    return (date.split(',').first, '${months[parsed.month - 1]} ${parsed.day}');
  }

  /// Prefills the gate / access code from the Home profile's access notes
  /// for the selected address, when the homeowner saved any (Oct 1, G-53).
  Future<void> _prefillAccessCode() async {
    final addressId = _string(_selectedAddressObj?['id']);
    if (addressId == null || _accessCodeController.text.trim().isNotEmpty) {
      return;
    }
    try {
      final data = await HomeownerService.instance.fetchHomeProfiles();
      final homes =
          (data['homeProfiles'] as List? ?? const []).whereType<Map>();
      for (final home in homes) {
        if ('${home['addressId'] ?? home['address_id']}' != addressId) continue;
        final notes = home['accessNotes'];
        final text = notes is Map ? _string(notes['text']) : null;
        if (text != null &&
            mounted &&
            _accessCodeController.text.trim().isEmpty) {
          setState(() => _accessCodeController.text = text);
        }
        return;
      }
    } catch (_) {
      // Optional field — the homeowner can type it.
    }
  }

  TextStyle get _cardTitleStyle => TwType.h3();

  Widget _changeLink(VoidCallback onTap) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.only(left: 12),
        ),
        child: Text('Change', style: TwType.link()),
      );

  Widget _reviewRow(
    String label,
    String value, {
    VoidCallback? onChange,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TwType.caption()),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: TwType.title()),
              ],
            ),
          ),
          if (onChange != null) _changeLink(onChange),
        ],
      ),
    );
  }

  /// "+$35.00" for Urgent / Emergency, shown in the Response time row.
  String _selectedLevelFeeLabel() {
    if (_selectedUrgencyIndex < 0) return '';
    if (_selectedUrgency.urgencySlug.toLowerCase() == 'standard') return '';
    final fee = _selectedUrgency.feeLabel.trim();
    if (fee.isEmpty || fee.toLowerCase() == 'included') return '';
    return fee.startsWith('+') ? fee : '+$fee';
  }

  /// (label, value) of the price panel, by work-order type.
  (String, String) _reviewPrice(_PricingChoice pricing) {
    final amount = pricing.amount;
    switch (pricing.workOrderType) {
      case 'quote_request':
        return ('Estimate to follow', 'Free visit');
      case 'nte':
        return (
          'Diagnostic · you approve the cap next',
          amount == null ? _priceText(pricing) : formatUsd(amount),
        );
      default:
        return (
          'Upfront price',
          amount == null ? _priceText(pricing) : formatUsd(amount),
        );
    }
  }

  /// Review & confirm (C05; Oct 1, G-53).
  Widget _buildReviewAndConfirm() {
    final pricing = _selectedPricingChoice;
    final detail = _issueController.text.trim();
    final address = _selectedAddressObj;
    final stateZip = [
      _string(address?['state']),
      _string(address?['zip']),
    ].whereType<String>().join(' ');
    final addressText = address == null
        ? ''
        : [
            _string(address['street']),
            _string(address['city']),
            stateZip.isEmpty ? null : stateZip,
          ].whereType<String>().join(', ');
    final when = !_picksOwnTime
        ? _deadlineText()
        : _selectedDate != null && _selectedTime != null
            ? '${_fullDateLabel(_selectedDate)} · $_selectedTime'
            : '';
    final levelFee = _selectedLevelFeeLabel();
    final price = _reviewPrice(pricing);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bookingStepHeader(
            title: 'Review & confirm',
            subtitle: 'Confirm the details below to book.',
          ),
          const SizedBox(height: TwSpace.s20),
          _reviewPanel(
            Column(children: [
              _reviewRow('Pro', _proName, onChange: _changeContractor),
              _reviewRow('Service', _selectedService.title,
                  onChange: () => _editFromReview(0)),
              _reviewRow('When', when,
                  onChange: () => _editFromReview(_picksOwnTime ? 3 : 2)),
              _reviewRow(
                'Response time',
                levelFee.isEmpty
                    ? _selectedUrgency.label
                    : '${_selectedUrgency.label} · $levelFee',
                onChange: () => _editFromReview(2),
                last: true,
              ),
            ]),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          const SizedBox(height: TwSpace.s12),
          _reviewPanel(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Your details', style: _cardTitleStyle)),
                _changeLink(() => _editFromReview(1)),
              ]),
              if (detail.isEmpty && _selectedPhotos.isEmpty)
                Text('No details or photos added', style: TwType.meta()),
              if (detail.isNotEmpty)
                Text(detail, style: TwType.bodySm(color: AppTheme.ink)),
              if (_selectedPhotos.isNotEmpty) ...[
                const SizedBox(height: TwSpace.s8),
                Wrap(
                  spacing: 8,
                  children: _selectedPhotos
                      .take(3)
                      .map((photo) => ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(photo.path),
                              width: 44, height: 44, fit: BoxFit.cover)))
                      .toList(),
                ),
              ],
            ],
          )),
          const SizedBox(height: TwSpace.s12),
          _reviewPanel(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Service address', style: _cardTitleStyle),
                        const SizedBox(height: TwSpace.s4),
                        Text(
                          addressText.isEmpty
                              ? 'No saved address'
                              : addressText,
                          style: TwType.body(color: AppTheme.ink),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit address',
                    onPressed: _openManageAddresses,
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_outlined,
                        color: AppTheme.navy, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const TwFieldLabel('Gate / access code (optional)'),
              TextField(
                controller: _accessCodeController,
                minLines: 1,
                maxLines: 3,
                maxLength: 500,
                textInputAction: TextInputAction.done,
                style: TwType.body(color: AppTheme.ink),
                decoration: TwInputs.decoration(counterText: ''),
              ),
              const SizedBox(height: TwSpace.s8),
              Text(
                'Only your pro sees this, on the job.',
                style: TwType.caption(),
              ),
            ],
          )),
          const SizedBox(height: TwSpace.s12),
          SizedBox(
            width: double.infinity,
            child: TwFactPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TwSpace.s12,
                    runSpacing: TwSpace.s4,
                    children: [
                      Text(
                        price.$1,
                        style: TwType.bodySm(color: AppTheme.navy)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        price.$2,
                        style: TwType.h1Mid(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TradeWorks adds no markup and takes no fee — we only fund the credits you apply.',
                    style: TwType.meta(color: AppTheme.body),
                  ),
                ],
              ),
            ),
          ),
          if (pricing.workOrderType != 'quote_request' &&
              _availableServiceCredits != null &&
              pricing.amount != null) ...[
            const SizedBox(height: TwSpace.s12),
            _creditsCard(pricing.amount!),
          ],
        ],
      ),
    );
  }

  /// Apply credits (C05): balance in purple, the settled instruction, the
  /// amount, credits applied and what the homeowner pays the pro.
  Widget _creditsCard(int price) {
    final balance = _availableServiceCredits ?? 0;
    final applied = _appliedServiceCredits(price);
    final amountDue = price - applied;
    return _reviewPanel(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Apply credits', style: _cardTitleStyle),
                const SizedBox(height: 2),
                Text(
                  'Available: ${formatUsd(balance)}',
                  style: TwType.label(color: AppTheme.purple),
                ),
              ],
            ),
          ),
          Switch(
            value: _useServiceCredits,
            onChanged: balance <= 0
                ? null
                : (value) => setState(() {
                      _useServiceCredits = value;
                      if (value &&
                          _creditAmountController.text.trim().isEmpty) {
                        _creditAmountController.text = [
                          balance,
                          price.toDouble()
                        ].reduce((a, b) => a < b ? a : b).toStringAsFixed(2);
                      }
                    }),
          ),
        ]),
        const SizedBox(height: TwSpace.s8),
        Text(
          'Tell us how much to apply when you book.',
          style: TwType.meta(color: AppTheme.body),
        ),
        if (_useServiceCredits) ...[
          const SizedBox(height: TwSpace.s12),
          const TwFieldLabel('Amount to apply'),
          TextField(
            controller: _creditAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: TwType.body(color: AppTheme.ink),
            decoration:
                TwInputs.decoration(hint: '0.00').copyWith(prefixText: '\$ '),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Text(
                'Credits applied',
                style: TwType.bodySm(color: AppTheme.body),
              ),
            ),
            Text(
              '−${formatUsd(applied)}',
              style: TwType.bodySm(color: AppTheme.purple)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ]),
          const Divider(height: 24, color: AppTheme.cardBorder),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('You pay', style: TwType.title()),
              ),
              Text(
                formatUsd(amountDue),
                style: TwType.h1Mid(context),
              ),
            ],
          ),
          const SizedBox(height: TwSpace.s4),
          Text(
            amountDue <= 0
                ? 'Fully covered by your credits.'
                : 'The remaining balance is paid directly to $_proName.',
            style: TwType.meta(),
          ),
        ],
      ],
    ));
  }

  Widget _reviewPanel(Widget child,
          {EdgeInsets padding = const EdgeInsets.all(16)}) =>
      SizedBox(
        width: double.infinity,
        child: TwCard(padding: padding, child: child),
      );

  double _appliedServiceCredits(int? price) {
    if (!_useServiceCredits ||
        price == null ||
        _availableServiceCredits == null) {
      return 0;
    }
    final entered = double.tryParse(_creditAmountController.text.trim());
    if (entered == null || !entered.isFinite) return 0;
    final requested = double.parse(entered.toStringAsFixed(2));
    return requested.clamp(
        0,
        [price.toDouble(), _availableServiceCredits!, 10000.0]
            .reduce((a, b) => a < b ? a : b));
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
    const months = [
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
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _formatArrivalWindow(DateTime start, DateTime end) =>
      formatWindow(start, end);

  List<String> _detailChipsForTrade(String trade) {
    final raw = _readList(
          _contractorProfile?['detail_chips'] ??
              _contractorProfile?['detailChips'] ??
              _contractorProfile?['issue_tags'] ??
              _contractorProfile?['issueTags'] ??
              _selectedService.detailChips,
        ) ??
        const [];
    return raw
        .map((item) => _string(item))
        .whereType<String>()
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<dynamic> _backendItemsFor(List<String> keys) {
    final aliases = keys.map(_normalizedKey).toSet();
    final items = <dynamic>[];

    void visit(dynamic value) {
      if (value is List) {
        for (final item in value) {
          visit(item);
        }
        return;
      }
      if (value is! Map) return;

      for (final entry in value.entries) {
        final item = entry.value;
        if (aliases.contains(_normalizedKey(entry.key.toString()))) {
          items.addAll(_collectionItems(item));
        }
        visit(item);
      }
    }

    visit(widget.pro);
    visit(_contractorProfileResponse);
    visit(_contractorProfile);
    return items;
  }

  List<dynamic> _collectionItems(dynamic value) {
    if (value is List) return value;
    if (value is! Map) return const [];

    final direct = Map<String, dynamic>.from(value);
    const recordKeys = <String>{
      'name',
      'title',
      'label',
      'service',
      'service_name',
      'serviceName',
      'category',
      'price',
      'amount',
      'fromPrice',
      'from_price',
      'base_price',
      'basePrice',
      'rate_amount',
      'rateAmount',
      'min_charge',
      'minCharge',
      'fee',
      'feeLabel',
      'fee_label',
      'surcharge',
      'additional_fee',
      'additionalFee',
      'urgencySlug',
      'urgency_slug',
      'urgency',
      'priority',
      'code',
      'slug',
      'tier',
      'responseTime',
      'response_time',
      'responseWindow',
      'response_window',
      'nextAvailable',
      'next_available',
      'startsAt',
      'starts_at',
      'start',
    };
    if (direct.keys.any(recordKeys.contains)) return [direct];

    for (final wrapperKey in const [
      'items',
      'results',
      'data',
      'records',
      'options',
      'values',
      'services',
      'tiers',
      'pricing',
      'slots',
      'windows',
      'availability',
      'arrivalWindows',
      'arrival_windows',
      'timeWindows',
      'time_windows',
    ]) {
      final wrapped = direct[wrapperKey];
      if (wrapped != null) {
        final nested = _collectionItems(wrapped);
        if (nested.isNotEmpty) return nested;
      }
    }

    return direct.entries.map((entry) {
      final item = entry.value;
      if (item is Map) {
        final mapped = Map<String, dynamic>.from(item);
        mapped.putIfAbsent('label', () => entry.key.toString());
        mapped.putIfAbsent('name', () => entry.key.toString());
        return mapped;
      }
      return <String, dynamic>{
        'label': entry.key.toString(),
        'name': entry.key.toString(),
        'detail': item,
        'price': item,
        'value': item,
      };
    }).toList();
  }

  String _normalizedKey(String value) =>
      value.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();

  Map<String, dynamic> _extractContractorProfile(
      Map<String, dynamic> response) {
    final merged = <String, dynamic>{...response};

    void mergeMap(dynamic source) {
      if (source is Map) {
        merged.addAll(Map<String, dynamic>.from(source));
      }
    }

    for (final key in const [
      'data',
      'profile',
      'contractor',
      'pro',
      'contractorProfile',
      'contractor_profile',
    ]) {
      final source = response[key];
      mergeMap(source);
      if (source is Map) {
        for (final nestedKey in const [
          'profile',
          'contractor',
          'booking',
          'booking_options',
          'bookingOptions',
          'availability',
          'pricing',
        ]) {
          mergeMap(source[nestedKey]);
        }
      }
    }

    for (final key in const [
      'booking',
      'booking_options',
      'bookingOptions',
      'availability',
    ]) {
      mergeMap(merged[key]);
    }
    return merged;
  }

  String _priceText(_PricingChoice pricing) {
    if (pricing.priceHeadline.trim().isNotEmpty) return pricing.priceHeadline;
    if (pricing.priceText.trim().isNotEmpty) return pricing.priceText;
    if (pricing.amount != null) return formatUsd(pricing.amount!);
    return 'Price set by ${_proName.isEmpty ? 'the pro' : _proName}';
  }

  String _workOrderPriceText(
    Map<String, dynamic> workOrder,
    _PricingChoice pricing,
  ) {
    final amount = _findPriceAmount(workOrder);
    return amount == null ? _priceText(pricing) : '\$$amount';
  }

  int? _findPriceAmount(dynamic value) {
    if (value is! Map) return null;
    const priceKeys = [
      'upfrontPrice',
      'upfront_price',
      'total',
      'totalAmount',
      'total_amount',
      'price',
      'amount',
      'amountDue',
      'amount_due',
      'approvedCap',
      'approved_cap',
    ];
    for (final key in priceKeys) {
      final price = _readInt(value[key]);
      if (price != null) return price;
    }
    for (final child in value.values) {
      if (child is Map) {
        final price = _findPriceAmount(child);
        if (price != null) return price;
      }
    }
    return null;
  }

  Map<String, dynamic> _workOrderFromBookingResponse(
    Map<String, dynamic> response, {
    required String contractorId,
    required String? startsAt,
    required String? endsAt,
    required Map<String, dynamic> address,
    required _ServiceOption service,
    required _PricingChoice pricing,
  }) {
    final workOrder = <String, dynamic>{};
    for (final key in const [
      'data',
      'result',
      'payload',
      'booking',
      'workOrder',
      'work_order',
    ]) {
      final nested = response[key];
      if (nested is Map) {
        final map = Map<String, dynamic>.from(nested);
        workOrder.addAll(map);
        for (final nestedKey in const ['workOrder', 'work_order', 'booking']) {
          final record = map[nestedKey];
          if (record is Map)
            workOrder.addAll(Map<String, dynamic>.from(record));
        }
      }
    }
    final id = workOrder['workOrderId'] ??
        workOrder['work_order_id'] ??
        response['workOrderId'] ??
        response['work_order_id'] ??
        workOrder['id'] ??
        response['id'];
    final amount = _findPriceAmount(workOrder) ??
        _findPriceAmount(response) ??
        pricing.amount;
    return {
      ...response,
      ...workOrder,
      if (id != null) 'workOrderId': id,
      'woNumber': workOrder['woNumber'] ??
          workOrder['workOrderNumber'] ??
          response['woNumber'] ??
          response['workOrderNumber'] ??
          id,
      'status': workOrder['status'] ?? response['status'] ?? 'scheduled',
      'slaArrivalTarget':
          workOrder['slaArrivalTarget'] ?? response['slaArrivalTarget'],
      'priority': _selectedUrgency.urgencySlug,
      'scheduledStart': workOrder['scheduledStart'] ??
          workOrder['scheduled_start'] ??
          workOrder['startsAt'] ??
          workOrder['starts_at'] ??
          response['scheduledStart'] ??
          response['scheduled_start'] ??
          startsAt,
      'scheduledEnd': workOrder['scheduledEnd'] ??
          workOrder['scheduled_end'] ??
          workOrder['endsAt'] ??
          workOrder['ends_at'] ??
          response['scheduledEnd'] ??
          response['scheduled_end'] ??
          endsAt,
      'serviceCategory': workOrder['serviceCategory'] ??
          workOrder['service_category'] ??
          service.title,
      'description': workOrder['description'] ?? _issueController.text.trim(),
      'address': workOrder['address'] ?? address,
      'pro': workOrder['pro'] ??
          {
            'id': contractorId,
            'businessName': _proName,
          },
      if (amount != null) ...{
        'amount': amount,
        'upfrontPrice': amount,
      },
      'work_order_type': workOrder['work_order_type'] ??
          workOrder['workOrderType'] ??
          pricing.workOrderType,
      if (_appliedServiceCredits(pricing.amount) > 0)
        'creditsApplied': workOrder['creditsApplied'] ??
            workOrder['credits_applied'] ??
            _appliedServiceCredits(pricing.amount),
      if (_accessCodeController.text.trim().isNotEmpty)
        'accessCode': _accessCodeController.text.trim(),
    };
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
    if (value is num) return value.round();
    final text = _string(value);
    if (text == null) return null;
    final match = RegExp(r'-?\d+(?:[,.]\d+)*').firstMatch(text);
    if (match == null) return null;
    return num.tryParse(match.group(0)!.replaceAll(',', ''))?.round();
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
    final direct =
        _string(widget.pro['slug']) ?? _string(widget.pro['profileSlug']);
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final businessName = _string(widget.pro['businessName']) ??
        _string(widget.pro['business_name']);
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

/// The homeowner-facing label of a work-order type (decisions §2). Sent as
/// `selected_pricing_label`; never "Request a quote" (Batch 19 F2).
String _pricingTypeLabel(String workOrderType) {
  switch (workOrderType) {
    case 'nte':
      return 'You approve the cap';
    case 'quote_request':
      return 'Free visit';
    default:
      return 'Upfront price';
  }
}

/// Prices are never worded "From $…" (decisions §2, Oct 1), even when a
/// backend label still carries it.
String _withoutFrom(String text) =>
    text.replaceFirst(RegExp(r'^\s*from\s+', caseSensitive: false), '');

class _ServiceOption {
  final String title;
  final String subtitle;
  final int? amount;
  final String priceLabel;
  final String pricingLabel;
  final String pricingDetail;
  final int? durationMinutes;
  final String? serviceId;
  final List<_PricingChoice> pricingChoices;
  final List<String> detailChips;

  const _ServiceOption({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.priceLabel,
    required this.pricingLabel,
    required this.pricingDetail,
    required this.durationMinutes,
    required this.pricingChoices,
    this.serviceId,
    this.detailChips = const [],
  });

  factory _ServiceOption.fromString(String value, {required String trade}) {
    return _ServiceOption(
      title: value,
      subtitle: '',
      amount: null,
      priceLabel: '',
      pricingLabel: '',
      pricingDetail: '',
      durationMinutes: null,
      pricingChoices: const [
        _PricingChoice(
          label: 'Upfront price',
          detail: '',
          amount: null,
          priceText: '',
          priceHeadline: '',
          workOrderType: 'rate_card',
          secondaryText: '',
        ),
      ],
      detailChips: const [],
    );
  }

  factory _ServiceOption.fromMap(Map<String, dynamic> map) {
    final source = <String, dynamic>{};
    for (final key in const [
      'service',
      'service_details',
      'serviceDetails',
      'service_info',
      'serviceInfo',
    ]) {
      final nested = map[key];
      if (nested is Map) source.addAll(Map<String, dynamic>.from(nested));
    }
    source.addAll(map);

    final choices = <_PricingChoice>[];
    final rawChoices = source['pricing_options'] ??
        source['pricingOptions'] ??
        source['pricing_paths'] ??
        source['pricingPaths'] ??
        source['price_options'] ??
        source['priceOptions'] ??
        source['prices'] ??
        source['pricing'];
    final choiceItems = rawChoices is List
        ? rawChoices
        : rawChoices is Map
            ? rawChoices.entries.map((entry) {
                if (entry.value is Map) {
                  final option = Map<String, dynamic>.from(entry.value as Map);
                  option.putIfAbsent('label', () => entry.key.toString());
                  return option;
                }
                return <String, dynamic>{
                  'label': entry.key.toString(),
                  'price': entry.value,
                };
              }).toList()
            : const <dynamic>[];
    for (final choice in choiceItems) {
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

    final price = _parseInt(
      source['fromPrice'] ??
          source['from_price'] ??
          source['startingPrice'] ??
          source['starting_price'] ??
          source['upfrontPrice'] ??
          source['upfront_price'] ??
          source['basePrice'] ??
          source['base_price'] ??
          source['minimumPrice'] ??
          source['minimum_price'] ??
          source['rateAmount'] ??
          source['rate_amount'] ??
          source['minCharge'] ??
          source['min_charge'] ??
          source['diagnosticFee'] ??
          source['diagnostic_fee'] ??
          source['price'] ??
          source['amount'],
    );
    final workOrderType = _string(source['workOrderType']) ??
        _string(source['work_order_type']) ??
        _string(source['type']) ??
        'rate_card';
    final durationMinutes = _parseInt(
      source['duration_minutes'] ??
          source['durationMinutes'] ??
          source['duration'] ??
          source['estimated_duration_minutes'],
    );
    final title = _string(source['name']) ??
        _string(source['title']) ??
        _string(source['serviceName']) ??
        _string(source['service_name']) ??
        _string(source['service']) ??
        _string(source['serviceCategory']) ??
        _string(source['service_category']) ??
        _string(source['category']) ??
        _string(source['label']) ??
        'Service';
    final subtitle = _string(source['description']) ??
        _string(source['serviceDescription']) ??
        _string(source['service_description']) ??
        _string(source['summary']) ??
        _string(source['details']) ??
        '';
    final rawDetailChips = source['detail_chips'] ??
        source['detailChips'] ??
        source['issue_tags'] ??
        source['issueTags'];
    final detailChips = rawDetailChips is List
        ? rawDetailChips
            .map((item) => _string(item))
            .whereType<String>()
            .where((item) => item.isNotEmpty)
            .toList()
        : const <String>[];

    if (choices.isEmpty) {
      final explicitPriceText = _string(source['priceText']) ??
          _string(source['price_label']) ??
          _string(source['priceLabel']) ??
          _string(source['display_price']);
      final priceText = explicitPriceText != null
          ? _withoutFrom(explicitPriceText)
          : (price == null ? '' : formatUsd(price));
      final isFreeVisit = workOrderType == 'quote_request';
      choices.add(
        _PricingChoice(
          label: _pricingTypeLabel(workOrderType),
          detail: '',
          amount: price,
          priceText: isFreeVisit ? 'Free visit' : priceText,
          priceHeadline: isFreeVisit
              ? 'Free visit'
              : workOrderType == 'nte'
                  ? 'You approve the cap'
                  : (price == null ? priceText : formatUsd(price)),
          workOrderType: workOrderType,
          secondaryText: '',
        ),
      );
    }

    return _ServiceOption(
      title: title,
      subtitle: subtitle,
      amount: price,
      priceLabel: choices.first.priceText,
      pricingLabel: _string(source['pricing_label']) ??
          _string(source['pricingLabel']) ??
          choices.first.label,
      pricingDetail: _string(source['pricing_detail']) ??
          _string(source['pricingDetail']) ??
          _string(source['fromUnit']) ??
          _string(source['from_unit']) ??
          _string(source['rateLabel']) ??
          _string(source['rate_label']) ??
          _string(source['rateUnit']) ??
          _string(source['rate_unit']) ??
          choices.first.detail,
      durationMinutes: durationMinutes,
      serviceId: _string(
        source['contractorServiceId'] ??
            source['contractor_service_id'] ??
            source['serviceOptionId'] ??
            source['service_option_id'] ??
            source['serviceId'] ??
            source['service_id'] ??
            source['id'],
      ),
      pricingChoices: choices,
      detailChips: detailChips,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.round();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'-?\d+(?:[,.]\d+)*').firstMatch(text);
    if (match == null) return null;
    return num.tryParse(match.group(0)!.replaceAll(',', ''))?.round();
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null')
      return null;
    return text;
  }
}

class _DashedOutline extends StatelessWidget {
  final Widget child;
  final Color color;
  final double borderRadius;

  const _DashedOutline({
    required this.child,
    required this.color,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedOutlinePainter(
        color: color,
        borderRadius: borderRadius,
      ),
      child: child,
    );
  }
}

class _DashedOutlinePainter extends CustomPainter {
  final Color color;
  final double borderRadius;

  const _DashedOutlinePainter({
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(borderRadius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 6).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedOutlinePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius;
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
    final source = <String, dynamic>{};
    for (final key in const [
      'pricing',
      'rate',
      'price_details',
      'priceDetails'
    ]) {
      final nested = map[key];
      if (nested is Map) source.addAll(Map<String, dynamic>.from(nested));
    }
    source.addAll(map);

    final label = _string(source['label']) ??
        _string(source['name']) ??
        _string(source['title']) ??
        _string(source['pricingLabel']) ??
        _string(source['pricing_label']) ??
        'Option';
    final detail = _string(source['detail']) ??
        _string(source['description']) ??
        _string(source['subtitle']) ??
        _string(source['pricingDetail']) ??
        _string(source['pricing_detail']) ??
        '';
    final amount = _parseInt(
      source['price'] ??
          source['amount'] ??
          source['fromPrice'] ??
          source['from_price'] ??
          source['upfrontPrice'] ??
          source['upfront_price'] ??
          source['basePrice'] ??
          source['base_price'] ??
          source['minimumPrice'] ??
          source['minimum_price'] ??
          source['rateAmount'] ??
          source['rate_amount'] ??
          source['minCharge'] ??
          source['min_charge'] ??
          source['diagnosticFee'] ??
          source['diagnostic_fee'],
    );
    final workOrderType = _string(source['workOrderType']) ??
        _string(source['work_order_type']) ??
        _string(source['type']) ??
        'rate_card';
    final headline = _withoutFrom(_string(source['headline']) ??
        _string(source['priceHeadline']) ??
        _string(source['price_headline']) ??
        (amount != null ? formatUsd(amount) : label));
    final priceText = _withoutFrom(_string(source['priceText']) ??
        _string(source['price_text']) ??
        _string(source['priceLabel']) ??
        _string(source['price_label']) ??
        (amount != null ? formatUsd(amount) : label));
    final secondaryText =
        _string(source['secondaryText']) ?? _string(source['subtitle']) ?? '';
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
    if (text == null || text.isEmpty || text.toLowerCase() == 'null')
      return null;
    return text;
  }

  static int? _parseInt(dynamic value) {
    if (value is num) return value.round();
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'-?\d+(?:[,.]\d+)*').firstMatch(text);
    if (match == null) return null;
    return num.tryParse(match.group(0)!.replaceAll(',', ''))?.round();
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

  _UrgencyOption copyWith({
    String? detail,
    String? feeLabel,
    String? urgencySlug,
    bool? available,
  }) {
    return _UrgencyOption(
      label: label,
      detail: detail ?? this.detail,
      feeLabel: feeLabel ?? this.feeLabel,
      urgencySlug: urgencySlug ?? this.urgencySlug,
      available: available ?? this.available,
    );
  }

  factory _UrgencyOption.fromMap(Map<String, dynamic> map) {
    final label = _string(map['label']) ??
        _string(map['name']) ??
        _string(map['title']) ??
        _string(map['tier']) ??
        _string(map['urgency']) ??
        _string(map['priority']) ??
        _string(map['code']) ??
        _string(map['slug']) ??
        '';
    final rawDetail = _string(map['detail']) ??
        _string(map['description']) ??
        _string(map['responseWindow']) ??
        _string(map['response_window']) ??
        _string(map['responseTime']) ??
        _string(map['response_time']) ??
        _string(map['window']) ??
        _string(map['nextAvailable']) ??
        _string(map['next_available']) ??
        _string(map['startsAt']) ??
        _string(map['starts_at']) ??
        _string(map['start']) ??
        _string(map['value']) ??
        '';
    final rawFee = _moneySource(
      map['feeLabel'] ??
          map['fee_label'] ??
          map['urgencyFee'] ??
          map['urgency_fee'] ??
          map['fee'] ??
          map['feeAmount'] ??
          map['fee_amount'] ??
          map['surcharge'] ??
          map['surchargeAmount'] ??
          map['surcharge_amount'] ??
          map['additional_fee'] ??
          map['additionalFee'] ??
          map['additional_fee_amount'] ??
          map['additionalFeeAmount'],
    );
    final rawPrice = _moneySource(
      map['priceLabel'] ??
          map['price_label'] ??
          map['priceText'] ??
          map['price_text'] ??
          map['displayPrice'] ??
          map['display_price'] ??
          map['fromPrice'] ??
          map['from_price'] ??
          map['totalPrice'] ??
          map['total_price'] ??
          map['price'] ??
          map['amount'],
    );
    final feeLabel = rawFee == null || rawFee.isEmpty
        ? rawPrice == null || rawPrice.isEmpty
            ? (map['included'] == true ? 'Included' : '')
            : formatMoneyLabel(rawPrice)
        : formatMoneyLabel(rawFee, plusForPlainNumber: true);
    final urgencySlug = _string(map['urgencySlug']) ??
        _string(map['urgency_slug']) ??
        _string(map['slug']) ??
        _string(map['code']) ??
        _string(map['priority']) ??
        label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final available = map['available'] != false &&
        map['isAvailable'] != false &&
        map['is_available'] != false &&
        map['enabled'] != false;
    return _UrgencyOption(
      label: label,
      detail: formatDetail(rawDetail),
      feeLabel: feeLabel,
      urgencySlug: urgencySlug,
      available: available,
    );
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null')
      return null;
    return text;
  }

  static String formatDetail(String? value) {
    final text = _string(value);
    if (text == null) return '';
    final dateTime = _parseDateTimeParts(text);
    if (dateTime == null) return text;

    final todayKey = _todayKeyForOffset(dateTime.offsetMinutes);
    final tomorrowKey = _dateKey(
      _shiftDateKey(todayKey, const Duration(days: 1)),
    );
    final slotKey = dateTime.key;
    final dayLabel = slotKey == todayKey
        ? 'Today'
        : slotKey == tomorrowKey
            ? 'Tomorrow'
            : _isWithinNextWeek(slotKey, todayKey)
                ? _weekdays[dateTime.weekday]
                : '${_months[dateTime.month - 1]} ${dateTime.day}';
    return '$dayLabel, ${_formatClock(dateTime.hour, dateTime.minute)}';
  }

  static String? _moneySource(dynamic value) {
    if (value is Map) {
      for (final key in const [
        'label',
        'priceLabel',
        'price_label',
        'feeLabel',
        'fee_label',
        'displayPrice',
        'display_price',
        'amount',
        'price',
        'priceAmount',
        'price_amount',
        'fee',
        'feeAmount',
        'fee_amount',
        'urgencyFee',
        'urgency_fee',
        'surcharge',
        'surchargeAmount',
        'surcharge_amount',
        'additionalFee',
        'additional_fee',
        'additionalFeeAmount',
        'additional_fee_amount',
      ]) {
        final nested = _moneySource(value[key]);
        if (nested != null && nested.isNotEmpty) return nested;
      }
      return null;
    }
    if (value is num) {
      return value % 1 == 0 ? value.toInt().toString() : value.toString();
    }
    return _string(value);
  }

  static String formatMoneyLabel(
    dynamic value, {
    bool plusForPlainNumber = false,
  }) {
    final text = _moneySource(value);
    if (text == null) return '';
    final lower = text.toLowerCase();
    if (lower == '0' || lower == '0.0' || lower == 'included') {
      return 'Included';
    }
    if (text.contains(r'$') ||
        lower.contains('free') ||
        lower.contains('included') ||
        lower.startsWith('from ') ||
        lower.startsWith('+')) {
      return text;
    }
    if (RegExp(r'^\d+(?:\.\d+)?$').hasMatch(text)) {
      return '${plusForPlainNumber ? '+' : ''}\$${double.parse(text).toStringAsFixed(2)}';
    }
    return text;
  }

  static _UrgencyDateParts? _parseDateTimeParts(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T\s](\d{2}):(\d{2}))?(?::\d{2})?(?:\.\d+)?(?:([+-])(\d{2}):?(\d{2})|Z)?',
    ).firstMatch(value.trim());
    if (match == null) {
      final parsed = DateTime.tryParse(value);
      if (parsed == null) return null;
      return _UrgencyDateParts(
        year: parsed.year,
        month: parsed.month,
        day: parsed.day,
        hour: parsed.hour,
        minute: parsed.minute,
        offsetMinutes: parsed.timeZoneOffset.inMinutes,
      );
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    final hour = int.tryParse(match.group(4) ?? '0');
    final minute = int.tryParse(match.group(5) ?? '0');
    final offsetSign = match.group(6);
    final offsetHour = int.tryParse(match.group(7) ?? '');
    final offsetMinute = int.tryParse(match.group(8) ?? '');
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null) {
      return null;
    }
    final offsetMinutes = offsetSign == null
        ? null
        : (offsetSign == '-' ? -1 : 1) *
            ((offsetHour ?? 0) * 60 + (offsetMinute ?? 0));
    return _UrgencyDateParts(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      offsetMinutes: offsetMinutes,
    );
  }

  static String _todayKeyForOffset(int? offsetMinutes) {
    if (offsetMinutes == null) return _dateKey(DateTime.now());
    final shiftedNow = DateTime.now().toUtc().add(
          Duration(minutes: offsetMinutes),
        );
    return _dateKey(shiftedNow);
  }

  static DateTime _shiftDateKey(String key, Duration duration) {
    final parts = key.split('-').map(int.parse).toList();
    return DateTime.utc(parts[0], parts[1], parts[2]).add(duration);
  }

  static bool _isWithinNextWeek(String key, String todayKey) {
    final date = _shiftDateKey(key, Duration.zero);
    final today = _shiftDateKey(todayKey, Duration.zero);
    final dayDelta = date.difference(today).inDays;
    return dayDelta > 1 && dayDelta < 7;
  }

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static String _formatClock(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final minuteText = minute.toString().padLeft(2, '0');
    return '$displayHour:$minuteText $period';
  }

  static const _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const _months = [
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
    'Dec',
  ];
}

class _UrgencyDateParts {
  final int year;
  final int month;
  final int day;
  final int hour;
  final int minute;
  final int? offsetMinutes;

  const _UrgencyDateParts({
    required this.year,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.offsetMinutes,
  });

  String get key => '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  int get weekday => DateTime.utc(year, month, day).weekday - 1;
}
