import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/homeowner_service.dart';
import '../theme.dart';
import '../widgets/main_bottom_navigation.dart';
import 'account/manage_addresses.dart';
import 'booking_success_screen.dart';

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
  static const double _contentInset = 16;
  static const double _headerInset = 0;

  late final PageController _pageController;
  final _issueController = TextEditingController();
  final _accessNotesController = TextEditingController();
  final _onsiteNotesController = TextEditingController();
  final _creditAmountController = TextEditingController();
  final _picker = ImagePicker();
  final Set<String> _selectedDetailChips = <String>{};

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

  bool _isLoadingAddresses = true;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;
  bool _useServiceCredits = false;
  String? _slotsError;
  String? _profileLoadError;
  double? _availableServiceCredits;

  int _pageIndex = 0;
  int _selectedServiceIndex = 0;
  int _selectedPricingIndex = 0;
  int _selectedUrgencyIndex = 0;
  final bool _asap = false;
  String? _selectedDate;
  String? _selectedTime;

  List<String> _dates = [];
  Map<String, List<Map<String, dynamic>>> _slotsByDate = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _issueController.text = _backendDescription;
    _loadProfileAndAvailability();
    _loadAddresses();
    _loadServiceCredits();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _issueController.dispose();
    _accessNotesController.dispose();
    _onsiteNotesController.dispose();
    _creditAmountController.dispose();
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

  bool get _isDetailsPage => _currentPage == _BookingPage.details;

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
          label: _string(_mergedPro['pricingLabel']) ??
              _string(_mergedPro['pricing_label']) ??
              'Upfront price',
          detail: pricingDetail,
          amount: price,
          priceText: priceText,
          priceHeadline: price == null ? priceText : '\$$price',
          workOrderType: workOrderType,
          secondaryText: pricingDetail,
        ),
      ],
      detailChips: const [],
    );
  }

  String _formatPriceLabel(int? price) {
    if (price == null) return '';
    return 'From \$$price';
  }

  String _moneyText(String? value) {
    if (value == null) return '';
    final lower = value.toLowerCase();
    if (value.contains(r'$') ||
        lower.contains('free') ||
        lower.startsWith('from ')) {
      return value;
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
    if (fee.isEmpty) return 'Included';
    if (fee.toLowerCase() == 'included') return 'Included';
    return fee;
  }

  String _urgencyCardPriceSubtext(_UrgencyOption tier) {
    final servicePrice = _priceAmountOnly(_selectedPricingChoice.priceText);
    return servicePrice.isEmpty ? '' : 'Service $servicePrice';
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
                'Responds within 8 hours',
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
                'Responds within 2 hours',
          ),
          feeLabel: _urgencyFallbackPriceText('emergency'),
          urgencySlug: 'emergency',
          available: true,
        );
      default:
        return _UrgencyOption(
          label: 'Standard',
          detail: _UrgencyOption.formatDetail(
            responseTime.isNotEmpty ? responseTime : 'Responds within 48 hours',
          ),
          feeLabel: _urgencyFallbackPriceText('standard'),
          urgencySlug: 'standard',
          available: true,
        );
    }
  }

  _UrgencyOption _withLiveUrgencySummary(_UrgencyOption option) {
    final key = option.urgencySlug.toLowerCase();
    return option.copyWith(
      detail: _urgencyAvailabilityDetails[key],
      feeLabel: _urgencyAvailabilityPrices[key],
      available: _urgencyAvailabilityStates[key],
    );
  }

  String _urgencyFallbackPriceText(String urgency) {
    final camelPrefix =
        '${urgency[0].toLowerCase()}${urgency.substring(1)}';
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

  List<_BookingPage> get _pages {
    return <_BookingPage>[
      _BookingPage.service,
      _BookingPage.details,
      _BookingPage.urgency,
      _BookingPage.schedule,
      _BookingPage.review,
    ];
  }

  _BookingPage get _currentPage => _pages[_pageIndex];

  bool get _isLastPage => _pageIndex == _pages.length - 1;

  int get _currentStepNumber => _pageIndex + 1;

  int get _totalSteps => _pages.length;

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
            _issueController.text = _backendDescription;
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
          await _hydrateUrgencySummaries();
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
    final selectedUrgencyKey = _selectedUrgency.urgencySlug.toLowerCase();

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

      final slotsList = _readList(data['slots']) ?? [];
      final selectedDetail = _firstAvailabilityDetail(slotsList);
      final selectedPrice = _availabilityPriceText(
        data,
        urgencySlug: _selectedUrgency.urgencySlug,
      );
      if (!mounted) return;
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
      if (!mounted) return;
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
        final slotsList = _readList(data['slots']) ?? [];
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

    if (!mounted || (details.isEmpty && prices.isEmpty && states.isEmpty)) return;
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
    final to = from.add(const Duration(days: 7));
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
      _slotsByDate[dateKey]!.add({
        'label': timeLabel,
        'slot': Map<String, dynamic>.from(slot),
      });
    }

    _dates = _dates.toSet().toList();
    if (_dates.isNotEmpty) {
      _selectedDate = _dates.first;
      final nextSlots = _slotsByDate[_selectedDate] ?? [];
      _selectedTime =
          nextSlots.isNotEmpty ? nextSlots.first['label'] as String : null;
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
        throw Exception(
            'This contractor is missing booking details right now.');
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
      if (startsAt == null || endsAt == null) {
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

      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': service.title,
        'service_description': _issueController.text.trim().isNotEmpty
            ? _issueController.text.trim()
            : service.subtitle,
        'address_street': street,
        'address_city': city,
        'address_state': state,
        'address_zip': zip,
        'work_order_type': selectedPricing.workOrderType,
        'access_notes': _accessNotesController.text.trim(),
        'service_details': service.title,
        'attached_photos': _selectedPhotos.map((p) => p.path).toList(),
        'selected_pricing_label': selectedPricing.label,
        if (selectedPricing.amount != null)
          'upfront_price': selectedPricing.amount,
        if (_appliedServiceCredits(selectedPricing.amount) > 0)
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
      final viewed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            woNumber: workOrder['woNumber']?.toString(),
            scheduledStart: workOrder['scheduledStart']?.toString() ?? startsAt,
            scheduledEnd: workOrder['scheduledEnd']?.toString() ?? endsAt,
            contractorName: _proName,
            trade: _proTrade,
            service: service.title,
            address:
                '${address['street'] ?? ''}, ${address['city'] ?? ''}, ${address['state'] ?? ''}',
            price: _workOrderPriceText(workOrder, selectedPricing),
            contractorId: contractorId,
            workOrder: workOrder,
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppTheme.orange500, size: 28),
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
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.ink, height: 1.4),
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
                  onPressed:
                      verifying ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.gray)),
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
                      : const Text('Verify & Book',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: SafeArea(
          child: Column(
            children: [
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
                      padding: const EdgeInsets.fromLTRB(
                        _contentInset,
                        0,
                        _contentInset,
                        18,
                      ),
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _headerInset),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppTheme.navy700,
                size: 22,
              ),
              onPressed: _goBack,
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Step $_currentStepNumber of 5',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(
                Icons.close_rounded,
                color: AppTheme.navy700,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
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

  Widget _buildProgress() {
    return const SizedBox.shrink();
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
    final options = _serviceOptions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOOK ${_proName.isEmpty ? 'THIS PRO' : _proName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.teal500,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Confirm your service',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 24,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Based on your search. You can change it below.',
            style: TextStyle(
              color: AppTheme.gray,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 13),
          if (_profileLoadError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.orangeTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Couldn't load this pro's full service list: $_profileLoadError",
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
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
        ],
      ),
    );
  }

  Widget _bookingStepEmptyService(double scale) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16 * scale),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12 * scale),
        border: Border.all(color: const Color(0xFFE6E8EC)),
      ),
      child: Text(
        'No bookable service was returned by the backend for this contractor.',
        style: TextStyle(
          color: AppTheme.navy700,
          fontSize: 14 * scale,
          height: 1.35,
          fontWeight: FontWeight.w700,
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
      _issueController.text =
          service.subtitle.isNotEmpty ? service.subtitle : _backendDescription;
    });
    _refreshAvailability();
    _hydrateUrgencySummaries();
  }

  Widget _bookingStepServiceTile({
    required _ServiceOption service,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final priceIsEstimate =
        service.priceLabel.toLowerCase().contains('estimate') ||
            service.priceLabel.toLowerCase().contains('free');
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 60,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.navy700 : const Color(0xFFE6E8EC),
              width: selected ? 2.2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTheme.navy700 : Colors.transparent,
                  border: Border.all(
                    color:
                        selected ? AppTheme.navy700 : const Color(0xFF718198),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 12,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (service.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        service.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.gray,
                          fontSize: 13,
                          height: 1.15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (service.priceLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  service.priceLabel,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color:
                        priceIsEstimate ? AppTheme.success : AppTheme.navy700,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep() {
    final backendChips = _detailChipsForTrade(_proTrade);
    final chips = backendChips;
    final searchPhotos = _searchPhotoUrls;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Book ${_proName.isNotEmpty ? _proName : 'this pro'}'.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.teal500,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Anything else we should know?',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Optional - add details or photos to help ${_proName.isNotEmpty ? _proName : 'the pro'} prepare. You can also skip this step.',
            style: const TextStyle(
              color: AppTheme.gray,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            height: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E8EC)),
            ),
            child: TextField(
              controller: _issueController,
              maxLines: null,
              expands: true,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 14,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'AC isn\'t cooling properly',
                hintStyle: TextStyle(
                  color: AppTheme.gray,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (searchPhotos.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE6E8EC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Photos from your search',
                          style: TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        'View',
                        style: TextStyle(
                          color: AppTheme.teal500,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: searchPhotos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            searchPhotos[index],
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 72,
                              height: 72,
                              color: AppTheme.pageAlt,
                              child: const Icon(
                                Icons.image_outlined,
                                color: AppTheme.gray,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          InkWell(
            onTap: _pickPhotos,
            borderRadius: BorderRadius.circular(8),
            child: _DashedOutline(
              color: AppTheme.teal500,
              borderRadius: 8,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: AppTheme.teal500,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      '+ Add photos of the issue',
                      style: TextStyle(
                        color: AppTheme.teal500,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedPhotos.map((photo) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(photo.path),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -5,
                      top: -5,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPhotos.remove(photo)),
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppTheme.navy700,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white,
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
            const SizedBox(height: 12),
            const Text(
              'Common issues',
              style: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: chips.map((label) {
                final selected = _selectedDetailChips.contains(label);
                return InkWell(
                  onTap: () {
                    setState(() {
                      if (selected) {
                        _selectedDetailChips.remove(label);
                      } else {
                        _selectedDetailChips.add(label);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: selected
                            ? AppTheme.teal500
                            : const Color(0xFFE6E8EC),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.teal500
                            : const Color(0xFF1E293B),
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
              setState(() {
                _selectedPricingIndex = index;
                _urgencyAvailabilityDetails.clear();
                _urgencyAvailabilityPrices.clear();
                _urgencyAvailabilityStates.clear();
              });
              _refreshAvailability();
              _hydrateUrgencySummaries();
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
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOOK ${_proName.isEmpty ? 'THIS PRO' : _proName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.teal500,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'When do you need this?',
            style: TextStyle(
              color: AppTheme.navy700,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
              'These options and fees are set by $_proName. Other pros differ.',
              style: const TextStyle(
                  color: AppTheme.gray,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 13),
          ..._urgencyOptions.asMap().entries.map((entry) {
            final index = entry.key;
            final tier = entry.value;
            final selected = index == _selectedUrgencyIndex;
            final priceText = _urgencyCardPriceText(tier);
            final priceSubtext = _urgencyCardPriceSubtext(tier);
            final isIncluded = priceText.toLowerCase() == 'included';
            return Opacity(
              opacity: tier.available ? 1 : 0.42,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: tier.available
                      ? () {
                          setState(() => _selectedUrgencyIndex = index);
                          _refreshAvailability();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 68),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: selected
                              ? AppTheme.navy700
                              : const Color(0xFFDDE3EA),
                          width: selected ? 2 : 1),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                              color: selected
                                  ? AppTheme.navy700
                                  : const Color(0xFF718198),
                              width: selected ? 5 : 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tier.label,
                                style: const TextStyle(
                                  color: AppTheme.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tier.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.gray,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (priceText.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 118),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  priceText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: isIncluded
                                        ? AppTheme.success
                                        : AppTheme.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (priceSubtext.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    priceSubtext,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: AppTheme.gray,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 14),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppTheme.teal500, size: 19),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'The urgency fee goes to $_proName. TradeWorks adds no markup and no platform fee.',
                      style: const TextStyle(
                          color: AppTheme.navy700,
                          fontSize: 13,
                          height: 1.38,
                          fontWeight: FontWeight.w500))),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleStep() {
    final slots = _selectedDate == null
        ? const <Map<String, dynamic>>[]
        : _slotsByDate[_selectedDate] ?? const <Map<String, dynamic>>[];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 150),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BOOK ${_proName.isEmpty ? 'THIS PRO' : _proName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.teal500,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 8),
        const Text('Pick a time',
            style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Available times for $_proName',
            style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
        const SizedBox(height: 13),
        if (_isLoadingSlots)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.orange500)))
        else if (_slotsError != null)
          Text(_slotsError!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13))
        else if (_selectedAvailability?['paused'] == true)
          const Text(
            'This pro has paused new bookings. Try another contractor.',
            style: TextStyle(color: AppTheme.gray),
          )
        else if (_selectedUrgency.urgencySlug.toLowerCase() == 'emergency' &&
            _selectedAvailability?['emergencyEligible'] == false)
          const Text(
            'This pro can’t take an emergency booking. Pick another tier or another pro.',
            style: TextStyle(color: AppTheme.gray),
          )
        else if (_dates.isEmpty)
          const Text(
            'No availability in this window — try another pro or a different urgency.',
            style: TextStyle(color: AppTheme.gray),
          )
        else ...[
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (context, index) {
                final date = _dates[index];
                final selected = date == _selectedDate;
                final info = _dateTileInfo(date);
                return InkWell(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    final options = _slotsByDate[date] ?? [];
                    _selectedTime = options.isEmpty
                        ? null
                        : options.first['label']?.toString();
                  }),
                  borderRadius: BorderRadius.circular(7),
                  child: Container(
                    width: 76,
                    decoration: BoxDecoration(
                        color: selected ? AppTheme.navy700 : Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: selected
                                ? AppTheme.navy700
                                : const Color(0xFFE0E4EA))),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(info.$1,
                              style: TextStyle(
                                  color: selected ? Colors.white : AppTheme.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(info.$2,
                              style: TextStyle(
                                  color:
                                      selected ? Colors.white : AppTheme.gray,
                                  fontSize: 10)),
                        ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 40),
            itemCount: slots.length,
            itemBuilder: (context, index) {
              final slot = slots[index];
              final label = slot['label']?.toString() ?? '';
              final selected = label == _selectedTime;
              return InkWell(
                onTap: () => setState(() => _selectedTime = label),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                          color: selected
                              ? AppTheme.navy700
                              : const Color(0xFFE0E4EA),
                          width: selected ? 1.8 : 1)),
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? AppTheme.navy700 : AppTheme.ink,
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w500)),
                ),
              );
            },
          ),
        ],
      ]),
    );
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
    return (date, '${months[parsed.month - 1]} ${parsed.day}');
  }

  Widget _buildLocationStep() {
    return _stepShell(
      title: 'Where & anything we should know',
      subtitle:
          'Separate the job description from access instructions. Photos and notes stay attached to the work order.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Service address'),
          const SizedBox(height: 8),
          if (_isLoadingAddresses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.orange500)),
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
                    style: TextStyle(
                        color: AppTheme.teal700, fontWeight: FontWeight.w700),
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
    final detail = _issueController.text.trim().isEmpty
        ? _selectedService.subtitle
        : _issueController.text.trim();
    final address = _selectedAddressObj;
    final addressText = address == null
        ? ''
        : [
            _string(address['street']),
            _string(address['city']),
            _string(address['state']),
            _string(address['zip']),
          ].whereType<String>().where((value) => value.isNotEmpty).join(', ');
    final when = _selectedDate != null && _selectedTime != null
        ? '$_selectedDate $_selectedTime'
        : '';
    final fromPrice = _websiteFromPriceValue();
    final emergencySurcharge = _selectedEmergencySurchargeLabel();

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 150),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BOOK ${_proName.isEmpty ? 'THIS PRO' : _proName.toUpperCase()}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppTheme.teal500,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        const Text('Review & confirm',
            style: TextStyle(
                color: AppTheme.navy700,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        const Text('Confirm the details below to book.',
            style: TextStyle(color: AppTheme.gray, fontSize: 14)),
        const SizedBox(height: 14),
        _reviewPanel(Column(children: [
          _reviewLine('Pro', _proName, onChange: () => _goToPage(0)),
          _reviewLine('Service', _selectedService.title,
              onChange: () => _goToPage(0)),
          _reviewLine('When', when, onChange: () => _goToPage(3)),
          _reviewLine('Urgency', _selectedUrgency.label,
              onChange: () => _goToPage(2)),
          if (fromPrice.isNotEmpty) _reviewLine('From', fromPrice),
          if (emergencySurcharge.isNotEmpty)
            _reviewLine('Emergency surcharge', emergencySurcharge),
        ])),
        const SizedBox(height: 11),
        _reviewPanel(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('YOUR DETAILS',
                style: TextStyle(
                    color: AppTheme.gray,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            InkWell(
                onTap: () => _goToPage(1),
                child: const Text('Change',
                    style: TextStyle(
                        color: AppTheme.teal500,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)))
          ]),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(detail,
                style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700))
          ],
          if (_selectedPhotos.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
                spacing: 8,
                children: _selectedPhotos
                    .take(3)
                    .map((photo) => ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(File(photo.path),
                            width: 42, height: 42, fit: BoxFit.cover)))
                    .toList())
          ],
        ])),
        const SizedBox(height: 11),
        _reviewPanel(Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('SERVICE ADDRESS',
                    style: TextStyle(
                        color: AppTheme.gray,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(addressText.isEmpty ? 'No saved address' : addressText,
                    style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700))
              ])),
          IconButton(
              onPressed: _openManageAddresses,
              icon: const Icon(Icons.edit_outlined, color: AppTheme.gray))
        ])),
        const SizedBox(height: 11),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFEAF4FF),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('UPFRONT PRICE',
                        style: TextStyle(
                            color: AppTheme.teal500,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('You pay $_proName directly · \$0 markup',
                        style:
                            const TextStyle(color: AppTheme.gray, fontSize: 12))
                  ])),
              Text(_priceText(pricing),
                  style: const TextStyle(
                      color: AppTheme.navy700,
                      fontSize: 24,
                      fontWeight: FontWeight.w900))
            ])),
        if (_availableServiceCredits != null && pricing.amount != null) ...[
          const SizedBox(height: 11),
          _serviceCreditsPanel(pricing.amount!),
        ],
      ]),
    );
  }

  Widget _reviewPanel(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E4EA))),
        child: child,
      );

  double _appliedServiceCredits(int? price) {
    if (!_useServiceCredits ||
        price == null ||
        _availableServiceCredits == null) {
      return 0;
    }
    final entered = double.tryParse(_creditAmountController.text.trim());
    final requested = entered ?? _availableServiceCredits!;
    return requested.clamp(
        0,
        [price.toDouble(), _availableServiceCredits!]
            .reduce((a, b) => a < b ? a : b));
  }

  Widget _serviceCreditsPanel(int price) {
    final balance = _availableServiceCredits ?? 0;
    final applied = _appliedServiceCredits(price);
    final amountDue = price - applied;
    return _reviewPanel(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
              child: Text('Use service credits',
                  style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w800))),
          Switch(
            value: _useServiceCredits,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.teal500,
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
        const SizedBox(height: 6),
        Text('Available balance: \$${balance.toStringAsFixed(2)}',
            style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
        if (_useServiceCredits) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _creditAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixText: '\$  ',
              hintText: '0.00',
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.line)),
            ),
          ),
          const SizedBox(height: 8),
          Text('Credits applied: -\$${applied.toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppTheme.teal500,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const Divider(height: 24),
          Row(children: [
            const Expanded(
                child: Text('You pay',
                    style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800))),
            Text('\$${amountDue.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.navy700,
                    fontSize: 24,
                    fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 5),
          Text(
              amountDue <= 0
                  ? 'Fully covered by service credits'
                  : 'The remaining balance is paid directly to $_proName.',
              style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
        ],
      ],
    ));
  }

  Widget _reviewLine(String label, String value, {VoidCallback? onChange}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Text('$label: $value',
                  style: const TextStyle(
                      color: AppTheme.gray, fontSize: 14, height: 1.3))),
          if (onChange != null)
            InkWell(
                onTap: onChange,
                child: const Text('Change',
                    style: TextStyle(
                        color: AppTheme.teal500,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)))
        ]),
      );

  Widget _buildLegacyReviewStep() {
    final pricing = _selectedPricingChoice;
    final estimatedCredits =
        ((pricing.amount ?? _selectedService.amount ?? 149) * 0.05).round();

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
    final label = _isLastPage ? 'Confirm booking' : 'Continue';
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _contentInset,
                12,
                _contentInset,
                12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 45,
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
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyFooter() {
    if (_currentPage == _BookingPage.service) {
      return Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: _isSubmitting || !_hasBookableService
                        ? null
                        : _goToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: AppTheme.gray,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomNavBar(),
            ],
          ),
        ),
      );
    }

    if (_isDetailsPage) {
      return Container(
        color: const Color(0xFFF5F7FA),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _goToNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2E8F0),
                      disabledForegroundColor: AppTheme.gray,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              _buildBottomNavBar(),
            ],
          ),
        ),
      );
    }

    final label = _isLastPage
        ? 'Confirm booking'
        : (_currentPage == _BookingPage.location
            ? 'Review booking'
            : 'Continue');
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

  Widget _buildBottomNavBar() {
    return MainBottomNavigation(
      currentIndex: 1,
      onTap: _navigateToAppTab,
    );
  }

  void _navigateToAppTab(int index) {
    AppTabNavigation.request(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
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
              overflow:
                  multiline ? TextOverflow.ellipsis : TextOverflow.visible,
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

  String _formatArrivalWindow(DateTime start, DateTime end) {
    String format(DateTime dt) {
      var hour = dt.hour;
      final isPm = hour >= 12;
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      final minute =
          dt.minute == 0 ? '' : ':${dt.minute.toString().padLeft(2, '0')}';
      return '$hour$minute${isPm ? ' PM' : ' AM'}';
    }

    return '${format(start)}-${format(end)}';
  }

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
    if (pricing.amount != null) return '\$${pricing.amount}';
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
    required String startsAt,
    required String endsAt,
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
      final priceText =
          explicitPriceText ?? (price == null ? '' : 'From \$$price');
      choices.add(
        _PricingChoice(
          label: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? 'You approve the cap'
                  : 'Upfront price',
          detail: workOrderType == 'quote_request'
              ? ''
              : workOrderType == 'nte'
                  ? ''
                  : '',
          amount: price,
          priceText: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? priceText
                  : priceText,
          priceHeadline: workOrderType == 'quote_request'
              ? 'Free estimate'
              : workOrderType == 'nte'
                  ? 'You approve the cap'
                  : (price == null ? priceText : '\$$price'),
          workOrderType: workOrderType,
          secondaryText: workOrderType == 'quote_request'
              ? ''
              : workOrderType == 'nte'
                  ? ''
                  : '',
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
    final headline = _string(source['headline']) ??
        _string(source['priceHeadline']) ??
        _string(source['price_headline']) ??
        (amount != null ? '\$$amount' : label);
    final priceText = _string(source['priceText']) ??
        _string(source['price_text']) ??
        _string(source['priceLabel']) ??
        _string(source['price_label']) ??
        (amount != null ? 'From \$$amount' : label);
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
        _string(map['eta']) ??
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
      return '${plusForPlainNumber ? '+' : ''}\$$text';
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

  String get key =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  int get weekday => DateTime.utc(year, month, day).weekday - 1;
}
