/// Normalizes the two rewards schemas returned by the live homeowner API.
/// Policy amounts always come from the response, never from UI constants.
Map<String, dynamic> normalizeRewards(Map<String, dynamic> data) {
  List<Map<String, dynamic>> rows(dynamic value) => value is List
      ? value.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : [];
  final program = data['program'] is Map ? data['program'] as Map : const {};
  var bands = rows(data['earningBands']);
  if (bands.isEmpty) bands = rows(data['bands'] ?? program['bands']);
  bands = bands
      .map((band) => <String, dynamic>{
            ...band,
            'floor': band['floor'] ?? band['from'],
            'ceiling': band['ceiling'] ?? band['upTo'],
          })
      .toList();
  final ledger = rows(data['ledger']);
  final milestones = rows(data['milestones'] ?? program['milestones']).map((m) {
    final threshold = m['threshold'] ?? m['at'];
    final awards = ledger.where((r) =>
        r['type'] == 'milestone_bonus' &&
        r['milestoneThreshold'] == threshold &&
        (m['reachedAt'] == null || r['createdAt'] == m['reachedAt']));
    return <String, dynamic>{
      ...m,
      'threshold': threshold,
      'amount': m['amount'] ?? m['bonus'],
      'expiresAt':
          m['expiresAt'] ?? (awards.isEmpty ? null : awards.first['expiresAt']),
    };
  }).toList();
  return {...data, 'bands': bands, 'milestones': milestones};
}
