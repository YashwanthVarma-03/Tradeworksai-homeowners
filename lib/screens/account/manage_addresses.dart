import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  static const Color _pageBackground = AppTheme.pageBackground;
  static const Color _lineSoft = AppTheme.cardBorder;

  List<dynamic> _addresses = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _busyAddressId;
  bool _exitRequested = false;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    try {
      final profile = await HomeownerService.instance.fetchProfile();
      if (!mounted) return;
      setState(() {
        _addresses = profile['addresses'] as List? ??
            profile['profile']?['addresses'] as List? ??
            const [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError(e);
    }
  }

  Future<void> _deleteAddress(dynamic id) async {
    if (_busyAddressId != null) return;
    final parsedId = int.tryParse(id?.toString() ?? '');
    if (parsedId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete address'),
        content: const Text('Remove this saved address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busyAddressId = parsedId.toString());
    try {
      await HomeownerService.instance.removeAddress(parsedId);
      _hasChanges = true;
      await _fetchAddresses();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyAddressId = null);
    }
  }

  Future<void> _setDefault(dynamic id) async {
    if (_busyAddressId != null) return;
    final key = id?.toString();
    if (key == null || key.isEmpty) return;
    setState(() => _busyAddressId = key);
    try {
      await HomeownerService.instance.setDefaultAddress(id);
      _hasChanges = true;
      await _fetchAddresses();
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyAddressId = null);
    }
  }

  Future<void> _addOrEditAddress([Map<String, dynamic>? address]) async {
    if (_busyAddressId != null) return;
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditAddressScreen(addressToEdit: address),
      ),
    );
    if (changed == true) {
      _hasChanges = true;
      await _fetchAddresses();
    }
  }

  void _exit() {
    if (_busyAddressId != null) {
      AppNotification.showInfo(
        context,
        'Please wait while the address change is being saved.',
      );
      return;
    }
    setState(() => _exitRequested = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, _hasChanges);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _exitRequested,
      onPopInvoked: (didPop) {
        if (!didPop) _exit();
      },
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: TwAppBar(title: 'Addresses', onBack: _exit),
        body: _isLoading
            ? const SkeletonPage(layout: SkeletonLayout.cards)
            : RefreshIndicator(
                onRefresh: _fetchAddresses,
                color: AppTheme.navy,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    TwPage(
                      top: TwSpace.s20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_addresses.isEmpty)
                            _emptyState()
                          else
                            ..._addresses.map(
                              (dynamic item) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: TwSpace.s16),
                                child: _addressCard(_asMap(item)),
                              ),
                            ),
                          _addAddressButton(),
                          const SizedBox(height: TwSpace.s16),
                          Text(
                            'Addresses pre-fill your bookings and confirm whether a pro covers your ZIP.',
                            style: TwType.meta(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> address) {
    final id = address['id'];
    final isDefault =
        address['isDefault'] == true || address['isDefault'] == 'true';
    final busy = _busyAddressId == id?.toString();
    return TwCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _string(address['label']) ?? 'Address',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TwType.h3(),
                ),
              ),
              if (isDefault) _defaultMark(),
              if (busy) ...[
                const SizedBox(width: TwSpace.s8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.navy,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _addressLine(address),
            style: TwType.bodySm(),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _lineSoft),
          const SizedBox(height: TwSpace.s4),
          Wrap(
            spacing: 24,
            children: [
              TwTextAction(
                label: 'Edit',
                onPressed: () => _addOrEditAddress(address),
              ),
              if (!isDefault)
                TwTextAction(
                  label: 'Set default',
                  onPressed: () => _setDefault(id),
                ),
              TwTextAction(
                label: 'Delete',
                onPressed: () => _deleteAddress(id),
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Secondary button (v3.3 rule 3): white, grey border, navy label.
  Widget _addAddressButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _addOrEditAddress(),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Add address'),
      ),
    );
  }

  Widget _emptyState() {
    return const Padding(
      padding: EdgeInsets.only(bottom: TwSpace.s16),
      child: TwEmptyState(
        icon: Icons.location_on_outlined,
        title: 'No saved addresses yet.',
      ),
    );
  }

  /// "Default" — a green check and the word (v3.3: no pills).
  Widget _defaultMark() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_rounded, size: 16, color: AppTheme.greenMark),
        SizedBox(width: 4),
        Text(
          'Default',
          style: TextStyle(
            color: AppTheme.green,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _addressLine(Map<String, dynamic> address) {
    final street = _string(address['street']);
    final unit = _string(address['unit']);
    final city = _string(address['city']);
    final state = _string(address['state']);
    final zip = _string(address['zip']);
    final line1 = [street, unit].whereType<String>().join(' ');
    final stateZip = [state, zip].whereType<String>().join(' ');
    final line2 = [city, stateZip]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(', ');
    // Street on one line, "Riverview, FL 33578" on the next (F06).
    return [line1, line2].where((part) => part.isNotEmpty).join('\n');
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  String? _string(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text.toLowerCase() == 'null') {
      return null;
    }
    return text;
  }

  void _showError(Object error) {
    if (!mounted) return;
    AppNotification.showError(
      context,
      error,
      fallback: 'We couldn\'t update your addresses. Please try again.',
    );
  }
}

class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? addressToEdit;

  const EditAddressScreen({super.key, this.addressToEdit});

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  static const Color _pageBackground = AppTheme.pageBackground;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _labelCtrl;
  late final TextEditingController _streetCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _zipCtrl;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final address = widget.addressToEdit ?? const {};
    _labelCtrl =
        TextEditingController(text: address['label']?.toString() ?? '');
    _streetCtrl =
        TextEditingController(text: address['street']?.toString() ?? '');
    _unitCtrl = TextEditingController(text: address['unit']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: address['city']?.toString() ?? '');
    _stateCtrl =
        TextEditingController(text: address['state']?.toString() ?? '');
    _zipCtrl = TextEditingController(text: address['zip']?.toString() ?? '');
    _isDefault = address['isDefault'] == true || address['isDefault'] == 'true';
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _streetCtrl.dispose();
    _unitCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final payload = {
      'label': _labelCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'unit': _unitCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'zip': _zipCtrl.text.trim(),
      'isDefault': _isDefault.toString(),
    };
    try {
      if (widget.addressToEdit == null) {
        await HomeownerService.instance.addAddress(payload);
      } else {
        await HomeownerService.instance.updateAddress(
          addressId: int.parse(widget.addressToEdit!['id'].toString()),
          address: payload,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      AppNotification.showError(
        context,
        e,
        fallback: 'We couldn\'t save this address. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.addressToEdit != null;
    return TransactionGuard(
      isProcessing: _isLoading,
      blockedMessage: 'Please wait while this address is being saved.',
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: TwAppBar(
          title: editing ? 'Edit address' : 'Add address',
          onBack: () => Navigator.pop(context),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              TwPage(
                top: TwSpace.s20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field('Label', _labelCtrl, required: true),
                    const SizedBox(height: TwSpace.s16),
                    _field('Street address', _streetCtrl, required: true),
                    const SizedBox(height: TwSpace.s16),
                    _field('Unit', _unitCtrl),
                    const SizedBox(height: TwSpace.s16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _field('City', _cityCtrl, required: true)),
                        const SizedBox(width: TwSpace.s12),
                        SizedBox(
                          width: 96,
                          child: _field('State', _stateCtrl, required: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: TwSpace.s16),
                    _field('ZIP code', _zipCtrl,
                        required: true, keyboardType: TextInputType.number),
                    if (!editing) ...[
                      const SizedBox(height: TwSpace.s16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _isDefault,
                        activeColor: AppTheme.white,
                        activeTrackColor: AppTheme.blue,
                        inactiveThumbColor: AppTheme.white,
                        inactiveTrackColor: AppTheme.border,
                        trackOutlineColor:
                            const WidgetStatePropertyAll(Colors.transparent),
                        title: Text(
                          'Set as default address',
                          style: TwType.title(),
                        ),
                        onChanged: (value) =>
                            setState(() => _isDefault = value),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: TwStickyBar(
          children: [
            TwPrimaryButton(
              label: editing ? 'Save address' : 'Add address',
              loading: _isLoading,
              onPressed: _isLoading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TwFieldLabel(label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: required
              ? (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty ? 'Required' : null;
                }
              : null,
          style: TwType.body(color: AppTheme.navy),
          decoration: TwInputs.decoration(),
        ),
      ],
    );
  }
}
