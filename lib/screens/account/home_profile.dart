import '../../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/homeowner_service.dart';
import '../../services/document_upload.dart';
import '../../theme.dart';
import '../../ui/tw.dart';
import '../../widgets/app_notification.dart';
import '../../widgets/transaction_guard.dart';

class HomeProfileScreen extends StatefulWidget {
  const HomeProfileScreen(
      {super.key, required this.addresses, this.loadProfiles});
  final List<dynamic> addresses;
  @visibleForTesting
  final Future<Map<String, dynamic>> Function()? loadProfiles;
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
      final data = await (widget.loadProfiles?.call() ??
          HomeownerService.instance.fetchHomeProfiles());
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
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      for (final profile in _profiles.values) {
        final details = profile['propertyDetails'] as Map;
        for (final key in details.keys) {
          final raw = (key == 'squareFootage'
                  ? '${details[key] ?? ''}'.replaceAll(',', '')
                  : '${details[key] ?? ''}')
              .trim();
          final number = raw.isEmpty ? null : num.tryParse(raw);
          if (raw.isNotEmpty &&
              (number == null || !number.isFinite || number < 0)) {
            throw Exception('Enter a valid non-negative number for $key.');
          }
          if (key != 'bathrooms' &&
              number != null &&
              number != number.roundToDouble()) {
            throw Exception('Enter a whole number for $key.');
          }
          if (key == 'yearBuilt' &&
              number != null &&
              (number < 1600 ||
                  number > 2200 ||
                  number != number.roundToDouble())) {
            throw Exception('Enter a valid year built.');
          }
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
        appBar: TwAppBar(title: 'Home profile'),
        body: _loading
            ? const SkeletonPage(layout: SkeletonLayout.form)
            : _error != null
                ? Center(
                    child: TwEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Your home profile could not be loaded.',
                      action: TwSecondaryButton(
                        label: 'Try again',
                        onPressed: _load,
                        expand: false,
                      ),
                    ),
                  )
                : _addresses.isEmpty
                    ? const Center(
                        child: TwEmptyState(
                          icon: Icons.home_outlined,
                          title:
                              'Add a saved address in Profile to create your home profile.',
                        ),
                      )
                    : ListView(padding: EdgeInsets.zero, children: [
                        TwPage(
                          top: TwSpace.s20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final address in _addresses)
                                _address(address)
                            ],
                          ),
                        ),
                      ]),
        bottomNavigationBar: _loading || _error != null || _addresses.isEmpty
            ? null
            : TwStickyBar(
                children: [
                  TwPrimaryButton(
                    label: 'Save home profile',
                    loading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
      ));

  /// F05 property details: a 2×2 grid with labels above the fields on
  /// Regular and Wide; one column on Compact.
  Widget _propertyDetails(Map details) {
    Widget field(String key, String label) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TwFieldLabel(label),
            TextFormField(
              initialValue: key == 'squareFootage'
                  ? _squareFootageLabel(details[key])
                  : '${details[key] ?? ''}',
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TwType.body(color: AppTheme.navy),
              decoration: TwInputs.decoration(),
              onChanged: (value) => details[key] = value,
            ),
          ],
        );
    final cells = [
      field('squareFootage', 'Square footage'),
      field('yearBuilt', 'Year built'),
      field('bedrooms', 'Bedrooms'),
      field('bathrooms', 'Bathrooms'),
    ];
    if (TwLayout.size(context) == TwSize.compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(height: TwSpace.s16),
            cells[i],
          ],
        ],
      );
    }
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: TwSpace.s12),
            Expanded(child: b),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        pair(cells[0], cells[1]),
        const SizedBox(height: TwSpace.s16),
        pair(cells[2], cells[3]),
      ],
    );
  }

  /// One hairline system row (F05): title, meta lines, 44 edit target.
  Widget _systemRow(Map<String, dynamic> profile, Map<String, dynamic> system,
      {required bool last}) {
    final meta = [
      [
        _text(system['model']),
        if (_text(system['installedYear']) != null)
          'Installed ${_text(system['installedYear'])}',
      ].whereType<String>().join(' · '),
      'Last serviced: ${_servicedLabel(system['lastServicedAt'])}',
    ].where((part) => part.isNotEmpty).join('\n');
    return Container(
      padding: const EdgeInsets.only(top: TwSpace.s12, bottom: 10),
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
                Text(_systemTitle(system), style: TwType.title()),
                const SizedBox(height: 2),
                Text(meta, style: TwType.meta()),
              ],
            ),
          ),
          IconButton(
              tooltip: 'Edit system',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.edit_outlined,
                  size: 20, color: AppTheme.navy),
              onPressed: _saving ? null : () => _editSystem(profile, system)),
        ],
      ),
    );
  }

  Widget _address(Map<String, dynamic> address) {
    final profile = _profiles['${address['id']}']!;
    final details = profile['propertyDetails'] as Map;
    final notes = profile['accessNotes'] as Map;
    final systems = profile['systems'] as List;
    final documents = (profile['documents'] as List).whereType<Map>().toList();
    final street = _text(
        address['street'] ?? address['line1'] ?? address['address_line1']);
    final cityLine = [
      _text(address['city']),
      [_text(address['state']), _text(address['zip'])]
          .whereType<String>()
          .join(' '),
    ].whereType<String>().where((part) => part.isNotEmpty).join(', ');
    final place = [street, cityLine]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(', ');
    final type = _text(details['propertyType'] ??
        address['propertyType'] ??
        address['homeType']);
    final line = [place, type]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' · ');
    final systemRows = systems.cast<Map<String, dynamic>>().toList();
    return Padding(
        padding: const EdgeInsets.only(bottom: TwSpace.s28),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const TwIconWell(Icons.home_outlined, size: 40),
            const SizedBox(width: TwSpace.s12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_text(address['label']) ?? 'Home', style: TwType.h2()),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(line, style: TwType.meta()),
                    ],
                  ]),
            ),
          ]),
          _sectionHeading('Property details', top: 22, bottom: TwSpace.s12),
          _propertyDetails(details),
          _sectionHeading('Systems', top: 26, bottom: 0),
          if (systems.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: TwSpace.s12),
                child: Text('Add the systems you want to keep a record of.',
                    style: TwType.bodySm(color: AppTheme.textSecondary))),
          for (var i = 0; i < systemRows.length; i++)
            _systemRow(profile, systemRows[i],
                last: i == systemRows.length - 1),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: _saving ? null : () => _editSystem(profile),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add system'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerLeft,
                )),
          ),
          _sectionHeading('Getting in', top: 24, bottom: TwSpace.s12),
          const TwFieldLabel('Door, gate or access instructions'),
          TextFormField(
              initialValue: '${notes['text'] ?? ''}',
              enabled: !_saving,
              minLines: 3,
              maxLines: 4,
              maxLength: 4000,
              style: TwType.body(color: AppTheme.navy),
              decoration: TwInputs.decoration(counterText: ''),
              onChanged: (value) => notes['text'] = value),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.lock_outline_rounded,
                size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                  'Only the pro with a confirmed booking at this address may see getting-in notes, until the job closes.',
                  style: TwType.meta(color: AppTheme.body)),
            ),
          ]),
          _sectionHeading('Documents & warranties'),
          if (documents.isEmpty)
            Text('No documents yet.',
                style: TwType.bodySm(color: AppTheme.textSecondary)),
          for (final doc in documents)
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined,
                    size: 22, color: AppTheme.navy),
                title: Text('${doc['title'] ?? doc['fileName'] ?? 'Document'}',
                    style: TwType.title()),
                subtitle: doc['homeSystemId'] == null
                    ? null
                    : Text('Attached to a system', style: TwType.meta()),
                onTap: () => _openDocument(doc)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: _saving ? null : () => _uploadDocument(profile),
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Upload document'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  alignment: Alignment.centerLeft,
                )),
          ),
          Text(
              'PDF or image, up to 10 MB. Documents are separate from work-order attachments.',
              style: TwType.caption()),
        ]));
  }

  Widget _sectionHeading(String text,
          {double top = TwSpace.s28, double bottom = TwSpace.s4}) =>
      Padding(
        padding: EdgeInsets.only(top: top, bottom: bottom),
        child: Text(text, style: TwType.h2()),
      );

  String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty || text.toLowerCase() == 'null'
        ? null
        : text;
  }

  String _squareFootageLabel(dynamic value) {
    final raw = _text(value) ?? '';
    final area = num.tryParse(raw.replaceAll(',', ''));
    return area == null
        ? raw
        : NumberFormat.decimalPattern('en_US').format(area);
  }

  /// "HVAC · Carrier", "Water heater" — never a raw key or a dangling "·".
  String _systemTitle(Map<String, dynamic> system) {
    final raw = _text(system['type']);
    final type = raw == null
        ? 'System'
        : raw.toLowerCase() == 'hvac'
            ? 'HVAC'
            : '${raw[0].toUpperCase()}${raw.substring(1).replaceAll('_', ' ')}';
    final brand = _text(system['brand']);
    return brand == null ? type : '$type · $brand';
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
          appBar: TwAppBar(
              title: widget.system == null ? 'Add system' : 'Edit system'),
          body: ListView(padding: EdgeInsets.zero, children: [
            TwPage(
              top: TwSpace.s20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const TwFieldLabel('System type'),
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
                    isExpanded: true,
                    style: TwType.body(color: AppTheme.navy),
                    decoration: TwInputs.decoration(),
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
                            child: Text(type == 'hvac'
                                ? 'HVAC'
                                : type.replaceAll('_', ' ')))
                    ],
                    onChanged: _uploading
                        ? null
                        : (value) => setState(() => _value['type'] = value),
                  ),
                  const SizedBox(height: TwSpace.s16),
                  for (final field in {
                    'brand': 'Brand',
                    'model': 'Model',
                    'installedYear': 'Year installed',
                    'location': 'Location in your home',
                    'notes': 'Notes'
                  }.entries)
                    Padding(
                        padding: const EdgeInsets.only(bottom: TwSpace.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TwFieldLabel(field.value),
                            TextFormField(
                              initialValue:
                                  '${_value[field.key] ?? (field.key == 'installedYear' ? _value['installed_year'] : null) ?? ''}',
                              enabled: !_uploading,
                              maxLength: field.key == 'notes' ? 2000 : 200,
                              minLines: field.key == 'notes' ? 3 : 1,
                              maxLines: field.key == 'notes' ? 3 : 1,
                              keyboardType: field.key == 'installedYear'
                                  ? TextInputType.number
                                  : TextInputType.text,
                              style: TwType.body(color: AppTheme.navy),
                              decoration: TwInputs.decoration(counterText: ''),
                              onChanged: (text) =>
                                  _value[field.key] = text.trim(),
                            ),
                          ],
                        )),
                  Text(
                      'Last serviced: ${_servicedLabel(_value['lastServicedAt'])}',
                      style: TwType.bodySm()),
                  const SizedBox(height: TwSpace.s4),
                  Text('Service dates come from completed work orders.',
                      style: TwType.caption()),
                  const SizedBox(height: TwSpace.s20),
                  if (_value['dataPlatePhotoUrl'] != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: Image.network('${_value['dataPlatePhotoUrl']}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Center(
                                  child: TextButton(
                                      onPressed: _refreshPhoto,
                                      child:
                                          const Text('Reload photo preview')),
                                )),
                      ),
                    ),
                    const SizedBox(height: TwSpace.s12),
                  ],
                  OutlinedButton.icon(
                      onPressed: _uploading ? null : _photo,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                      label: Text(_uploading
                          ? 'Uploading…'
                          : 'Upload data-plate photo')),
                  const SizedBox(height: TwSpace.s8),
                  Text(
                      'Uploading saves this system first. Keep the sticker as a record and enter its details manually.',
                      style: TwType.caption()),
                  const SizedBox(height: TwSpace.s28),
                  TwPrimaryButton(
                      label: 'Use these details',
                      onPressed: _uploading ? null : _done),
                  const SizedBox(height: TwSpace.s8),
                  Text('Save the home profile to finish saving system changes.',
                      textAlign: TextAlign.center, style: TwType.caption()),
                ],
              ),
            ),
          ])));
}

/// "Mar 4, 2025" for an ISO timestamp; the raw value if it isn't a date;
/// the empty-state sentence when nothing is recorded (F05).
String _servicedLabel(dynamic raw) {
  final text = raw?.toString().trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') {
    return 'No completed service recorded';
  }
  final date = DateTime.tryParse(text);
  return date == null ? text : DateFormat('MMM d, yyyy').format(date.toLocal());
}
