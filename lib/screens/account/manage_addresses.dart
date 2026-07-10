import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/homeowner_service.dart';

class ManageAddressesScreen extends StatefulWidget {
  const ManageAddressesScreen({Key? key}) : super(key: key);

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  List<dynamic> _addresses = [];
  bool _isLoading = true;
  String? _settingDefaultId; // tracks which address is being set as default
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    setState(() => _isLoading = true);
    try {
      final profile = await HomeownerService.instance.fetchProfile();
      if (mounted) {
        setState(() {
          _addresses = profile['addresses'] as List? ??
              profile['profile']?['addresses'] as List? ??
              [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Cancel', style: TextStyle(color: AppTheme.gray))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final parsedId = int.tryParse(id) ?? 0;
      await HomeownerService.instance.removeAddress(parsedId);
      _hasChanges = true;
      _fetchAddresses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.error));
      }
    }
  }

  void _addOrEditAddress([Map<String, dynamic>? address]) async {
    final changed = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => EditAddressScreen(addressToEdit: address)),
    );
    if (changed == true) {
      _hasChanges = true;
      _fetchAddresses();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.white,
        appBar: AppBar(
          title: const Text('Addresses',
              style: TextStyle(
                  color: AppTheme.navy700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.orange500))
                    : _addresses.isEmpty
                        ? _buildEmptyState()
                        : _buildList(),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: AppTheme.white,
                  border: Border(top: BorderSide(color: AppTheme.line)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _addOrEditAddress(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: AppTheme.navy700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Add address',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_city_outlined,
              size: 64, color: AppTheme.gray.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No addresses yet',
              style: TextStyle(
                  color: AppTheme.navy700,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Add an address to see pros in your area.',
              style: TextStyle(color: AppTheme.gray)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _addresses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final a = _addresses[index];
        final isDefault = a['isDefault'] == true || a['isDefault'] == 'true';
        final addressStr =
            '${a['street'] ?? ''}, ${a['city'] ?? ''}, ${a['state'] ?? ''} ${a['zip'] ?? ''}';

        final isSettingDefault = _settingDefaultId == a['id']?.toString();

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDefault ? AppTheme.teal500 : AppTheme.line,
              width: isDefault ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Text(a['label'] ?? 'Address',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.navy700)),
                if (isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppTheme.tealTint,
                        borderRadius: BorderRadius.circular(4)),
                    child: const Text('Default',
                        style: TextStyle(
                            color: AppTheme.teal700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ]
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(addressStr,
                  style: const TextStyle(color: AppTheme.gray, fontSize: 13)),
            ),
            trailing: isSettingDefault
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.teal500))
                : PopupMenuButton(
                    icon: const Icon(Icons.more_vert, color: AppTheme.gray),
                    itemBuilder: (context) => [
                      if (!isDefault)
                        const PopupMenuItem(
                            value: 'default', child: Text('Set as Default')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete',
                              style: TextStyle(color: AppTheme.error))),
                    ],
                    onSelected: (val) async {
                      if (val == 'default') {
                        setState(() => _settingDefaultId = a['id']?.toString());
                        try {
                          final result = await HomeownerService.instance
                              .setDefaultAddress(a['id']);
                          if (result['success'] == true) {
                            // Optimistically update local list
                            setState(() {
                              for (final addr in _addresses) {
                                addr['isDefault'] = (addr['id']?.toString() ==
                                    a['id']?.toString());
                              }
                              _settingDefaultId = null;
                            });
                            _hasChanges = true;
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Default address updated!'),
                                    backgroundColor: AppTheme.success),
                              );
                            }
                          } else {
                            setState(() => _settingDefaultId = null);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(result['error'] ??
                                        'Failed to set default address.'),
                                    backgroundColor: AppTheme.error),
                              );
                            }
                          }
                        } catch (e) {
                          setState(() => _settingDefaultId = null);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error: ${e.toString().replaceAll('Exception:', '')}'),
                                  backgroundColor: AppTheme.error),
                            );
                          }
                        }
                        // Always re-fetch to be sure
                        _fetchAddresses();
                      } else if (val == 'edit') {
                        _addOrEditAddress(a);
                      } else if (val == 'delete') {
                        _deleteAddress(a['id']);
                      }
                    },
                  ),
            onTap: () => _addOrEditAddress(a),
          ),
        );
      },
    );
  }
}

class EditAddressScreen extends StatefulWidget {
  final Map<String, dynamic>? addressToEdit;
  const EditAddressScreen({Key? key, this.addressToEdit}) : super(key: key);

  @override
  State<EditAddressScreen> createState() => _EditAddressScreenState();
}

class _EditAddressScreenState extends State<EditAddressScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _labelCtrl;
  late TextEditingController _streetCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _zipCtrl;
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final a = widget.addressToEdit;
    _labelCtrl = TextEditingController(text: a?['label'] ?? '');
    _streetCtrl = TextEditingController(text: a?['street'] ?? '');
    _cityCtrl = TextEditingController(text: a?['city'] ?? '');
    _stateCtrl = TextEditingController(text: a?['state'] ?? '');
    _zipCtrl = TextEditingController(text: a?['zip'] ?? '');
    _isDefault = a?['isDefault'] == true || a?['isDefault'] == 'true';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.addressToEdit == null) {
        await HomeownerService.instance.addAddress({
          'label': _labelCtrl.text,
          'street': _streetCtrl.text,
          'city': _cityCtrl.text,
          'state': _stateCtrl.text,
          'zip': _zipCtrl.text,
          'isDefault': _isDefault.toString(),
        });
      } else {
        await HomeownerService.instance.updateAddress(
            addressId: int.parse(widget.addressToEdit!['id'].toString()),
            address: {
              'label': _labelCtrl.text,
              'street': _streetCtrl.text,
              'city': _cityCtrl.text,
              'state': _stateCtrl.text,
              'zip': _zipCtrl.text,
            });
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: Text(
            widget.addressToEdit == null ? 'Add address' : 'Edit address',
            style: const TextStyle(
                color: AppTheme.navy700,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildField(
                          'Label (e.g. Home, Rental)', _labelCtrl, true),
                      const SizedBox(height: 16),
                      _buildField('Street address', _streetCtrl, true),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              flex: 2,
                              child: _buildField('City', _cityCtrl, true)),
                          const SizedBox(width: 12),
                          Expanded(
                              flex: 1,
                              child: _buildField('State', _stateCtrl, true)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildField('ZIP Code', _zipCtrl, true, isNumber: true),
                      const SizedBox(height: 24),
                      if (widget.addressToEdit == null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Set as default address',
                                style: TextStyle(
                                    color: AppTheme.navy700,
                                    fontWeight: FontWeight.w600)),
                            Switch(
                              value: _isDefault,
                              onChanged: (val) =>
                                  setState(() => _isDefault = val),
                              activeColor: AppTheme.teal500,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.line)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: AppTheme.navy700,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.navy700))
                      : const Text('Save address',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool required,
      {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: AppTheme.ink)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.line)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
          validator: required
              ? (val) => (val == null || val.isEmpty) ? 'Required' : null
              : null,
        ),
      ],
    );
  }
}
