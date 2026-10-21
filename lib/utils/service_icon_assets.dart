/// Original TradeWorks artwork, keyed by the public catalogue's category slugs.
class ServiceIconAssets {
  ServiceIconAssets._();

  static const _slugs = {
    'handyman-general-repairs',
    'hvac',
    'air-duct-vent-services',
    'plumbing',
    'electrical',
    'appliance-repair',
    'pool-spa',
    'landscaping-lawn-care',
    'tree-service',
    'pest-control',
    'cleaning',
    'pressure-washing-exterior-cleaning',
    'flooring',
    'painting',
    'drywall-plaster',
    'roofing',
    'gutters',
    'siding',
    'windows-doors',
    'screen-repair-enclosures',
    'garage-doors',
    'locksmith',
    'junk-removal-hauling',
    'moving-hauling',
    'fencing-decks',
    'concrete-masonry',
    'remodeling-construction',
    'home-security-smart-home',
    'insulation-weatherization',
    'water-treatment',
    'fireplace-chimney',
  };

  // Compact labels used by Browse and the Home category shortcuts.
  static const _aliases = {
    'handyman': 'handyman-general-repairs',
    'air-duct-vent': 'air-duct-vent-services',
    'landscaping': 'landscaping-lawn-care',
    'lawn': 'landscaping-lawn-care',
    'pressure-washing': 'pressure-washing-exterior-cleaning',
    'screen-repair': 'screen-repair-enclosures',
    'moving': 'moving-hauling',
    'junk-removal': 'junk-removal-hauling',
    'remodeling': 'remodeling-construction',
    'home-security': 'home-security-smart-home',
    'smart-home': 'home-security-smart-home',
    'insulation': 'insulation-weatherization',
  };

  static String? forCategory(String category) {
    final normalized = category
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final slug = _aliases[normalized] ?? normalized;
    return _slugs.contains(slug)
        ? 'assets/icons/services/tradeworks/$slug.svg'
        : null;
  }
}
