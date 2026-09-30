import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/homeowner_service.dart';
import '../../services/document_upload.dart';
import '../../theme.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

class HomeProfileScreen extends StatefulWidget {
  const HomeProfileScreen({super.key, required this.addresses});
  final List<dynamic> addresses;
  @override
  State<HomeProfileScreen> createState() => _HomeProfileScreenState();
}

class _HomeProfileScreenState extends State<HomeProfileScreen> {
  List<Map<String, dynamic>> _addresses = [];
  final Map<String, Map<String, dynamic>> _profiles = {};
  bool _loading = true, _saving = false;
  Object? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await HomeownerService.instance.fetchHomeProfiles();
      final addresses = (data['addresses'] as List? ?? widget.addresses)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final profiles = (data['homeProfiles'] as List? ?? []).whereType<Map>();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        for (final address in addresses) {
          final id = '${address['id']}';
          final found = profiles
              .where((p) => '${p['addressId'] ?? p['address_id']}' == id);
          final value = found.isEmpty
              ? <String, dynamic>{}
              : Map<String, dynamic>.from(found.first);
          _profiles[id] = {
            ...value,
            'addressId': int.tryParse(id),
            'propertyDetails':
                Map<String, dynamic>.from(value['propertyDetails'] as Map? ??
                    {
                      'squareFootage': value['squareFeet'],
                      'yearBuilt': value['yearBuilt'],
                    }),
            'systems': (value['systems'] as List? ?? [])
                .whereType<Map>()
                .toList()
                .asMap()
                .entries
                .map((e) => <String, dynamic>{
                      ...Map<String, dynamic>.from(e.value),
                      'id': e.value['id'] ?? 'legacy-$id-${e.key}'
                    })
                .toList(),
            'documents': (value['documents'] as List? ?? [])
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
            'accessNotes':
                Map<String, dynamic>.from(value['accessNotes'] as Map? ?? {}),
          };
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e;
          _loading = false;
        });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final profile in _profiles.values) {
        final details = profile['propertyDetails'] as Map;
        for (final key in details.keys) {
          final raw = '${details[key] ?? ''}'.trim();
          final number = raw.isEmpty ? null : num.tryParse(raw);
          if (raw.isNotEmpty &&
              (number == null || !number.isFinite || number < 0))
            throw Exception('Enter a valid non-negative number for $key.');
          if (key != 'bathrooms' &&
              number != null &&
              number != number.roundToDouble()) {
            throw Exception('Enter a whole number for $key.');
          }
          if (key == 'yearBuilt' &&
              number != null &&
              (number < 1600 ||
                  number > 2200 ||
                  number != number.roundToDouble()))
            throw Exception('Enter a valid year built.');
          if (number != null &&
              ((key == 'squareFootage' && (number < 1 || number > 10000000)) ||
                  ((key == 'bedrooms' || key == 'bathrooms') &&
                      number > 100))) {
            throw Exception('Enter a valid value for $key.');
          }
          details[key] = number;
        }
        await HomeownerService.instance.saveHomeProfile(profile);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editSystem(Map<String, dynamic> profile,
      [Map<String, dynamic>? system]) async {
    final updated = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => HomeSystemEditor(
                  addressId: profile['addressId'] as int,
                  system: system,
                )));
    if (updated == null || !mounted) return;
    setState(() {
      final systems = profile['systems'] as List;
      final index = systems.indexOf(system);
      if (index < 0) {
        systems.add(updated);
      } else {
        systems[index] = updated;
      }
    });
  }

  Future<void> _uploadDocument(Map<String, dynamic> profile) async {
    if (_saving) return;
    String? systemId;
    final systems = (profile['systems'] as List)
        .whereType<Map>()
        .where((s) => s['id'] != null)
        .toList();
    if (systems.isNotEmpty) {
      final selected = await showDialog<String>(
          context: context,
          builder: (context) =>
              SimpleDialog(title: const Text('Attach document to'), children: [
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(context, ''),
                    child: const Text('This home')),
                for (final system in systems)
                  SimpleDialogOption(
                      onPressed: () =>
                          Navigator.pop(context, '${system['id']}'),
                      child:
                          Text('${system['type']} · ${system['brand'] ?? ''}')),
              ]));
      if (selected == null) return;
      systemId = selected.isEmpty ? null : selected;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final file = await DocumentUpload.pick();
      if (file == null) return;
      // Save newly added systems first so attachments use server IDs.
      for (final system in systems.cast<Map<String, dynamic>>()) {
        if ('${system['id']}' != systemId ||
            int.tryParse(systemId ?? '') != null) continue;
        final saved = await HomeownerService.instance.saveHomeSystem(
            addressId: profile['addressId'] as int, system: system);
        system.addAll(saved);
        systemId = '${saved['id']}';
      }
      final doc = await HomeownerService.instance.uploadHomeFile(
          addressId: profile['addressId'] as int,
          kind: 'document',
          file: file,
          systemId: systemId);
      if (mounted) setState(() => (profile['documents'] as List).add(doc));
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openDocument(Map doc) async {
    try {
      final link = await HomeownerService.instance
          .homeDocumentDownloadUrl(int.parse('${doc['id']}'));
      final uri = Uri.tryParse(link);
      if (uri == null ||
          uri.scheme != 'https' ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('This document could not be opened.');
      }
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Home profile')),
        body: _loading
            ? const SkeletonPage(layout: SkeletonLayout.form)
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Your home profile could not be loaded.'),
                    TextButton(onPressed: _load, child: const Text('Try again'))
                  ]))
                : _addresses.isEmpty
                    ? const Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'Add a saved address in Profile to create your home profile.')))
                    : ListView(padding: const EdgeInsets.all(16), children: [
                        for (final address in _addresses) _address(address)
                      ]),
        bottomNavigationBar: _loading || _error != null || _addresses.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save home profile'),
                    ))),
      ));
  Widget _address(Map<String, dynamic> address) {
    final profile = _profiles['${address['id']}']!;
    final details = profile['propertyDetails'] as Map;
    final notes = profile['accessNotes'] as Map;
    final systems = profile['systems'] as List;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '${address['label'] ?? address['street'] ?? address['line1'] ?? address['address_line1'] ?? 'Home'}',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              const Text('Property details',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final field in {
                'squareFootage': 'Square footage',
                'yearBuilt': 'Year built',
                'bedrooms': 'Bedrooms',
                'bathrooms': 'Bathrooms'
              }.entries)
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextFormField(
                      initialValue: '${details[field.key] ?? ''}',
                      enabled: !_saving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: field.value),
                      onChanged: (value) => details[field.key] = value,
                    )),
              const SizedBox(height: 24),
              const Text('Systems',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              if (systems.isEmpty)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child:
                        Text('Add the systems you want to keep a record of.')),
              for (final system in systems.cast<Map<String, dynamic>>())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      '${system['type'] ?? 'System'} · ${system['brand'] ?? ''}'),
                  subtitle: Text(
                      '${system['model'] ?? ''}\nLast serviced: ${system['lastServicedAt'] ?? 'No completed service recorded'}'),
                  isThreeLine: true,
                  trailing: IconButton(
                      tooltip: 'Edit system',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed:
                          _saving ? null : () => _editSystem(profile, system)),
                ),
              TextButton.icon(
                  onPressed: _saving ? null : () => _editSystem(profile),
                  icon: const Icon(Icons.add),
                  label: const Text('Add system')),
              const SizedBox(height: 16),
              TextFormField(
                  initialValue: '${notes['text'] ?? ''}',
                  enabled: !_saving,
                  maxLines: 4,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                      labelText: 'Getting in',
                      hintText: 'Door, gate or access instructions'),
                  onChanged: (value) => notes['text'] = value),
              const Text(
                  'Only the pro with a confirmed booking at this address may see getting-in notes, until the job closes.',
                  style: TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              const Text('Documents & warranties',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              for (final doc in (profile['documents'] as List).whereType<Map>())
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(
                        '${doc['title'] ?? doc['fileName'] ?? 'Document'}'),
                    subtitle: doc['homeSystemId'] == null
                        ? null
                        : const Text('Attached to a system'),
                    onTap: () => _openDocument(doc)),
              TextButton.icon(
                  onPressed: _saving ? null : () => _uploadDocument(profile),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload document')),
              const Text(
                  'PDF or image, up to 10 MB. Documents are separate from work-order attachments.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            ])));
  }
}

class HomeSystemEditor extends StatefulWidget {
  const HomeSystemEditor({super.key, required this.addressId, this.system});
  final int addressId;
  final Map<String, dynamic>? system;
  @override
  State<HomeSystemEditor> createState() => _HomeSystemEditorState();
}

class _HomeSystemEditorState extends State<HomeSystemEditor> {
  late Map<String, dynamic> _value;
  bool _uploading = false;
  @override
  void initState() {
    super.initState();
    _value = {...?widget.system};
    _value.putIfAbsent(
        'id', () => 'system-${DateTime.now().microsecondsSinceEpoch}');
    final photos = (_value['documents'] as List? ?? [])
        .whereType<Map>()
        .where((d) => d['type'] == 'system_photo');
    if (photos.isNotEmpty) {
      _value['dataPlateDocumentId'] = photos.first['id'];
      _refreshPhoto();
    }
  }

  Future<void> _photo() async {
    setState(() => _uploading = true);
    try {
      final file = await DocumentUpload.pick(imageOnly: true);
      if (file == null) return;
      final saved = await HomeownerService.instance
          .saveHomeSystem(addressId: widget.addressId, system: _value);
      _value.addAll(saved);
      final doc = await HomeownerService.instance.uploadHomeFile(
          addressId: widget.addressId,
          kind: 'data_plate',
          file: file,
          systemId: '${_value['id']}');
      _value['dataPlateDocumentId'] = doc['id'];
      final url = await HomeownerService.instance
          .homeDocumentDownloadUrl(int.parse('${doc['id']}'));
      if (mounted) setState(() => _value['dataPlatePhotoUrl'] = url);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _refreshPhoto() async {
    try {
      final id = _value['dataPlateDocumentId'];
      if (id == null) return;
      final url = await HomeownerService.instance
          .homeDocumentDownloadUrl(int.parse('$id'));
      if (mounted) setState(() => _value['dataPlatePhotoUrl'] = url);
    } catch (e) {
      if (mounted) AppNotification.showError(context, e);
    }
  }

  void _done() {
    if ('${_value['type'] ?? ''}'.trim().isEmpty) {
      AppNotification.showInfo(context, 'Enter a system type.');
      return;
    }
    final raw =
        '${_value['installedYear'] ?? _value['installed_year'] ?? ''}'.trim();
    final year = int.tryParse(raw);
    if (raw.isNotEmpty && (year == null || year < 1600 || year > 2200)) {
      AppNotification.showInfo(context, 'Enter a valid installation year.');
      return;
    }
    _value['installedYear'] = year;
    _value['installed_year'] = year;
    Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) => TransactionGuard(
      isProcessing: _uploading,
      child: Scaffold(
          appBar: AppBar(
              title:
                  Text(widget.system == null ? 'Add system' : 'Edit system')),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButtonFormField<String>(
              value: const [
                'hvac',
                'water_heater',
                'plumbing',
                'electrical',
                'roof',
                'appliances',
                'windows',
                'insulation',
                'solar',
                'pool',
                'other'
              ].contains(_value['type'])
                  ? _value['type'] as String
                  : null,
              decoration: const InputDecoration(labelText: 'System type'),
              items: [
                for (final type in const [
                  'hvac',
                  'water_heater',
                  'plumbing',
                  'electrical',
                  'roof',
                  'appliances',
                  'windows',
                  'insulation',
                  'solar',
                  'pool',
                  'other'
                ])
                  DropdownMenuItem(
                      value: type,
                      child: Text(
                          type == 'hvac' ? 'HVAC' : type.replaceAll('_', ' ')))
              ],
              onChanged: _uploading
                  ? null
                  : (value) => setState(() => _value['type'] = value),
            ),
            const SizedBox(height: 16),
            for (final field in {
              'brand': 'Brand',
              'model': 'Model',
              'installedYear': 'Year installed',
              'location': 'Location in your home',
              'notes': 'Notes'
            }.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    initialValue:
                        '${_value[field.key] ?? (field.key == 'installedYear' ? _value['installed_year'] : null) ?? ''}',
                    enabled: !_uploading,
                    maxLength: field.key == 'notes' ? 2000 : 200,
                    maxLines: field.key == 'notes' ? 3 : 1,
                    keyboardType: field.key == 'installedYear'
                        ? TextInputType.number
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: field.value),
                    onChanged: (text) => _value[field.key] = text.trim(),
                  )),
            Text(
                'Last serviced: ${_value['lastServicedAt'] ?? 'No completed service recorded'}'),
            const Text('Service dates come from completed work orders.'),
            const SizedBox(height: 20),
            if (_value['dataPlatePhotoUrl'] != null)
              Image.network('${_value['dataPlatePhotoUrl']}',
                  height: 180,
                  errorBuilder: (_, __, ___) => TextButton(
                      onPressed: _refreshPhoto,
                      child: const Text('Reload photo preview'))),
            OutlinedButton.icon(
                onPressed: _uploading ? null : _photo,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(
                    _uploading ? 'Uploading…' : 'Upload data-plate photo')),
            const Text(
                'Uploading saves this system first. Keep the sticker as a record and enter its details manually.'),
            const SizedBox(height: 24),
            FilledButton(
                onPressed: _uploading ? null : _done,
                child: const Text('Use these details')),
            const Text(
                'Save the home profile to finish saving system changes.'),
          ])));
}
