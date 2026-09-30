import '../widgets/loading_skeleton.dart';
import 'package:flutter/material.dart';

import '../services/homeowner_service.dart';
import '../theme.dart';
import '../widgets/offline_state.dart';

/// Side-by-side comparison of two or three pros.
///
/// The rules this screen exists to honour:
///
///  * **Equal columns.** No pro is wider, first-by-default, highlighted,
///    badged or marked as recommended. Order is the order they were added.
///  * **Identical actions.** Every column gets the same three controls, in the
///    same order, with the same styling.
///  * **No score.** No composite rating, no "best value", no winner. The
///    homeowner compares; TradeWorks does not.
///  * **Missing data says so.** A blank cell reads "Not listed" — never greyed
///    out, never hidden, never filled with a guess.
///  * **Identical values are shown normally.** No greying, no "same", no
///    differences-only toggle. If two pros both charge $149, both cells say
///    $149 in the same ink.
///
/// Matches the web portal's compare view row for row, so a homeowner who uses
/// both surfaces sees the same comparison.
class CompareProsScreen extends StatefulWidget {
  /// Contractor ids, in the order the homeowner added them. Two or three.
  final List<String> contractorIds;

  /// What they were searching for, shown as context under the title.
  final String? serviceLabel;
  final String? zip;

  const CompareProsScreen({
    super.key,
    required this.contractorIds,
    this.serviceLabel,
    this.zip,
  });

  @override
  State<CompareProsScreen> createState() => _CompareProsScreenState();
}

class _CompareProsScreenState extends State<CompareProsScreen> {
  /// The eight rows, in this order, identical to the web.
  static const List<_Row> _rows = [
    _Row('rating', 'Rating'),
    _Row('price', 'Upfront price'),
    _Row('response', 'Response tiers'),
    _Row('licensed', 'Licensed & insured'),
    _Row('background', 'Background checked'),
    _Row('years', 'Years in business'),
    _Row('availability', 'Availability'),
    _Row('work', 'Recent work'),
  ];

