import 'package:flutter/material.dart';

import '../../services/homeowner_service.dart';
import '../../theme.dart';
import '../../utils/app_error_utils.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({super.key});

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _mutedText = Color(0xFF64748B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

  List<dynamic> _addresses = [];
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _busyAddressId;

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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _hasChanges);
      },
      child: Scaffold(
        backgroundColor: _pageBackground,
        appBar: _appBar('Addresses'),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.orange500),
              )
            : RefreshIndicator(
                onRefresh: _fetchAddresses,
                color: AppTheme.orange500,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    if (_addresses.isEmpty)
                      _emptyState()
                    else
                      ..._addresses.map(
                        (dynamic item) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _addressCard(_asMap(item)),
                        ),
                      ),
                    _addAddressButton(),
                    const SizedBox(height: 16),
                    const Text(
                      'Addresses pre-fill your bookings and confirm whether a pro covers your ZIP.',
                      style: TextStyle(
                        color: _mutedText,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _appBar(String title) {
    return AppBar(
      toolbarHeight: 56,
      backgroundColor: Colors.white,
      elevation: 0,
      leadingWidth: 54,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, size: 25),
        color: AppTheme.navy700,
        onPressed: () => Navigator.pop(context, _hasChanges),
      ),
      titleSpacing: 0,
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.navy700,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _lineSoft),
      ),
    );
  }

  Widget _addressCard(Map<String, dynamic> address) {
    final id = address['id'];
    final isDefault =
        address['isDefault'] == true || address['isDefault'] == 'true';
    final busy = _busyAddressId == id?.toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _string(address['label']) ?? 'Address',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _inkStrong,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (isDefault) _pill('DEFAULT'),
              if (busy) ...[
                const SizedBox(width: 8),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.teal500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 11),
          Text(
            _addressLine(address),
            style: const TextStyle(
              color: _mutedText,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _lineSoft),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _textAction('Edit', () => _addOrEditAddress(address)),
              if (!isDefault)
                _textAction('Set default', () => _setDefault(id),
                    color: AppTheme.navy700),
              _textAction('Delete', () => _deleteAddress(id),
                  color: AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addAddressButton() {
    return OutlinedButton(
      onPressed: () => _addOrEditAddress(),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.teal500,
        side: const BorderSide(
          color: AppTheme.teal500,
          width: 1.2,
          style: BorderStyle.solid,
        ),
        padding: const EdgeInsets.symmetric(vertical: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        '+ Add address',
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lineSoft),
      ),
      child: const Text(
        'No saved addresses yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _mutedText,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _textAction(String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AppTheme.teal500,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7F8),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.teal500,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _addressLine(Map<String, dynamic> address) {
    final street = _string(address['street']);
    final unit = _string(address['unit']);
    final city = _string(address['city']);
    final state = _string(address['state']);
    final zip = _string(address['zip']);
    final line1 = [street, unit].whereType<String>().join(' ');
    final line2 = [city, state, zip].whereType<String>().join(', ');
    return [line1, line2].where((part) => part.isNotEmpty).join(', ');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppErrorUtils.friendlyMessage(error)),
        backgroundColor: AppTheme.error,
      ),
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
  static const Color _pageBackground = Color(0xFFF5F7FA);
  static const Color _inkStrong = Color(0xFF1E293B);
  static const Color _lineSoft = Color(0xFFE1E7EF);

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
    _labelCtrl = TextEditingController(text: address['label']?.toString() ?? '');
    _streetCtrl =
        TextEditingController(text: address['street']?.toString() ?? '');
    _unitCtrl = TextEditingController(text: address['unit']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: address['city']?.toString() ?? '');
    _stateCtrl = TextEditingController(text: address['state']?.toString() ?? '');
    _zipCtrl = TextEditingController(text: address['zip']?.toString() ?? '');
    _isDefault =
        address['isDefault'] == true || address['isDefault'] == 'true';
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
    if (!_formKey.currentState!.validate()) return;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorUtils.friendlyMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.addressToEdit != null;
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 54,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 25),
          color: AppTheme.navy700,
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Text(
          editing ? 'Edit address' : 'Add address',
          style: const TextStyle(
            color: AppTheme.navy700,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _lineSoft),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
          children: [
            _field('Label', _labelCtrl, required: true),
            const SizedBox(height: 14),
            _field('Street address', _streetCtrl, required: true),
            const SizedBox(height: 14),
            _field('Unit', _unitCtrl),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _field('City', _cityCtrl, required: true)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: _field('State', _stateCtrl, required: true),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _field('ZIP code', _zipCtrl,
                required: true, keyboardType: TextInputType.number),
            if (!editing) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isDefault,
                activeColor: AppTheme.orange500,
                title: const Text(
                  'Set as default address',
                  style: TextStyle(
                    color: _inkStrong,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onChanged: (value) => setState(() => _isDefault = value),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _lineSoft)),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.orange500,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  editing ? 'Save address' : 'Add address',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
        Text(
          label,
          style: const TextStyle(
            color: _inkStrong,
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: required
              ? (value) {
                  final text = value?.trim() ?? '';
                  return text.isEmpty ? 'Required' : null;
                }
              : null,
          style: const TextStyle(
            color: _inkStrong,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: _lineSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide:
                  const BorderSide(color: AppTheme.teal500, width: 1.3),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
