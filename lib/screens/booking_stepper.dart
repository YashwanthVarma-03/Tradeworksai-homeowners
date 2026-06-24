import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

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
  final String _selectedAddress = '124 Skyview Lane, Tampa, FL';
  final TextEditingController _gateCodeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<Map<String, dynamic>> _tiers = [
    {'name': 'Standard', 'desc': 'SLA: Response within 48 hours', 'surcharge': 0},
    {'name': 'Urgent', 'desc': 'SLA: Dispatch within 12 hours', 'surcharge': 30},
    {'name': 'Emergency', 'desc': 'SLA: Immediate 2-hour dispatch', 'surcharge': 75},
  ];

  final List<String> _dates = ['Today', 'Tomorrow', 'Thu, Jun 25', 'Fri, Jun 26'];
  final List<String> _slots = ['8:00 AM', '10:00 AM', '1:00 PM', '3:00 PM', '5:00 PM'];

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
                style: AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 16),
              ),
              Text(
                'Step ${_currentStep + 1} of 5',
                style: const TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 13),
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
                color: isActive ? AppTheme.teal500 : AppTheme.line.withOpacity(0.3),
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
          'TradeWorks AI enforces upfront pricing to eliminate quotes negotiations and bidding wars.',
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    widget.proDetails['price']!,
                    style: const TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 16),
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
                  style: TextStyle(color: AppTheme.ink, fontSize: 12, height: 1.4),
                ),
              ] else ...[
                const Text(
                  'Flat Upfront Rate:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This is a flat rate service. The pro will perform the requested work for the specified amount. No bidding or hidden platform markup.',
                  style: TextStyle(color: AppTheme.ink, fontSize: 12, height: 1.4),
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
          'Choose an urgency tier. Emergency dispatch enforces a strict 2-hour response slot.',
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
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
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
                          style: const TextStyle(fontSize: 12, color: AppTheme.gray),
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
        const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        SizedBox(
          height: 45,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _dates.length,
            itemBuilder: (context, index) {
              final d = _dates[index];
              final isSel = d == _selectedDate;
              return GestureDetector(
                onTap: () => setState(() => _selectedDate = d),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        const Text('Select Time Slot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _slots.map((t) {
            final isSel = t == _selectedTime;
            return GestureDetector(
              onTap: () => setState(() => _selectedTime = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSel ? AppTheme.teal500 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSel ? AppTheme.teal500 : AppTheme.line),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Service Address & Instructions', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 20),
        const Text('Select Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.pageAlt,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.home_work, color: AppTheme.navy700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Gate / Access Code (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _gateCodeController,
          decoration: InputDecoration(
            hintText: 'e.g. #4233',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Access / Job Instructions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Detail key information, parking codes, or pet alerts here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }

  // --- STEP 5: REVIEW SUMMARY ---
  Widget _buildStepReviewSummary() {
    final surcharge = _tiers.firstWhere((t) => t['name'] == _selectedTier)['surcharge'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Booking Summary & Confirm', style: AppTheme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Confirm that the details below are correct. Commit to book the pro calendar.',
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              _buildReviewRow(Icons.bolt, 'SLA Urgency Tier', _selectedTier),
              _buildReviewRow(Icons.calendar_month, 'Scheduled Arrival', '$_selectedDate at $_selectedTime'),
              _buildReviewRow(Icons.location_on, 'Service Address', _selectedAddress),
              if (_gateCodeController.text.isNotEmpty)
                _buildReviewRow(Icons.vpn_key, 'Access Code', _gateCodeController.text),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Base Service Charge', style: TextStyle(color: AppTheme.gray, fontSize: 13)),
                  Text(widget.proDetails['price']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              if (surcharge > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$_selectedTier SLA Surcharge', style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
                    Text('+\$$surcharge', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.orange500)),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Diagnostic / Capped Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
                Text(label, style: const TextStyle(color: AppTheme.gray, fontSize: 11)),
                const SizedBox(height: 2),
                Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.pageAlt,
                foregroundColor: AppTheme.navy700,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                text: _currentStep == 4 ? 'Confirm & Book' : 'Continue',
                onPressed: () {
                  if (_currentStep < 4) {
                    setState(() {
                      _currentStep++;
                    });
                  } else {
                    // Complete
                    widget.onBookingComplete();
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
