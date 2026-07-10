import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/homeowner_service.dart';
import '../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'account/manage_addresses.dart';
import 'booking_success_screen.dart';

class BookFlowScreen extends StatefulWidget {
  final Map<String, dynamic> pro;

  const BookFlowScreen({Key? key, required this.pro}) : super(key: key);

  @override
  State<BookFlowScreen> createState() => _BookFlowScreenState();
}

class _BookFlowScreenState extends State<BookFlowScreen> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1
  final _issueController = TextEditingController();
  List<XFile> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();

  // Step 2
  List<dynamic> _addresses = [];
  Map<String, dynamic>? _selectedAddressObj;
  final _accessNotesController = TextEditingController();
  bool _isLoadingAddresses = true;

  // Step 3
  bool _asap = false;
  String? _selectedDate;
  String? _selectedTime;

  bool _isLoadingSlots = false;
  String? _slotsError;
  List<dynamic> _availableSlotsList = [];
  List<String> _uiDates = [];
  Map<String, List<Map<String, dynamic>>> _uiSlotsByDate = {};

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    _fetchAvailability();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoadingAddresses = true);
    try {
      final profileResp = await HomeownerService.instance.fetchProfile();
      final List<dynamic> addressList = profileResp['addresses'] as List? ??
          profileResp['profile']?['addresses'] as List? ??
          [];
      if (mounted) {
        setState(() {
          _addresses = addressList;
          _isLoadingAddresses = false;
          if (_addresses.isNotEmpty) {
            _selectedAddressObj = _addresses.firstWhere(
                (a) => a['isDefault'] == true || a['isDefault'] == 'true',
                orElse: () => _addresses.first);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAddresses = false);
      }
    }
  }

  Future<void> _fetchAvailability() async {
    final contractorId =
        (widget.pro['contractorId'] ?? widget.pro['id'] ?? '1').toString();
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
        urgency: 'standard',
        fromDate: fromDate,
        toDate: toDate,
      );

      final List<dynamic> slotsList = data['slots'] ?? [];
      if (mounted) {
        setState(() {
          _availableSlotsList = slotsList;
          _isLoadingSlots = false;
          _parseSlotsIntoUI();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _slotsError = e.toString().replaceAll('Exception: ', '');
          _isLoadingSlots = false;
        });
      }
    }
  }

  void _parseSlotsIntoUI() {
    _uiDates.clear();
    _uiSlotsByDate.clear();

    if (_availableSlotsList.isEmpty) return;

    for (final slot in _availableSlotsList) {
      final startStr = slot['start'] as String?;
      if (startStr == null) continue;

      try {
        final dt = DateTime.parse(startStr).toLocal();

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = today.add(const Duration(days: 1));
        final checkDate = DateTime(dt.year, dt.month, dt.day);

        String dateKey;
        if (checkDate == today)
          dateKey = 'Today';
        else if (checkDate == tomorrow)
          dateKey = 'Tomorrow';
        else {
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
          dateKey =
              '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
        }

        int hour = dt.hour;
        final isPm = hour >= 12;
        if (hour > 12) hour -= 12;
        if (hour == 0) hour = 12;
        final minuteStr = dt.minute.toString().padLeft(2, '0');
        final timeLabel = '$hour:$minuteStr ${isPm ? 'PM' : 'AM'}';

        if (!_uiDates.contains(dateKey)) {
          _uiDates.add(dateKey);
        }

        _uiSlotsByDate.putIfAbsent(dateKey, () => []);
        _uiSlotsByDate[dateKey]!.add({
          'label': timeLabel,
          'slot': slot,
        });
      } catch (_) {}
    }

    if (_uiDates.isNotEmpty) {
      _selectedDate = _uiDates.first;
      final slotsForDate = _uiSlotsByDate[_selectedDate];
      if (slotsForDate != null && slotsForDate.isNotEmpty) {
        _selectedTime = slotsForDate.first['label'] as String;
      }
    } else {
      _selectedDate = null;
      _selectedTime = null;
    }
  }

  void _nextStep() {
    if (_currentStep == 1 && _selectedAddressObj == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please add an address to continue.'),
          backgroundColor: AppTheme.error));
      return;
    }
    if (_currentStep == 2 &&
        !_asap &&
        (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a time slot or choose ASAP.'),
          backgroundColor: AppTheme.error));
      return;
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submitRequest();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _submitRequest() async {
    setState(() => _isSubmitting = true);
    try {
      final contractorId =
          (widget.pro['contractorId'] ?? widget.pro['id'] ?? '1').toString();

      String? startsAt;
      String? endsAt;
      if (!_asap &&
          _selectedDate != null &&
          _uiSlotsByDate.containsKey(_selectedDate)) {
        final slotsForDate = _uiSlotsByDate[_selectedDate];
        if (slotsForDate != null) {
          final chosenSlotMap = slotsForDate.firstWhere(
              (s) => s['label'] == _selectedTime,
              orElse: () => slotsForDate.first);
          final slotObj = chosenSlotMap['slot'];
          startsAt = slotObj['start'];
          endsAt = slotObj['end'];
        }
      }

      if (startsAt == null) {
        final now = DateTime.now();
        DateTime targetDate = now.add(const Duration(days: 1));
        startsAt = targetDate.toIso8601String();
        endsAt = targetDate.add(const Duration(hours: 2)).toIso8601String();
      }

      String street = '123 Main St';
      String city = 'Springfield';
      String state = 'FL';
      String zip = '33569';

      if (_selectedAddressObj != null) {
        street = _selectedAddressObj!['street'] ?? '';
        city = _selectedAddressObj!['city'] ?? '';
        state = _selectedAddressObj!['state'] ?? '';
        zip = _selectedAddressObj!['zip'] ?? '';
      }

      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': widget.pro['trade'] ?? 'Home Service',
        'service_description': _issueController.text.isNotEmpty
            ? _issueController.text
            : 'Diagnostic and repair request.',
        'address_street': street,
        'address_city': city,
        'address_state': state,
        'address_zip': zip,
        'work_order_type': widget.pro['workOrderType'] ?? 'rate_card',
        'access_notes': _accessNotesController.text,
      };

      final actionVal = widget.pro['workOrderType'] == 'quote_request'
          ? 'quote_request'
          : 'commit';

      final response = await HomeownerService.instance.commitBooking(
        contractorId: contractorId,
        action: actionVal,
        urgency: _asap ? 'urgent' : 'standard',
        booking: bookingData,
        startsAt: startsAt,
        endsAt: endsAt,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);
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
        // Trigger verification email sending
        try {
          await HomeownerService.instance
              .sendVerificationEmail(AuthService.instance.userEmail ?? '');
        } catch (_) {}
        _showVerificationDialog();
      } else if (mounted) {
        setState(() => _isSubmitting = false);
        final message = errStr.contains('booking_cap')
            ? 'You already have the maximum number of open bookings. Please complete or cancel one from Scheduled or Active before placing another booking.'
            : errStr;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppTheme.error));
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
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: AppTheme.orange500, size: 28),
              SizedBox(width: 8),
              Text('Verify Email',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.navy700)),
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
                    letterSpacing: 8),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle:
                      TextStyle(color: Colors.grey.shade400, letterSpacing: 8),
                  counterText: '',
                  errorText: localError,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.orange500)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: verifying
                      ? null
                      : () async {
                          try {
                            await HomeownerService.instance
                                .sendVerificationEmail(
                                    AuthService.instance.userEmail ?? '');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Verification code resent!'),
                                  backgroundColor: AppTheme.success),
                            );
                          } catch (err) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Failed to resend: $err'),
                                  backgroundColor: AppTheme.error),
                            );
                          }
                        },
                  child: const Text('Resend Code',
                      style: TextStyle(
                          color: AppTheme.teal700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: verifying ? null : () => Navigator.pop(dialogContext),
              child:
                  const Text('Cancel', style: TextStyle(color: AppTheme.gray)),
            ),
            ElevatedButton(
              onPressed: verifying
                  ? null
                  : () async {
                      final code = codeController.text.trim();
                      if (code.length != 6) {
                        setDlgState(() {
                          localError = 'Please enter a 6-digit code';
                        });
                        return;
                      }

                      setDlgState(() {
                        verifying = true;
                        localError = null;
                      });

                      try {
                        await HomeownerService.instance
                            .confirmVerification(code);
                        if (mounted) {
                          Navigator.pop(
                              dialogContext); // close verification dialog
                          // Re-trigger submit request
                          _submitRequest();
                        }
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
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: verifying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.navy700))
                  : const Text('Verify & Book',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.navy700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.pro['businessName'] ?? 'Book Pro',
            style: const TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Progress
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: AppTheme.line,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.teal500),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStep(),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _prevStep,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppTheme.line),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Back',
                            style: TextStyle(
                                color: AppTheme.navy700,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.navy700))
                          : Text(
                              _currentStep == 3 ? 'Submit Request' : 'Continue',
                              style: const TextStyle(
                                  color: AppTheme.navy700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 1 of 4',
            style: TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        const SizedBox(height: 8),
        const Text('What do you need help with?',
            style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        const SizedBox(height: 24),
        const Text('Describe the issue',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _issueController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'E.g., The sink is leaking under the cabinet...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.teal500)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Photos (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final List<XFile> images = await _picker.pickMultiImage();
            if (images.isNotEmpty) {
              setState(() {
                _selectedPhotos.addAll(images);
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.pageAlt,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppTheme.line, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                const Icon(Icons.add_a_photo_outlined,
                    color: AppTheme.gray, size: 32),
                const SizedBox(height: 8),
                Text(
                    _selectedPhotos.isEmpty
                        ? 'Tap to upload photos'
                        : 'Tap to add more photos (${_selectedPhotos.length} added)',
                    style: const TextStyle(color: AppTheme.gray)),
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
                .map((photo) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(File(photo.path),
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: -5,
                          top: -5,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedPhotos.remove(photo);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 2 of 4',
            style: TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        const SizedBox(height: 8),
        const Text('Where is the service needed?',
            style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        const SizedBox(height: 24),

        // Service address label removed – default address is shown automatically
        const SizedBox(height: 8),
        if (_isLoadingAddresses)
          const Center(
              child: CircularProgressIndicator(color: AppTheme.orange500))
        else if (_addresses.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4F4),
              border: Border.all(color: AppTheme.error.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.location_off, color: AppTheme.error, size: 20),
                    SizedBox(width: 8),
                    Text('No address saved',
                        style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('You must add an address before booking.',
                    style: TextStyle(color: AppTheme.gray, fontSize: 13)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManageAddressesScreen()),
                      );
                      // Re-fetch addresses when user comes back
                      _fetchAddresses();
                    },
                    icon: const Icon(Icons.add_location_alt, size: 16),
                    label: const Text('Add an Address'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.navy700,
                      side: const BorderSide(color: AppTheme.navy700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Builder(
            builder: (context) {
              final defaultAddr = _addresses.firstWhere(
                  (a) => a['isDefault'] == true || a['isDefault'] == 'true',
                  orElse: () => _addresses.first);
              // Ensure _selectedAddressObj is set to default
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_selectedAddressObj?['id'] != defaultAddr['id'] &&
                    mounted) {
                  setState(() => _selectedAddressObj = defaultAddr);
                }
              });
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.teal500, width: 2),
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.tealTint,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.teal500),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(defaultAddr['label'] ?? 'Home',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                              '${defaultAddr['street']}, ${defaultAddr['city']}, ${defaultAddr['state']} ${defaultAddr['zip']}'),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],

        const SizedBox(height: 20),
        const Text('Access Notes (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _accessNotesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Gate code, parking instructions, etc.',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.teal500)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 3 of 4',
            style: TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        const SizedBox(height: 8),
        const Text('When do you need it?',
            style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        const SizedBox(height: 24),
        CheckboxListTile(
          value: _asap,
          onChanged: (v) => setState(() => _asap = v ?? false),
          title: const Text('As Soon As Possible (ASAP)',
              style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle:
              const Text('Pro will respond with their earliest availability.'),
          activeColor: AppTheme.teal500,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (!_asap) ...[
          const SizedBox(height: 20),
          const Text('Select preferred time slot:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          if (_isLoadingSlots)
            const Center(
                child: CircularProgressIndicator(color: AppTheme.orange500))
          else if (_slotsError != null)
            Text(_slotsError!, style: const TextStyle(color: AppTheme.error))
          else if (_uiDates.isEmpty)
            const Text('No direct booking slots available.')
          else ...[
            SizedBox(
              height: 45,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _uiDates.length,
                itemBuilder: (context, index) {
                  final d = _uiDates[index];
                  final isSel = d == _selectedDate;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDate = d;
                        final nextSlots = _uiSlotsByDate[d] ?? [];
                        if (nextSlots.isNotEmpty) {
                          _selectedTime = nextSlots.first['label'] as String;
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.teal500 : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: isSel ? AppTheme.teal500 : AppTheme.line),
                      ),
                      child: Text(
                        d,
                        style: TextStyle(
                          color: isSel ? Colors.white : AppTheme.navy700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedDate != null)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: (_uiSlotsByDate[_selectedDate!] ?? []).map((slotMap) {
                  final label = slotMap['label'] as String;
                  final isSel = _selectedTime == label;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedTime = label);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.tealTint : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isSel ? AppTheme.teal500 : AppTheme.line),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isSel ? AppTheme.teal700 : AppTheme.ink,
                          fontWeight:
                              isSel ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
          ]
        ],
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 4 of 4',
            style: TextStyle(
                color: AppTheme.teal700,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        const SizedBox(height: 8),
        const Text('Review & Submit',
            style: TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 22)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.pageAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SERVICE DETAILS',
                  style: TextStyle(
                      color: AppTheme.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(widget.pro['trade'] ?? 'Home Service',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                  _issueController.text.isEmpty
                      ? 'No description provided'
                      : _issueController.text,
                  style: const TextStyle(color: AppTheme.ink)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1)),
              const Text('ADDRESS',
                  style: TextStyle(
                      color: AppTheme.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_selectedAddressObj != null)
                Text(
                    '${_selectedAddressObj!['street']}, ${_selectedAddressObj!['city']}, ${_selectedAddressObj!['state']} ${_selectedAddressObj!['zip']}',
                    style: const TextStyle(fontWeight: FontWeight.bold))
              else
                const Text('No Address Selected',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1)),
              const Text('SCHEDULE',
                  style: TextStyle(
                      color: AppTheme.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  _asap
                      ? 'As Soon As Possible (ASAP)'
                      : (_selectedDate != null && _selectedTime != null)
                          ? '$_selectedDate at $_selectedTime'
                          : 'Anytime',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.tealTint,
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppTheme.teal700, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No payment is required now. The pro will review your request and provide a quote or confirm the booking before any charges.',
                  style: TextStyle(
                      color: AppTheme.teal700, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
