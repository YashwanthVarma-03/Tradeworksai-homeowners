import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets/custom_widgets.dart';

class SearchTab extends StatefulWidget {
  final Function(Map<String, String>) onBookPro;
  final String? initialSearchQuery;
  final String? initialCategory;

  const SearchTab({
    super.key,
    required this.onBookPro,
    this.initialSearchQuery,
    this.initialCategory,
  });

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  late final TextEditingController _searchController;
  final TextEditingController _zipController = TextEditingController(text: '33569');
  late String _activeCategoryFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchQuery ?? '');
    _activeCategoryFilter = widget.initialCategory ?? 'All';
  }

  @override
  void didUpdateWidget(SearchTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      _searchController.text = widget.initialSearchQuery ?? '';
    }
    if (widget.initialCategory != oldWidget.initialCategory) {
      _activeCategoryFilter = widget.initialCategory ?? 'All';
    }
  }

  // Category list covering all 31 official categories plus "All"
  final List<Map<String, dynamic>> _categories = [
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

  // Mock list of pros representing multiple categories
  final List<Map<String, String>> _allPros = [
    {
      'name': 'Dave Miller',
      'trade': 'Licensed HVAC Technician',
      'company': 'Miller Cool Air & Heating',
      'rating': '4.9',
      'reviews': '148',
      'price': '\$85/hr',
      'category': 'HVAC',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Sarah Jenkins',
      'trade': 'Master Plumber',
      'company': 'Jenkins Plumbing Group',
      'rating': '4.8',
      'reviews': '92',
      'price': '\$90/hr',
      'category': 'Plumbing',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Marcus Vance',
      'trade': 'General Handyman',
      'company': 'Vance Home Services',
      'rating': '4.9',
      'reviews': '310',
      'price': '\$60/hr',
      'category': 'Handyman',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'GreenLawn Care',
      'trade': 'Lawn Maintenance Pro',
      'company': 'GreenLawn Tampa Corp',
      'rating': '4.7',
      'reviews': '412',
      'price': '\$40/hr',
      'category': 'Landscaping',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'MaidShine Cleaning',
      'trade': 'Home Clean Specialist',
      'company': 'MaidShine Services Inc',
      'rating': '4.8',
      'reviews': '280',
      'price': '\$110 Fixed',
      'category': 'Cleaning',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Elena Rostova',
      'trade': 'Licensed Electrician',
      'company': 'Apex Electrical Services',
      'rating': '4.9',
      'reviews': '175',
      'price': '\$95/hr',
      'category': 'Electrical',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Appliance Masters',
      'trade': 'Appliance Repair Technician',
      'company': 'Tampa Bay Appliance Repair',
      'rating': '4.8',
      'reviews': '210',
      'price': '\$75/hr',
      'category': 'Appliance Repair',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'ClearWater Pool Care',
      'trade': 'Certified Pool Technician',
      'company': 'ClearWater Pools & Spas',
      'rating': '4.9',
      'reviews': '88',
      'price': '\$80 Fixed',
      'category': 'Pool & Spa',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Stump & Branch Tree Co.',
      'trade': 'Licensed Arborist',
      'company': 'Stump & Branch Tree Care',
      'rating': '4.7',
      'reviews': '134',
      'price': '\$120/hr',
      'category': 'Tree Service',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Shield Pest Control',
      'trade': 'Certified Pest Specialist',
      'company': 'Shield Pest & Termite Control',
      'rating': '4.9',
      'reviews': '340',
      'price': '\$70 Fixed',
      'category': 'Pest Control',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Elite Flooring & Tile',
      'trade': 'Flooring Installation Pro',
      'company': 'Elite Floors LLC',
      'rating': '4.8',
      'reviews': '156',
      'price': '\$85/hr',
      'category': 'Flooring',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Apex Painting Pros',
      'trade': 'Professional Painter',
      'company': 'Apex Painting Contractors',
      'rating': '4.8',
      'reviews': '194',
      'price': '\$50/hr',
      'category': 'Painting',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'SecureLock Locksmith',
      'trade': 'Mobile Locksmith',
      'company': 'SecureLock & Key Services',
      'rating': '4.9',
      'reviews': '420',
      'price': '\$65 Fixed',
      'category': 'Locksmith',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'EcoJunk Haulers',
      'trade': 'Junk Removal Specialist',
      'company': 'EcoJunk Hauling Tampa',
      'rating': '4.7',
      'reviews': '258',
      'price': '\$95 Fixed',
      'category': 'Junk Removal',
      'badge': 'Vetted & Insured',
    },
    {
      'name': 'Overhead Garage Doctor',
      'trade': 'Garage Door Technician',
      'company': 'Overhead Garage Door Pros',
      'rating': '4.9',
      'reviews': '182',
      'price': '\$90/hr',
      'category': 'Garage Doors',
      'badge': 'Vetted & Insured',
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Advanced keyword matching map for the search bar
    final Map<String, List<String>> categoryKeywords = {
      'Plumbing': ['pipe', 'drain', 'leak', 'toilet', 'clog', 'faucet', 'sink', 'plumber', 'shower', 'water heater'],
      'HVAC': ['ac', 'heating', 'hvac', 'cool', 'heat', 'air conditioning', 'furnace', 'vent', 'thermostat'],
      'Handyman': ['tv', 'mount', 'furniture', 'assembly', 'fixture', 'doorbell', 'shelf', 'hang', 'repair'],
      'Landscaping': ['lawn', 'grass', 'mow', 'garden', 'sprinkler', 'sod', 'weed', 'landscaper', 'yard'],
      'Cleaning': ['clean', 'maid', 'wash', 'dust', 'vacuum', 'housekeeping', 'deep clean'],
      'Electrical': ['wire', 'outlet', 'light', 'switch', 'ev charger', 'breaker', 'electrician', 'wiring'],
      'Appliance Repair': ['fridge', 'refrigerator', 'stove', 'oven', 'dishwasher', 'washer', 'dryer', 'freezer'],
      'Pool & Spa': ['pool', 'spa', 'jacuzzi', 'chlorine', 'pump', 'pool cleaning'],
      'Tree Service': ['tree', 'branch', 'stump', 'trim', 'arborist', 'cutting'],
      'Pest Control': ['bug', 'pest', 'termite', 'ant', 'roach', 'spider', 'exterminator', 'flea', 'tick'],
      'Flooring': ['floor', 'tile', 'hardwood', 'carpet', 'laminate', 'vinyl', 'plank'],
      'Painting': ['paint', 'wall', 'stain', 'brush', 'roller', 'painter', 'exterior', 'interior'],
      'Drywall & Plaster': ['drywall', 'plaster', 'patch', 'sheetrock', 'spackle'],
      'Roofing': ['roof', 'shingle', 'leak', 'tile', 'roofing', 'roofer'],
      'Gutters': ['gutter', 'downspout', 'leaf', 'guards'],
      'Siding': ['siding', 'vinyl siding', 'stucco', 'wood siding'],
      'Windows & Doors': ['window', 'door', 'entry', 'sliding', 'pane', 'storm door'],
      'Screen Repair': ['screen', 'lanai', 'mesh', 'patio', 'window screen'],
      'Garage Doors': ['garage', 'overhead', 'spring', 'opener', 'garage door'],
      'Locksmith': ['lock', 'key', 'deadbolt', 'lockout', 'smart lock', 'rekey'],
      'Junk Removal': ['junk', 'trash', 'debris', 'removal', 'haul', 'clutter'],
      'Moving': ['move', 'pack', 'truck', 'relocate', 'movers', 'loading'],
      'Fencing & Decks': ['fence', 'gate', 'deck', 'wood', 'vinyl', 'railing'],
      'Concrete & Masonry': ['concrete', 'brick', 'masonry', 'paver', 'driveway', 'patio', 'sidewalk'],
      'Remodeling': ['remodel', 'kitchen', 'bathroom', 'renovate', 'addition', 'contractor'],
      'Home Security': ['security', 'alarm', 'camera', 'cctv', 'ring', 'safe'],
      'Insulation': ['insulation', 'attic', 'fiberglass', 'blown-in'],
      'Water Treatment': ['water', 'filter', 'softener', 'reverse osmosis', 'purification'],
      'Fireplace & Chimney': ['fireplace', 'chimney', 'hearth', 'soot', 'sweep', 'flue'],
      'Solar Energy': ['solar', 'panel', 'sun', 'pv'],
      'Smart Home': ['smart', 'automation', 'alexa', 'nest', 'home automation', 'hub'],
    };

    // Filter pros
    final filteredPros = _allPros.where((pro) {
      final matchesCat = _activeCategoryFilter == 'All' || pro['category'] == _activeCategoryFilter;
      
      final query = _searchController.text.toLowerCase().trim();
      if (query.isEmpty) return matchesCat;

      // 1. Check direct matches on name, trade, company, category
      final directMatch = pro['name']!.toLowerCase().contains(query) ||
          pro['trade']!.toLowerCase().contains(query) ||
          pro['company']!.toLowerCase().contains(query) ||
          pro['category']!.toLowerCase().contains(query);

      if (directMatch) return matchesCat;

      // 2. Check keyword mapping for this pro's category
      final proCat = pro['category']!;
      final keywords = categoryKeywords[proCat];
      if (keywords != null) {
        for (final kw in keywords) {
          if (query.contains(kw) || kw.contains(query)) {
            return matchesCat;
          }
        }
      }

      return false;
    }).toList();

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
                    'Vetted Pros Available (${filteredPros.length})',
                    style: AppTheme.textTheme.headlineMedium?.copyWith(fontSize: 16),
                  ),
                  const Text('Sort: Highest Rated', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),
              if (filteredPros.isEmpty)
                _buildEmptyState()
              else
                ...filteredPros.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final pro = entry.value;
                  return AnimatedEntrance(
                    key: ValueKey('${pro['name']}_${_searchController.text}_$_activeCategoryFilter'),
                    delay: Duration(milliseconds: idx * 80),
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'What service do you need? (e.g. HVAC, pipe)',
              prefixIcon: const Icon(Icons.search, color: AppTheme.gray),
              filled: true,
              fillColor: AppTheme.pageAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _zipController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'ZIP Code',
                    prefixIcon: const Icon(Icons.location_on, color: AppTheme.gray, size: 20),
                    filled: true,
                    fillColor: AppTheme.pageAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.tealTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.filter_list, color: AppTheme.teal700, size: 20),
                    SizedBox(width: 6),
                    Text('Filters', style: TextStyle(color: AppTheme.teal700, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCategoryScroll() {
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
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 12),
              width: 80,
              decoration: BoxDecoration(
                color: isSel ? AppTheme.navy700 : AppTheme.pageAlt,
                borderRadius: BorderRadius.circular(16),
                border: isSel ? null : Border.all(color: AppTheme.line.withOpacity(0.3)),
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
                  Text(
                    cat['name'],
                    style: TextStyle(
                      color: isSel ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProCard(Map<String, String> pro) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.line, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pro['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.tealTint,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          pro['badge']!,
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
                    '${pro['trade']} • ${pro['company']}',
                    style: const TextStyle(color: AppTheme.gray, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${pro['rating']} (${pro['reviews']} verified jobs)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pro['price']!,
                  style: AppTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.orange500,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => widget.onBookPro(pro),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.orange500,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            )
          ],
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
          Text('No pros found', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          SizedBox(height: 4),
          Text('Try adjusting your filters or keyword query.', style: TextStyle(color: AppTheme.gray, fontSize: 12)),
        ],
      ),
    );
  }
}
