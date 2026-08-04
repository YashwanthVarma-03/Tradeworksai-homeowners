import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';
import '../services/auth_service.dart';
import 'booking_success_screen.dart';

class BookingStepper extends StatefulWidget {
  final Map<String, String> proDetails;
  final VoidCallback onBookingComplete;

  const BookingStepper({
    super.key,
    required this.proDetails,
    required this.onBookingComplete,
  });

  @override
  State<BookingStepper> createState() => _BookingStepperState();
}

class _BookingStepperState extends State<BookingStepper> {
  int _currentStep = 0;

  // Selection States
  String _selectedTier = 'Standard';
  String _selectedDate = 'Tomorrow';
  String _selectedTime = '10:00 AM';
  final TextEditingController _gateCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _tiers = [
    {
      'name': 'Standard',
      'desc': 'Responds within 48 hours',
      'surcharge': 0
    },
    {
      'name': 'Urgent',
      'desc': 'Responds within 12 hours',
      'surcharge': 30
    },
    {
      'name': 'Emergency',
      'desc': 'Responds within 2 hours',
      'surcharge': 75
    },
  ];

  bool _isLoadingSlots = false;
  String? _slotsError;
  List<dynamic> _availableSlots = [];
  List<String> _uiDates = [];
  Map<String, List<Map<String, dynamic>>> _uiSlotsByDate = {};

