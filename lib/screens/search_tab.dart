import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../services/stream_service.dart';
import '../widgets/custom_widgets.dart';
import '../services/homeowner_service.dart';
import 'chat_screen.dart';
import 'pro_profile.dart';

class SearchTab extends StatefulWidget {
  final Function(Map<String, String>) onBookPro;
  final String? initialSearchQuery;
  final String? initialCategory;

  const SearchTab({
    key,
    required this.onBookPro,
    this.initialSearchQuery,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final TextEditingController _searchController;
  final TextEditingController _zipController = TextEditingController(text: '');
  late String _activeCategoryFilter;

  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _searchResults = [];

  double? _maxDistanceFilter;
  double? _minRatingFilter;
  String? _priceTypeFilter; // 'rate_card' or 'quote_request'

  List<dynamic> get _filteredResults {
    return _searchResults.where((pro) {
      if (_minRatingFilter != null) {
        final rating = (pro['verifiedRating'] as num?)?.toDouble() ?? 5.0;
        if (rating < _minRatingFilter!) return false;
      }
      if (_maxDistanceFilter != null) {
        final dist = (pro['distanceMiles'] as num?)?.toDouble();
        if (dist != null && dist > _maxDistanceFilter!) return false;
      }
      if (_priceTypeFilter != null) {
        if (pro['workOrderType'] != _priceTypeFilter) return false;
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchQuery ?? '');
    _activeCategoryFilter = widget.initialCategory ?? 'All';
    _initializeDefaultZipAndSearch();
  }

  Future<void> _initializeDefaultZipAndSearch() async {
    try {
      List<dynamic> addresses = HomeownerService.instance.cachedAddresses ?? [];
      if (addresses.isEmpty) {
        final data = await HomeownerService.instance.fetchProfile();
        addresses = (data['addresses'] as List?) ??
            (data['profile']?['addresses'] as List?) ??
            [];
      }

      final defaultAddr = addresses.firstWhere(
          (a) => a['isDefault'] == true || a['isDefault'] == 'true',
          orElse: () => addresses.isNotEmpty ? addresses.first : null);
      if (defaultAddr != null && defaultAddr['zip'] != null) {
        _zipController.text = defaultAddr['zip'].toString();
      } else {
        _zipController.text = '33569';
      }
    } catch (e) {
      _zipController.text = '33569';
    }
    _performSearch();
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool shouldSearch = false;
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      _searchController.text = widget.initialSearchQuery ?? '';
      shouldSearch = true;
    }
    if (widget.initialCategory != oldWidget.initialCategory) {
      _activeCategoryFilter = widget.initialCategory ?? 'All';
      shouldSearch = true;
    }
    if (shouldSearch) {
      _performSearch();
    }
  }

  String getCategorySlug(String categoryName) {
    return categoryName
        .toLowerCase()
        .replaceAll(' & ', '-')
        .replaceAll(' ', '-');
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final zip = _zipController.text.trim();
      String category = _activeCategoryFilter;

      // If "All" is selected but the search bar has a query, check keywords
      if (category == 'All' && _searchController.text.isNotEmpty) {
        final query = _searchController.text.toLowerCase();
        for (final entry in categoryKeywords.entries) {
          final catName = entry.key;
          final keywords = entry.value;
          if (keywords.any((kw) => query.contains(kw) || kw.contains(query))) {
            category = catName;
            break;
          }
        }
      }

      // If category is "All", default to "hvac" for public pro listing
      final categorySlug =
          category == 'All' ? 'hvac' : getCategorySlug(category);

      final data = await HomeownerService.instance.searchPros(
        zip: zip.isNotEmpty ? zip : '33569',
        categorySlug: categorySlug,
      );

      if (mounted) {
        setState(() {
          var rawResults = data['results'];
          if (rawResults is List) {
            _searchResults = rawResults;
          } else if (rawResults is Map) {
            _searchResults = rawResults.values.toList();
          } else {
            _searchResults = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  static const List<Map<String, dynamic>> _categories = [
    {'name': 'All', 'icon': Icons.all_out},
    {'name': 'Plumbing', 'icon': Icons.plumbing},
    {'name': 'HVAC', 'icon': Icons.ac_unit},
    {'name': 'Handyman', 'icon': Icons.build},
    {'name': 'Landscaping', 'icon': Icons.nature_people},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services},
    {'name': 'Electrical', 'icon': Icons.flash_on},
    {'name': 'Appliance Repair', 'icon': Icons.kitchen},
    {'name': 'Pool & Spa', 'icon': Icons.pool},
    {'name': 'Tree Service', 'icon': Icons.park},
    {'name': 'Pest Control', 'icon': Icons.bug_report},
    {'name': 'Flooring', 'icon': Icons.layers},
    {'name': 'Painting', 'icon': Icons.format_paint},
    {'name': 'Drywall & Plaster', 'icon': Icons.texture},
    {'name': 'Roofing', 'icon': Icons.roofing},
    {'name': 'Gutters', 'icon': Icons.waves},
    {'name': 'Siding', 'icon': Icons.home_work},
    {'name': 'Windows & Doors', 'icon': Icons.window},
    {'name': 'Screen Repair', 'icon': Icons.grid_on},
    {'name': 'Garage Doors', 'icon': Icons.garage},
    {'name': 'Locksmith', 'icon': Icons.lock},
    {'name': 'Junk Removal', 'icon': Icons.delete_outline},
    {'name': 'Moving', 'icon': Icons.local_shipping},
    {'name': 'Fencing & Decks', 'icon': Icons.fence},
    {'name': 'Concrete & Masonry', 'icon': Icons.foundation},
    {'name': 'Remodeling', 'icon': Icons.construction},
    {'name': 'Home Security', 'icon': Icons.security},
    {'name': 'Insulation', 'icon': Icons.wb_shade},
    {'name': 'Water Treatment', 'icon': Icons.water_drop},
    {'name': 'Fireplace & Chimney', 'icon': Icons.fireplace},
    {'name': 'Solar Energy', 'icon': Icons.solar_power},
    {'name': 'Smart Home', 'icon': Icons.settings_remote},
  ];

  static const Map<String, List<String>> categoryKeywords = {
    'Plumbing': [
      'pipe',
      'drain',
      'leak',
      'toilet',
      'clog',
      'faucet',
      'sink',
      'plumber',
      'shower',
      'water heater'
    ],
    'HVAC': [
      'ac',
      'heating',
      'hvac',
      'cool',
      'heat',
      'air conditioning',
      'furnace',
      'vent',
      'thermostat'
    ],
    'Handyman': [
      'tv',
      'mount',
      'furniture',
      'assembly',
      'fixture',
      'doorbell',
      'shelf',
      'hang',
      'repair'
    ],
    'Landscaping': [
      'lawn',
      'grass',
      'mow',
      'garden',
      'sprinkler',
      'sod',
      'weed',
      'landscaper',
      'yard'
    ],
    'Cleaning': [
      'clean',
      'maid',
      'wash',
      'dust',
      'vacuum',
      'housekeeping',
      'deep clean'
    ],
    'Electrical': [
      'wire',
      'outlet',
      'light',
      'switch',
      'ev charger',
      'breaker',
      'electrician',
      'wiring'
    ],
    'Appliance Repair': [
      'fridge',
      'refrigerator',
      'stove',
      'oven',
      'dishwasher',
      'washer',
      'dryer',
      'freezer'
    ],
    'Pool & Spa': [
      'pool',
      'spa',
      'jacuzzi',
      'chlorine',
      'pump',
      'pool cleaning'
    ],
    'Tree Service': ['tree', 'branch', 'stump', 'trim', 'arborist', 'cutting'],
    'Pest Control': [
      'bug',
      'pest',
      'termite',
      'ant',
      'roach',
      'spider',
      'exterminator',
      'flea',
      'tick'
    ],
    'Flooring': [
      'floor',
      'tile',
      'hardwood',
      'carpet',
      'laminate',
      'vinyl',
      'plank'
    ],
    'Painting': [
      'paint',
      'wall',
      'stain',
      'brush',
      'roller',
      'painter',
      'exterior',
      'interior'
    ],
    'Drywall & Plaster': [
      'drywall',
      'plaster',
      'patch',
      'sheetrock',
      'spackle'
    ],
    'Roofing': ['roof', 'shingle', 'leak', 'tile', 'roofing', 'roofer'],
    'Gutters': ['gutter', 'downspout', 'leaf', 'guards'],
    'Siding': ['siding', 'vinyl siding', 'stucco', 'wood siding'],
    'Windows & Doors': [
      'window',
      'door',
      'entry',
      'sliding',
      'pane',
      'storm door'
    ],
    'Screen Repair': ['screen', 'lanai', 'mesh', 'patio', 'window screen'],
    'Garage Doors': ['garage', 'overhead', 'spring', 'opener', 'garage door'],
    'Locksmith': ['lock', 'key', 'deadbolt', 'lockout', 'smart lock', 'rekey'],
    'Junk Removal': ['junk', 'trash', 'debris', 'removal', 'haul', 'clutter'],
    'Moving': ['move', 'pack', 'truck', 'relocate', 'movers', 'loading'],
    'Fencing & Decks': ['fence', 'gate', 'deck', 'wood', 'vinyl', 'railing'],
    'Concrete & Masonry': [
      'concrete',
      'brick',
      'masonry',
      'paver',
      'driveway',
      'patio',
      'sidewalk'
    ],
    'Remodeling': [
      'remodel',
      'kitchen',
      'bathroom',
      'renovate',
      'addition',
      'contractor'
    ],
    'Home Security': ['security', 'alarm', 'camera', 'cctv', 'ring', 'safe'],
    'Insulation': ['insulation', 'attic', 'fiberglass', 'blown-in'],
    'Water Treatment': [
      'water',
      'filter',
      'softener',
      'reverse osmosis',
      'purification'
    ],
    'Fireplace & Chimney': [
      'fireplace',
      'chimney',
      'hearth',
      'soot',
      'sweep',
      'flue'
    ],
    'Solar Energy': ['solar', 'panel', 'sun', 'pv'],
    'Smart Home': [
      'smart',
      'automation',
      'alexa',
      'nest',
      'home automation',
      'hub'
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchHeader(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              AnimatedEntrance(
                delay: const Duration(milliseconds: 50),
                child: _buildCategoryScroll(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Vetted Pros Available (${_searchResults.length})',
                    style: AppTheme.textTheme.headlineMedium
                        ?.copyWith(fontSize: 16),
                  ),
                  const Text('Sort: Highest Rated',
                      style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.orange500),
                  ),
                )
              else if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.error),
                      const SizedBox(height: 12),
                      Text(_errorMessage!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              else if (_filteredResults.isEmpty)
                _buildEmptyState()
              else
                ..._filteredResults.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pro = entry.value;
                  return AnimatedEntrance(
                    key: ValueKey(
                        '${pro['contractorId']}_${_searchController.text}_$_activeCategoryFilter'),
                    delay: Duration(milliseconds: idx < 3 ? idx * 30 : 0),
                    child: _buildProCard(pro),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader() {
    final hasActiveFilters = _maxDistanceFilter != null ||
        _minRatingFilter != null ||
        _priceTypeFilter != null;
    int filterCount = 0;
    if (_maxDistanceFilter != null) filterCount++;
    if (_minRatingFilter != null) filterCount++;
    if (_priceTypeFilter != null) filterCount++;

    final useWireframeHeader = true;
    if (useWireframeHeader) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: AppTheme.pageAlt,
          border: Border(bottom: BorderSide(color: AppTheme.line)),
        ),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (val) => setState(() {}),
              onSubmitted: (val) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'Search a service or pro',
                prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(23),
                  borderSide: const BorderSide(color: AppTheme.line, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(23),
                  borderSide:
                      const BorderSide(color: AppTheme.orange500, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 9),
            TextField(
              controller: _zipController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (val) => _performSearch(),
              decoration: InputDecoration(
                hintText: 'ZIP code',
                prefixIcon:
                    const Icon(Icons.location_on_outlined, color: AppTheme.gray),
                suffixIcon: IconButton(
                  tooltip: 'Search this area',
                  onPressed: _performSearch,
                  icon: const Icon(Icons.arrow_forward,
                      color: AppTheme.navy700, size: 20),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(23),
                  borderSide: const BorderSide(color: AppTheme.line, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(23),
                  borderSide:
                      const BorderSide(color: AppTheme.orange500, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            onSubmitted: (val) => _performSearch(),
            decoration: InputDecoration(
              hintText: 'What service do you need? (e.g. HVAC, pipe)',
              prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
              filled: true,
              fillColor: AppTheme.pageAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zipController,
                  keyboardType: TextInputType.number,
                  onSubmitted: (val) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'ZIP Code',
                    prefixIcon: const Icon(Icons.location_on,
                        color: AppTheme.gray, size: 20),
                    filled: true,
                    fillColor: AppTheme.pageAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _showFiltersBottomSheet,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: hasActiveFilters
                        ? AppTheme.orange500
                        : AppTheme.tealTint,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: hasActiveFilters
                        ? [
                            BoxShadow(
                              color: AppTheme.orange500.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          color: hasActiveFilters
                              ? Colors.white
                              : AppTheme.teal700,
                          size: 20),
                      const SizedBox(width: 6),
                      Text(
                        hasActiveFilters ? 'Filters ($filterCount)' : 'Filters',
                        style: TextStyle(
                          color: hasActiveFilters
                              ? Colors.white
                              : AppTheme.teal700,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCategoryScroll() {
    final useWireframeRail = true;
    if (useWireframeRail) {
      return SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final name = cat['name'] as String;
            final isSel = name == _activeCategoryFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TradeWorksCategoryTile(
                label: name,
                meta: index == 0 ? '${_filteredResults.length} pros' : 'services',
                selected: isSel,
                width: 88,
                onTap: () {
                  setState(() => _activeCategoryFilter = name);
                  _performSearch();
                },
              ),
            );
          },
        ),
      );
    }

    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSel = cat['name'] == _activeCategoryFilter;

          return GestureDetector(
            onTap: () {
              setState(() {
                _activeCategoryFilter = cat['name'];
              });
              _performSearch();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF1B3C6E) : AppTheme.pageAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSel
                        ? Colors.transparent
                        : AppTheme.line.withOpacity(0.3)),
                boxShadow: isSel
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1B3C6E).withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    cat['icon'] as IconData,
                    color: isSel ? Colors.white : AppTheme.navy700,
                    size: 22,
                  ),
                  const SizedBox(height: 6),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      color: isSel ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                    child: Text(cat['name']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProCard(Map<String, dynamic> pro) {
    final businessName = pro['businessName'] ?? 'Service Pro';
    final isNew = pro['isNew'] == true;
    final badgeText = isNew ? 'New Pro' : 'Vetted & Insured';
    final nextAvailable = pro['nextAvailable'] ?? 'Next Week';
    final workOrderType = pro['workOrderType'] == 'quote_request'
        ? 'Free estimate'
        : 'Upfront price';
    final rating = pro['verifiedRating'] != null
        ? pro['verifiedRating'].toString()
        : '5.0';
    final reviewsCount =
        pro['verifiedCount'] != null ? pro['verifiedCount'].toString() : '0';

    final priceLabel = pro['fromPrice'] != null
        ? 'From \$${pro['fromPrice'].toString()}'
        : workOrderType;
    final messageUserId = StreamService.instance.resolveMessagingUserId(
      Map<String, dynamic>.from(pro),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.line, width: 0.5),
      ),
      child: InkWell(
        onTap: () async {
          final booked = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProProfileScreen(pro: pro)),
          );
          if (booked == true && context.mounted) {
            // We want to pass this up to the BrowseScreen which will pass it to dashboard_shell
            // Wait! If SearchTab is not a Navigator itself, popping here will pop SearchTab?
            // Actually, BrowseScreen contains SearchTab, but they are in the same Navigator scope if SearchTab is just a widget in BrowseScreen.
            // But what if SearchTab is inside the main IndexedStack?
            // If it's inside the IndexedStack (like the actual SearchTab in dashboard_shell wasn't, wait it WAS?)
            // Oh, dashboard_shell doesn't use SearchTab directly in tabs, it uses BrowseScreen! Wait.
            // If we are in BrowseScreen, popping BrowseScreen returns to DashboardShell.
            Navigator.pop(context, true);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (pro['photoUrl'] != null &&
                  pro['photoUrl'].toString().isNotEmpty) ...[
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(pro['photoUrl'].toString()),
                  backgroundColor: AppTheme.navyTint,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            businessName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.tealTint,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isNew ? badgeText : 'Select-certified',
                            style: const TextStyle(
                              color: AppTheme.teal700,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$workOrderType - Available: $nextAvailable',
                      style:
                          const TextStyle(color: AppTheme.gray, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '$rating - $reviewsCount completed work orders',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceLabel,
                    style: AppTheme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.orange500,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final booked = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProProfileScreen(pro: pro)),
                      );
                      if (booked == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange500,
                      foregroundColor: AppTheme.navy700,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: const Text('View profile',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () async {
                      if (!AuthService.instance.isAuthenticated) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please sign in to message this contractor.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      if (messageUserId == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Chat is coming soon for this contractor.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            contractorId: messageUserId,
                            contractorName: businessName.toString(),
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.line),
                      foregroundColor: AppTheme.navy700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Message',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40.0),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 48, color: AppTheme.gray),
          SizedBox(height: 12),
          Text('No pros found',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 4),
          Text('Try adjusting your filters or keyword query.',
              style: TextStyle(color: AppTheme.gray, fontSize: 12)),
        ],
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        double? selectedDist = _maxDistanceFilter;
        double? selectedRating = _minRatingFilter;
        String? selectedPrice = _priceTypeFilter;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pros',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppTheme.navy700),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            selectedDist = null;
                            selectedRating = null;
                            selectedPrice = null;
                          });
                        },
                        child: const Text('Reset All',
                            style: TextStyle(color: AppTheme.orange500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance Filter
                  const Text('Distance',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Any distance',
                        selected: selectedDist == null,
                        onTap: () => setSheetState(() => selectedDist = null),
                      ),
                      _buildFilterChip(
                        label: 'Within 5 miles',
                        selected: selectedDist == 5.0,
                        onTap: () => setSheetState(() => selectedDist = 5.0),
                      ),
                      _buildFilterChip(
                        label: 'Within 15 miles',
                        selected: selectedDist == 15.0,
                        onTap: () => setSheetState(() => selectedDist = 15.0),
                      ),
                      _buildFilterChip(
                        label: 'Within 25 miles',
                        selected: selectedDist == 25.0,
                        onTap: () => setSheetState(() => selectedDist = 25.0),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Rating Filter
                  const Text('Minimum Rating',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All ratings',
                        selected: selectedRating == null,
                        onTap: () => setSheetState(() => selectedRating = null),
                      ),
                      _buildFilterChip(
                        label: '4.5+ Stars',
                        selected: selectedRating == 4.5,
                        onTap: () => setSheetState(() => selectedRating = 4.5),
                      ),
                      _buildFilterChip(
                        label: '4.8+ Stars',
                        selected: selectedRating == 4.8,
                        onTap: () => setSheetState(() => selectedRating = 4.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price Type Filter
                  const Text('Pricing Type',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'All pricing',
                        selected: selectedPrice == null,
                        onTap: () => setSheetState(() => selectedPrice = null),
                      ),
                      _buildFilterChip(
                        label: 'Upfront price',
                        selected: selectedPrice == 'rate_card',
                        onTap: () =>
                            setSheetState(() => selectedPrice = 'rate_card'),
                      ),
                      _buildFilterChip(
                        label: 'Free estimate',
                        selected: selectedPrice == 'quote_request',
                        onTap: () => setSheetState(
                            () => selectedPrice = 'quote_request'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _maxDistanceFilter = selectedDist;
                          _minRatingFilter = selectedRating;
                          _priceTypeFilter = selectedPrice;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.orange500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Apply Filters',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip(
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.navy700,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        backgroundColor: selected ? const Color(0xFF1B3C6E) : AppTheme.pageAlt,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: selected
                  ? Colors.transparent
                  : AppTheme.line.withOpacity(0.3)),
        ),
      ),
    );
  }
}