  late List<String> _ids;
  List<Map<String, dynamic>>? _profiles;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _ids = List<String>.from(widget.contractorIds);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Compare fetches full profiles. The search-results payload is
      // deliberately light and does not carry licence, insurance, background
      // check, years in business or the response-tier table.
      final fetched = await Future.wait(
        _ids.map((id) => HomeownerService.instance.fetchContractorProfile(id)),
      );
      if (!mounted) return;
      setState(() {
        // The public endpoint envelopes its allow-listed fields in `profile`.
        _profiles = fetched.map((response) {
          final profile = response['profile'];
          if (profile is! Map) {
            throw const FormatException('Contractor profile is missing');
          }
          return Map<String, dynamic>.from(profile);
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _remove(int index) {
    if (_ids.length <= 2) {
      // Below two there is nothing to compare. Close rather than show a
      // one-column table pretending to be a comparison.
      Navigator.pop(context);
      return;
    }
    setState(() {
      _ids.removeAt(index);
      _profiles!.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.pageBackground,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Close comparison',
          icon: const Icon(Icons.close_rounded, color: AppTheme.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compare ${_ids.length} pros',
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppTheme.cardBorder),
        ),
      ),
      body: _isLoading
          ? const SkeletonPage(layout: SkeletonLayout.cards)
          : _error != null
              ? OfflineState(onRetry: _load, message: _error)
              : _table(),
    );
  }

  Widget _table() {
    final profiles = _profiles!;
    // Two pros fit the screen. Three needs horizontal room, so the whole
    // table scrolls sideways with a fixed-width label column.
    final wide = profiles.length > 2;

    return Column(
      children: [
        _contextLine(),
        Expanded(
          child: wide
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 132 + profiles.length * 150,
                    child: _grid(),
                  ),
                )
              : _grid(),
        ),
      ],
    );
  }

  Widget _contextLine() {
    final parts = <String>[
      if (widget.serviceLabel?.trim().isNotEmpty == true)
        widget.serviceLabel!.trim(),
      if (widget.zip?.trim().isNotEmpty == true) widget.zip!.trim(),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: const TextStyle(
                color: AppTheme.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 2),
          const Text(
            'No score, no ranking. You choose.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    final profiles = _profiles!;
    final scroller = SingleChildScrollView(
      child: Column(
        children: [
          for (final row in _rows) _attributeRow(row, profiles),
          _actionsRow(profiles),
          const SizedBox(height: 28),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headerRow(profiles),
        // The header stays put; only the attributes scroll.
        Expanded(child: scroller),
      ],
    );
  }

  Widget _headerRow(List<Map<String, dynamic>> profiles) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.pageBackground,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 132),
          for (var i = 0; i < profiles.length; i++)
            Expanded(child: _proHeader(profiles[i], i)),
        ],
      ),
    );
  }

  Widget _proHeader(Map<String, dynamic> profile, int index) {
    final name = _str(profile['business_name']) ??
        _str(profile['businessName']) ??
        'Pro';
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              tooltip: 'Remove $name from comparison',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppTheme.textSecondary),
              onPressed: () => _remove(index),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.navy,
            child: Text(
              _initials(name),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 3,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 13,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attributeRow(_Row row, List<Map<String, dynamic>> profiles) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Text(
                row.label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final profile in profiles)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
                child: _cell(row.key, profile),
              ),
            ),
        ],
      ),
    );
  }

  /// Every value is rendered in the same ink at the same weight, whether or
  /// not another column matches it. Nothing is greyed for being the same.
  Widget _cell(String key, Map<String, dynamic> profile) {
    final value = _value(key, profile);
    if (value.text == null) {
      return const Text(
        'Not listed',
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
      );
    }
    const style = TextStyle(
      color: AppTheme.navy,
      fontSize: 13,
      height: 1.35,
      fontWeight: FontWeight.w600,
    );
    if (value.glyph == null) return Text(value.text!, style: style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.glyph!,
          style: TextStyle(
            color: value.glyphColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(child: Text(value.text!, style: style)),
      ],
    );
  }

  /// Values match the web portal's `compareValue()` exactly, so the same pro
  /// reads the same on both surfaces. Do not "improve" a format here without
  /// changing the portal in the same pass.
  _CellValue _value(String key, Map<String, dynamic> p) {
    final badges = _map(p['badges']);
    final creds = _map(p['credentials']);
    final em = _map(p['emergency']);

    switch (key) {
      case 'rating':
        final agg = _map(_map(p['reviews'])['verified_aggregate']);
        final rating = _num(agg['avg_rating']);
        if (rating == null) return const _CellValue.text('No reviews yet');
        final count = _num(agg['count']);
        return _CellValue.star(
          '${rating.toStringAsFixed(1)}'
          '${count != null && count > 0 ? ' (${count.toInt()} reviews)' : ''}',
        );

      case 'price':
        final svc = _firstPricedService(p);
        final amount = _num(svc['rate_amount']);
        if (amount != null) return _CellValue.text(_money(amount));
        return _CellValue.maybe(_str(svc['rate_label']));

      case 'response':
        // All three tiers always show. A tier the pro has not set up reads
        // "not offered" rather than being hidden — on a comparison screen the
        // absence IS the useful fact. (Booking behaves differently: there an
        // unoffered tier does not render at all.)
        final urgentOffered = em['urgent_available'] == true ||
            _str(em['avg_urgent_response']) != null ||
            em['urgent_fee'] != null;
        final emergencyOffered = em['available'] == true ||
            _str(em['avg_emergency_response']) != null ||
            em['emergency_fee'] != null;
        String tier(String label, String window, dynamic fee, bool offered,
            {bool plus = true}) {
          if (!offered) return '$label $window · not offered';
          final amount = _num(fee);
          if (amount == null) return '$label $window · included';
          return '$label $window · ${plus ? '+' : ''}${_money(amount)}';
        }

        return _CellValue.text([
          tier('Standard', _str(em['standard_response']) ?? '48h',
              em['standard_fee'], true,
              plus: false),
          tier('Urgent', _str(em['avg_urgent_response']) ?? '24h',
              em['urgent_fee'], urgentOffered),
          tier('Emergency', _str(em['avg_emergency_response']) ?? '4h',
              em['emergency_fee'], emergencyOffered),
        ].join('\n'));

      case 'licensed':
        final license = _map(creds['license']);
        final parts = <String>[];
        if (badges['license_verified'] == true || creds['license'] != null) {
          final number = _str(license['number']);
          parts.add(number == null ? 'Licensed' : 'Licensed $number');
        }
        if (badges['insured'] == true || creds['insured'] == true) {
          parts.add('Insured');
        }
        return _CellValue.maybe(parts.isEmpty ? null : parts.join('\n'));

      case 'background':
        final checked = badges['background_checked'] == true ||
            creds['background_checked'] == true;
        return checked
            ? const _CellValue.check('Yes')
            : const _CellValue.none();

      case 'years':
        final years = _num(p['years_in_business'] ?? p['yearsInBusiness']);
        return _CellValue.maybe(
            years == null ? null : '${years.toInt()} years');

      case 'availability':
        // Coverage, not a next-free-slot. A slot would be stale by the time
        // the homeowner read it, and compare is not a booking screen.
        final zip = widget.zip?.trim();
        return _CellValue.text(zip == null || zip.isEmpty
            ? 'Accepting bookings'
            : 'Accepting bookings in $zip');

      case 'work':
        final photos = _num(p['photoCount'] ?? p['photo_count']) ??
            _num(_list(p['photos']).length);
        if (photos == null || photos == 0) return const _CellValue.none();
        final n = photos.toInt();
        return _CellValue.text('$n photo${n == 1 ? '' : 's'}');

      default:
        return const _CellValue.none();
    }
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static List<dynamic> _list(dynamic v) => v is List ? v : const [];

  static Map<String, dynamic> _firstPricedService(Map<String, dynamic> p) {
    for (final raw in _list(p['services'])) {
      final svc = _map(raw);
      if (_num(svc['rate_amount']) != null || _str(svc['rate_label']) != null) {
        return svc;
      }
    }
    return const {};
  }

  static String _money(double amount) =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  /// Identical controls, identical order, identical styling in every column.
  /// Nothing here may differ between pros.
  Widget _actionsRow(List<Map<String, dynamic>> profiles) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 132),
          for (final profile in profiles)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    // Book is the page-level primary action, so it is orange —
                    // but it appears once per column, identically. See the
                    // note in the brief: this is the one screen where the
                    // one-orange-control rule is deliberately a per-column
                    // rule instead.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _book(profile),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.orange,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w900),
                        ),
                        child: const Text('Book'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _message(profile),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.navy,
                          side: const BorderSide(color: AppTheme.navy),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          textStyle: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                        child: const Text('Message'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => _openProfile(profile),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.navy,
                        minimumSize: const Size(44, 44),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Full profile'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Wire these three to the existing routes — see the brief, Part D.
  void _book(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'book', 'profile': profile});
  void _message(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'message', 'profile': profile});
  void _openProfile(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'profile', 'profile': profile});

  static String? _str(dynamic v) {
    final t = v?.toString().trim();
    if (t == null || t.isEmpty || t.toLowerCase() == 'null') return null;
    return t;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String)
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
    return null;
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }
}

/// A cell's value, plus an optional leading glyph. The star is the only place
/// gold appears in the app; the tick is the only place green does here.
class _CellValue {
  final String? text;
  final String? glyph;
  final Color glyphColor;

  const _CellValue.text(this.text)
      : glyph = null,
        glyphColor = AppTheme.navy;
  const _CellValue.none()
      : text = null,
        glyph = null,
        glyphColor = AppTheme.navy;
  const _CellValue.star(this.text)
      : glyph = '\u2605',
        glyphColor = AppTheme.gold;
  const _CellValue.check(this.text)
      : glyph = '\u2713',
        glyphColor = AppTheme.green;

  factory _CellValue.maybe(String? value) =>
      value == null ? const _CellValue.none() : _CellValue.text(value);
}

class _Row {
  final String key;
  final String label;
  const _Row(this.key, this.label);
}
