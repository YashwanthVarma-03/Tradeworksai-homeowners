import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/homeowner_service.dart';
import '../theme.dart';
import '../utils/display_format.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/offline_state.dart';

/// Compare two or three pros (B03; Oct 1 G-48).
///
/// The rules this screen exists to honour:
///
///  * **Equal columns.** Each attribute's label sits above two or three equal
///    columns, so three pros fit a phone without scrolling sideways. No pro is
///    wider, highlighted, badged or marked as recommended. Order is the order
///    they were added.
///  * **Identical actions.** Every column gets the same three controls, in the
///    same order, with the same styling.
///  * **No score.** No composite rating, no "best value", no winner.
///  * **Missing data says so.** A blank cell reads "Not listed".
///  * **Identical values are shown normally.** No greying, no "same".
///  * **The searched service's price.** The Price row is the price of the
///    service the homeowner searched, worded by its work-order type —
///    "$89.00 / diagnostic · You approve the cap", "$165.00 / Upfront price",
///    "Free visit / The pro sends you an estimate".
class CompareProsScreen extends StatefulWidget {
  /// Contractor ids, in the order the homeowner added them. Two or three.
  final List<String> contractorIds;

  /// The service they searched ("AC repair"), shown under the title and used
  /// to pick each pro's price.
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
  /// The seven rows, in this order (B03).
  static const List<_Row> _rows = [
    _Row('rating', 'Rating'),
    _Row('price', 'Price'),
    _Row('response', 'Response times'),
    _Row('licensed', 'Licensed & insured'),
    _Row('background', 'Background checked'),
    _Row('years', 'Years in business'),
    _Row('work', 'Recent work'),
  ];