  List<dynamic> _addresses = [];
  Map<String, dynamic>? _selectedAddressObj;
  bool _isLoadingAddresses = false;
  bool _isSubmittingBooking = false;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
    _fetchAvailability();
  }

  Future<void> _fetchAddresses() async {
    if (!mounted) return;
    setState(() => _isLoadingAddresses = true);
    try {
      final profileResp = await HomeownerService.instance.fetchProfile();
      final List<dynamic> addressList = profileResp['addresses'] as List? ?? [];
      if (mounted) {
        setState(() {
          _addresses = addressList;
          _isLoadingAddresses = false;
          if (_addresses.isNotEmpty) {
            final defAddr = _addresses.firstWhere((a) => a['isDefault'] == true,
                orElse: () => _addresses.first);
            _selectedAddressObj = defAddr;
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
    final contractorId = widget.proDetails['contractorId'];
    if (contractorId == null || contractorId.isEmpty) return;

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

      final urgencyVal = _selectedTier.toLowerCase();

      final data = await HomeownerService.instance.getContractorAvailability(
        contractorId: contractorId,
        urgency: urgencyVal,
        fromDate: fromDate,
        toDate: toDate,
      );

      final List<dynamic> slotsList = data['slots'] ?? [];
      if (mounted) {
        setState(() {
          _availableSlots = slotsList;
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

    if (_availableSlots.isEmpty) {
      return;
    }

    for (final slot in _availableSlots) {
      final startStr = slot['start'] as String?;
      if (startStr == null) continue;

      try {
        final dt = DateTime.parse(startStr).toLocal();
        final dateKey = _formatDateKey(dt);
        final timeLabel = _formatTimeLabel(dt);

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
      _selectedDate = 'None';
      _selectedTime = 'None';
    }
  }

  String _formatDateKey(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    if (checkDate == today) return 'Today';
    if (checkDate == tomorrow) return 'Tomorrow';

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

    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  String _formatTimeLabel(DateTime dt) {
    int hour = dt.hour;
    final isPm = hour >= 12;
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    final minuteStr = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minuteStr ${isPm ? 'PM' : 'AM'}';
  }

  Future<void> _submitBooking() async {
    setState(() {
      _isSubmittingBooking = true;
    });

    try {
      final contractorId = widget.proDetails['contractorId'] ?? '';

      String? startsAt;
      String? endsAt;

      if (_uiSlotsByDate.containsKey(_selectedDate)) {
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

      String street = '';
      String city = '';
      String state = '';
      String zip = '';

      if (_selectedAddressObj != null) {
        street = _selectedAddressObj!['street'] ?? '';
        city = _selectedAddressObj!['city'] ?? '';
        state = _selectedAddressObj!['state'] ?? '';
        zip = _selectedAddressObj!['zip'] ?? '';
      } else {
        street = '124 Skyview Lane';
        city = 'Tampa';
        state = 'FL';
        zip = '33569';
      }

      final bookingData = {
        'requester_name': AuthService.instance.userName ?? 'Homeowner',
        'requester_email': AuthService.instance.userEmail ?? '',
        'service_category': widget.proDetails['trade'] ?? 'Home Service',
        'service_description': _notesController.text.isNotEmpty
            ? _notesController.text
            : 'Diagnostic and repair request.',
        'address_street': street,
        'address_city': city,
        'address_state': state,
        'address_zip': zip,
        'work_order_type': widget.proDetails['workOrderType'] ?? 'rate_card',
      };

      final actionVal = widget.proDetails['workOrderType'] == 'quote_request'
          ? 'quote_request'
          : 'commit';
      final urgencyVal = _selectedTier.toLowerCase();

      final response = await HomeownerService.instance.commitBooking(
        contractorId: contractorId,
        action: actionVal,
        urgency: urgencyVal,
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
        widget.onBookingComplete();
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
        final message = errStr.contains('booking_cap')
            ? 'You already have the maximum number of open bookings. Please complete or cancel one before placing another booking.'
            : errStr;
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
        setState(() {
          _isSubmittingBooking = false;
        });
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
                          // Re-trigger submit booking
                          _submitBooking();
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildStepperHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _buildCurrentStepContent(),
            ),
          ),
          _buildFooterNavigation(),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.line,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Book Pro: ${widget.proDetails['name']}',
                style:
                    AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 16),
              ),
              Text(
                'Step ${_currentStep + 1} of 5',
                style: const TextStyle(
                    color: AppTheme.teal700,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
        ),
        // Progress Bar
        Row(
          children: List.generate(5, (index) {
            final isActive = index <= _currentStep;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: isActive
                    ? AppTheme.teal500
                    : AppTheme.line.withOpacity(0.3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStepServiceConfirm();
      case 1:
        return _buildStepUrgencyTiers();
      case 2:
        return _buildStepSlotPicker();
      case 3:
        return _buildStepAddressPicker();
      case 4:
        return _buildStepReviewSummary();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: SERVICE CONFIRM ---
  Widget _buildStepServiceConfirm() {
    final isPlumbing = widget.proDetails['trade']?.contains('Plumber') ?? false;
    final isHVAC = widget.proDetails['trade']?.contains('HVAC') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Intake Check', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Choose the service you want booked. You will see the full price or approved cap before confirming.',
          style: AppTheme.textTheme.bodyMedium?.copyWith(color: AppTheme.gray),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.proDetails['trade']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    widget.proDetails['price']!,
                    style: const TextStyle(
                        color: AppTheme.teal700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              if (isPlumbing || isHVAC) ...[
                const Text(
                  'Diagnostic Booking cap (NTE):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is a diagnostic repair visit. You pay a capped diagnostic rate (\$89) which will be applied directly as credit toward your final repair cost if you approve the quote on site.',
                  style:
                      TextStyle(color: AppTheme.ink, fontSize: 12, height: 1.4),
                ),
              ] else ...[
                const Text(
                  'Flat Upfront Rate:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This service has upfront pricing from this pro. No hidden platform markup.',
                  style:
                      TextStyle(color: AppTheme.ink, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- STEP 2: URGENCY TIERS ---
  Widget _buildStepUrgencyTiers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SLA Dispatch Urgency', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Choose how soon you need this. Urgency fees go to the pro.',
          style: AppTheme.textTheme.bodyMedium?.copyWith(color: AppTheme.gray),
        ),
        const SizedBox(height: 20),
        ..._tiers.map((tier) {
          final isSelected = _selectedTier == tier['name'];
          final surcharge = tier['surcharge'] as int;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTier = tier['name'];
              });
              _fetchAvailability();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.tealTint : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppTheme.teal500 : AppTheme.line,
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected ? AppTheme.teal500 : AppTheme.gray,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tier['name'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSelected ? AppTheme.teal700 : AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tier['desc'],
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.gray),
                        ),
                      ],
                    ),
                  ),
                  if (surcharge > 0)
                    Text(
                      '+\$$surcharge',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.orange500,
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

  // --- STEP 3: SLOT PICKER ---
  Widget _buildStepSlotPicker() {
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child:
            Center(child: CircularProgressIndicator(color: AppTheme.orange500)),
      );
    }

    if (_slotsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppTheme.error),
            const SizedBox(height: 8),
            Text(_slotsError!,
                style: const TextStyle(color: AppTheme.gray, fontSize: 12)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _fetchAvailability, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_uiDates.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 40, color: AppTheme.gray),
            SizedBox(height: 12),
            Text(
              'No direct booking slots available.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'You can still proceed to submit a general quote request to the pro.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final slotsForDate = _uiSlotsByDate[_selectedDate] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Availability Scheduler', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Select a date and time slot inside the pro\'s calendar.',
          style: AppTheme.textTheme.bodyMedium?.copyWith(color: AppTheme.gray),
        ),
        const SizedBox(height: 24),
        const Text('Select Date',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
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
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.navy700 : AppTheme.pageAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    d,
                    style: TextStyle(
                      color: isSel ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        const Text('Select Time Slot',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        if (slotsForDate.isEmpty)
          const Text('No slots for this date.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slotsForDate.map((slotMap) {
              final t = slotMap['label'] as String;
              final isSel = t == _selectedTime;
              return GestureDetector(
                onTap: () => setState(() => _selectedTime = t),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? AppTheme.teal500 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isSel ? AppTheme.teal500 : AppTheme.line),
                  ),
                  child: Text(
                    t,
                    style: TextStyle(
                      color: isSel ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // --- STEP 4: ADDRESS PICKER ---
  Widget _buildStepAddressPicker() {
    if (_isLoadingAddresses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child:
            Center(child: CircularProgressIndicator(color: AppTheme.orange500)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Address & Instructions',
            style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 20),
        const Text('Select Address',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        if (_addresses.isEmpty) ...[
          const Text(
              'No saved addresses found. Please add an address to continue.',
              style: TextStyle(color: AppTheme.gray)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _showAddNewAddressDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
          ),
        ] else
          ..._addresses.map((item) {
            final isSelected = _selectedAddressObj?['id'] == item['id'];
            final street = item['street'] ?? '';
            final unit = item['unit'] ?? '';
            final city = item['city'] ?? '';
            final state = item['state'] ?? '';
            final zip = item['zip'] ?? '';
            final label = item['label'] ?? 'Address';
            final fullAddrText = unit.isNotEmpty
                ? '$street, $unit, $city, $state $zip'
                : '$street, $city, $state $zip';

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedAddressObj = item;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.tealTint : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.teal500 : AppTheme.line,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? AppTheme.teal500 : AppTheme.gray,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppTheme.navy700)),
                          const SizedBox(height: 2),
                          Text(fullAddrText,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        if (_addresses.isNotEmpty)
          TextButton.icon(
            onPressed: _showAddNewAddressDialog,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add different address'),
          ),
        const SizedBox(height: 20),
        const Text('Gate / Access Code (Optional)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _gateCodeController,
          decoration: InputDecoration(
            hintText: 'e.g. #4233',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Access / Job Instructions',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText:
                'Detail key information, parking codes, or pet alerts here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  void _showAddNewAddressDialog() {
    final labelCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    final stateCtrl = TextEditingController();
    final zipCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('Add Address',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Label (e.g. Home, Rental)')),
                TextField(
                    controller: streetCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Street Address')),
                TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Unit/Apt (Optional)')),
                TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(labelText: 'City')),
                TextField(
                    controller: stateCtrl,
                    decoration:
                        const InputDecoration(labelText: 'State (2-letter)')),
                TextField(
                    controller: zipCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'ZIP Code (5-digit)')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (labelCtrl.text.trim().isEmpty ||
                          streetCtrl.text.trim().isEmpty ||
                          cityCtrl.text.trim().isEmpty ||
                          stateCtrl.text.trim().isEmpty ||
                          zipCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Please fill all required fields'),
                              backgroundColor: AppTheme.error),
                        );
                        return;
                      }

                      setDlgState(() => isSaving = true);
                      try {
                        final addrPayload = {
                          'label': labelCtrl.text.trim(),
                          'street': streetCtrl.text.trim(),
                          'unit': unitCtrl.text.trim(),
                          'city': cityCtrl.text.trim(),
                          'state': stateCtrl.text.trim(),
                          'zip': zipCtrl.text.trim(),
                        };

                        await HomeownerService.instance.addAddress(addrPayload);
                        if (context.mounted) {
                          Navigator.pop(context);
                          _fetchAddresses();
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to save address: $e'),
                                backgroundColor: AppTheme.error),
                          );
                        }
                      } finally {
                        setDlgState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // --- STEP 5: REVIEW SUMMARY ---
  Widget _buildStepReviewSummary() {
    final surcharge = _tiers
        .firstWhere((t) => t['name'] == _selectedTier)['surcharge'] as int;
    final street = _selectedAddressObj?['street'] ?? 'No address selected';
    final unit = _selectedAddressObj?['unit'] ?? '';
    final city = _selectedAddressObj?['city'] ?? '';
    final state = _selectedAddressObj?['state'] ?? '';
    final zip = _selectedAddressObj?['zip'] ?? '';
    final fullAddr = unit.isNotEmpty
        ? '$street, $unit, $city, $state $zip'
        : '$street, $city, $state $zip';

    final arrivalText = _uiDates.isEmpty
        ? 'To be scheduled (Quote request)'
        : '$_selectedDate at $_selectedTime';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking Summary & Confirm', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Confirm the details below to book.',
          style: AppTheme.textTheme.bodyMedium?.copyWith(color: AppTheme.gray),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.proDetails['name']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    widget.proDetails['trade']!,
                    style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              _buildReviewRow(Icons.bolt, 'Urgency', _selectedTier),
              _buildReviewRow(
                  Icons.calendar_month, 'Scheduled Arrival', arrivalText),
              _buildReviewRow(Icons.location_on, 'Service Address', fullAddr),
              if (_gateCodeController.text.isNotEmpty)
                _buildReviewRow(
                    Icons.vpn_key, 'Access Code', _gateCodeController.text),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Upfront price',
                      style: TextStyle(color: AppTheme.gray, fontSize: 13)),
                  Text(widget.proDetails['price']!,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              if (surcharge > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_selectedTier SLA Surcharge',
                        style: const TextStyle(
                            color: AppTheme.gray, fontSize: 13)),
                    Text('+\$$surcharge',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.orange500)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total or approved cap',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(
                    surcharge > 0
                        ? '\$${89 + surcharge} Capped'
                        : widget.proDetails['price']!,
                    style: const TextStyle(
                      color: AppTheme.teal700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildReviewRow(IconData icon, String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.teal500, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: AppTheme.gray, fontSize: 11)),
                const SizedBox(height: 2),
                Text(val,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- FOOTER BUTTONS ---
  Widget _buildFooterNavigation() {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          if (_currentStep > 0)
            ElevatedButton(
              onPressed: _isSubmittingBooking
                  ? null
                  : () {
                      setState(() {
                        _currentStep--;
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pageAlt,
                foregroundColor: AppTheme.navy700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          // Next / Confirm button
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: _currentStep > 0 ? 12.0 : 0.0),
              child: HoverButton(
                text: _isSubmittingBooking
                    ? 'Booking...'
                    : (_currentStep == 4 ? 'Confirm & Book' : 'Continue'),
                onPressed: () {
                  if (!_isSubmittingBooking) {
                    if (_currentStep < 4) {
                      setState(() {
                        _currentStep++;
                      });
                    } else {
                      _submitBooking();
                    }
                  }
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}