  static const double _gap = 8;

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
      // check, years in business or the response-time table.
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
      // Below two there is nothing to compare.
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Close comparison',
          icon: const Icon(Icons.close_rounded, color: AppTheme.navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Compare ${_ids.length} pros',
          style: GoogleFonts.outfit(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.cardBorder),
        ),
      ),
      body: _isLoading
          ? const SkeletonPage(layout: SkeletonLayout.cards)
          : _error != null
              ? OfflineState(onRetry: _load, message: _error)
              : _body(),
    );
  }

  Widget _body() {
    final profiles = _profiles!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _contextLine(),
        // The pro names stay put; only the attributes scroll.
        _headerRow(profiles),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final row in _rows) _attributeRow(row, profiles),
                _actionsRow(profiles),
              ],
            ),
          ),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 2),
          const Text(
            'No score, no ranking. You choose.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  /// Equal columns with a gap between them — the same grid for the header,
  /// every row and the actions.
  Widget _columns(List<Widget> cells) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Expanded(child: cells[i]),
        ],
      ],
    );
  }

  Widget _headerRow(List<Map<String, dynamic>> profiles) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: _columns([
        for (var i = 0; i < profiles.length; i++) _proHeader(profiles[i], i),
      ]),
    );
  }

  Widget _proHeader(Map<String, dynamic> profile, int index) {
    final name = _nameOf(profile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: Text(
                _initials(name),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Remove $name from comparison',
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppTheme.textSecondary),
              onPressed: () => _remove(index),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          name,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: AppTheme.navy,
            fontSize: 15,
            height: 1.27,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// The label sits above the columns (B03), not in a column of its own.
  Widget _attributeRow(_Row row, List<Map<String, dynamic>> profiles) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _columns([
            for (final profile in profiles) _cell(row.key, profile),
          ]),
        ],
      ),
    );
  }

  static const TextStyle _value = TextStyle(
    color: AppTheme.navy,
    fontSize: 14,
    height: 1.43,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle _meta = TextStyle(
    color: AppTheme.textSecondary,
    fontSize: 13,
    height: 1.38,
  );
  static const Widget _notListed = Text(
    'Not listed',
    style: TextStyle(color: AppTheme.textTertiary, fontSize: 14, height: 1.43),
  );

  /// Every value is rendered in the same ink at the same weight, whether or
  /// not another column matches it.
  Widget _cell(String key, Map<String, dynamic> p) {
    final badges = _map(p['badges']);
    final creds = _map(p['credentials']);
    final em = _map(p['emergency']);

    switch (key) {
      case 'rating':
        final agg = _map(_map(p['reviews'])['verified_aggregate']);
        final rating = _num(agg['avg_rating']);
        if (rating == null) return const Text('No reviews yet', style: _meta);
        final count = _num(agg['count'])?.toInt() ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.star_rounded, size: 16, color: AppTheme.gold),
              const SizedBox(width: 4),
              Text(rating.toStringAsFixed(1), style: _value),
            ]),
            if (count > 0)
              Text('($count review${count == 1 ? '' : 's'})', style: _meta),
          ],
        );

      case 'price':
        final price = _priceFor(p);
        if (price == null) return _notListed;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              price.headline,
              style: GoogleFonts.outfit(
                color: AppTheme.navy,
                fontSize: 17,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(price.note, style: _meta),
          ],
        );

      case 'response':
        // All three tiers always show. A tier the pro has not set up — or set
        // up with no fee (Oct 1: Urgent and Emergency need a fee) — reads
        // "Not offered"; on a comparison screen the absence is the useful
        // fact. Standard carries no fee line.
        final urgentFee = _num(em['urgent_fee']);
        final emergencyFee = _num(em['emergency_fee']);
        final urgentOffered =
            urgentFee != null && em['urgent_available'] != false;
        final emergencyOffered =
            emergencyFee != null && em['available'] != false;
        Widget tier(String label, String window, double? fee, bool offered) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$label $window', style: _value),
                Text(
                  offered ? '+${_money(fee!)}' : 'Not offered',
                  style: _value.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Standard ${_str(em['standard_response']) ?? '48h'}',
                style: _value),
            const SizedBox(height: 8),
            tier('Urgent', _str(em['avg_urgent_response']) ?? '24h', urgentFee,
                urgentOffered),
            const SizedBox(height: 8),
            tier('Emergency', _str(em['avg_emergency_response']) ?? '4h',
                emergencyFee, emergencyOffered),
          ],
        );

      case 'licensed':
        final parts = <String>[
          if (badges['license_verified'] == true || creds['license'] != null)
            'Licensed',
          if (badges['insured'] == true || creds['insured'] == true) 'Insured',
        ];
        if (parts.isEmpty) return _notListed;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final part in parts) Text(part, style: _value)],
        );

      case 'background':
        final checked = badges['background_checked'] == true ||
            creds['background_checked'] == true;
        if (!checked) return _notListed;
        return const Row(children: [
          Icon(Icons.check_rounded, size: 16, color: AppTheme.greenMark),
          SizedBox(width: 4),
          Text('Yes', style: _value),
        ]);

      case 'years':
        final years = _num(p['years_in_business'] ?? p['yearsInBusiness']);
        if (years == null) return _notListed;
        final n = years.toInt();
        return Text('$n year${n == 1 ? '' : 's'}', style: _value);

      case 'work':
        final photos = _num(p['photoCount'] ?? p['photo_count']) ??
            _num(_list(p['photos']).length);
        if (photos == null || photos == 0) return _notListed;
        final n = photos.toInt();
        return Text('$n photo${n == 1 ? '' : 's'}', style: _value);

      default:
        return _notListed;
    }
  }

  /// The searched service's price, worded by its work-order type
  /// (decisions §1). Falls back to the pro's first priced service — and then
  /// names it, so a different service is never passed off as the searched one.
  _Price? _priceFor(Map<String, dynamic> p) {
    final services = _list(p['services']).map(_map).toList();
    String nameOf(Map<String, dynamic> svc) =>
        (_str(svc['name']) ?? _str(svc['service_name']) ?? '').toLowerCase();
    bool priced(Map<String, dynamic> svc) =>
        _num(svc['rate_amount']) != null || _typeOf(svc) == 'quote_request';

    final wanted = widget.serviceLabel?.trim().toLowerCase() ?? '';
    Map<String, dynamic>? svc;
    if (wanted.isNotEmpty) {
      for (final s in services) {
        if (nameOf(s) == wanted && priced(s)) {
          svc = s;
          break;
        }
      }
      svc ??= services.cast<Map<String, dynamic>?>().firstWhere(
            (s) =>
                priced(s!) &&
                nameOf(s).isNotEmpty &&
                (nameOf(s).contains(wanted) || wanted.contains(nameOf(s))),
            orElse: () => null,
          );
    }
    final matched = svc != null;
    svc ??= services.cast<Map<String, dynamic>?>().firstWhere(
          (s) => priced(s!),
          orElse: () => null,
        );
    if (svc == null) return null;

    final type = _typeOf(svc);
    final amount = _num(svc['rate_amount']);
    final headline = type == 'quote_request'
        ? 'Free visit'
        : (amount == null ? null : formatUsd(amount));
    if (headline == null) return null;
    final typeNote = switch (type) {
      'nte' => 'diagnostic · You approve the cap',
      'quote_request' => 'The pro sends you an estimate',
      _ => 'Upfront price',
    };
    final serviceName = _str(svc['name']) ?? _str(svc['service_name']);
    final note = matched || wanted.isEmpty || serviceName == null
        ? typeNote
        : '$serviceName · $typeNote';
    return _Price(headline, note);
  }

  static String _typeOf(Map<String, dynamic> svc) =>
      _str(svc['work_order_type']) ?? _str(svc['workOrderType']) ?? 'rate_card';

  /// Identical controls, identical order, identical styling in every column.
  /// Book is orange once per column — the one screen where the
  /// one-orange-control rule is deliberately per column.
  Widget _actionsRow(List<Map<String, dynamic>> profiles) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: _columns([
        for (final profile in profiles)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: () => _book(profile),
                child: Semantics(
                  label: 'Book ${_nameOf(profile)}',
                  excludeSemantics: true,
                  child: const Text('Book'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _message(profile),
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4)),
                child: Semantics(
                  label: 'Message ${_nameOf(profile)}',
                  excludeSemantics: true,
                  child: const Text('Message'),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _openProfile(profile),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: Semantics(
                  label: 'Full profile, ${_nameOf(profile)}',
                  excludeSemantics: true,
                  child: const Text('Full profile'),
                ),
              ),
            ],
          ),
      ]),
    );
  }

  void _book(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'book', 'profile': profile});
  void _message(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'message', 'profile': profile});
  void _openProfile(Map<String, dynamic> profile) =>
      Navigator.pop(context, {'action': 'profile', 'profile': profile});

  static String _nameOf(Map<String, dynamic> profile) =>
      _str(profile['business_name']) ?? _str(profile['businessName']) ?? 'Pro';

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static List<dynamic> _list(dynamic v) => v is List ? v : const [];

  /// Urgency fees as the pro set them: "+$35", "+$12.50".
  static String _money(double amount) =>
      '\$${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)}';

  static String? _str(dynamic v) {
    final t = v?.toString().trim();
    if (t == null || t.isEmpty || t.toLowerCase() == 'null') return null;
    return t;
  }

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.replaceAll(RegExp(r'[^0-9.]'), ''));
    }
    return null;
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'P';
    return parts.map((p) => p[0]).take(2).join().toUpperCase();
  }
}

class _Price {
  final String headline;
  final String note;
  const _Price(this.headline, this.note);
}

class _Row {
  final String key;
  final String label;
  const _Row(this.key, this.label);
}
