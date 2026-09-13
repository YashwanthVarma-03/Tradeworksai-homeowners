import 'package:flutter/material.dart';
import '../theme.dart';

class SunriseBackground extends StatelessWidget {
  final Widget child;
  const SunriseBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(20.0),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class HoverButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final bool isSecondary;

  const HoverButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width = double.infinity,
    this.height = 48.0,
    this.isSecondary = false,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isSecondary) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isHovered
                  ? const [Color(0xFFFFFFFF), Color(0xFFDCE0E5)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF0F2F4)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x280F172A),
                blurRadius: 0,
                spreadRadius: 0.75,
              )
            ],
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Color(0xFF121F31),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) => setState(() => _isHovered = false),
      onTapCancel: () => setState(() => _isHovered = false),
      onTap: widget.onPressed,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: AppTheme.orange500.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          children: [
            // Static Base Solid Orange Color
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9999),
                color: AppTheme.orange500,
              ),
            ),
            // Hover Overlay (Darkens on hover)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isHovered ? 0.15 : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  color: Colors.black,
                ),
              ),
            ),
            // Text Content
            Center(
              child: Text(
                widget.text,
                style: const TextStyle(
                  color: AppTheme.navy700,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryToken {
  final Color color;
  final Color tint;
  final IconData icon;

  const CategoryToken({
    required this.color,
    required this.tint,
    required this.icon,
  });
}

class TradeWorksCategoryTokens {
  static const CategoryToken fallback = CategoryToken(
    color: AppTheme.navy700,
    tint: AppTheme.navyTint,
    icon: Icons.home_repair_service,
  );

  static const Map<String, CategoryToken> all = {
    'All': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.apps,
    ),
    'HVAC': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.ac_unit,
    ),
    'Plumbing': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.plumbing,
    ),
    'Electrical': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.flash_on,
    ),
    'Cleaning': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.cleaning_services,
    ),
    'Roofing': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.roofing,
    ),
    'Landscaping': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.nature_people,
    ),
    'Lawn': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.nature_people,
    ),
    'Handyman': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.build,
    ),
    'Painting': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.format_paint,
    ),
    'Appliance Repair': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.kitchen,
    ),
    'Pool & Spa': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.pool,
    ),
    'Tree Service': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.park,
    ),
    'Pest Control': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.bug_report,
    ),
    'Flooring': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.layers,
    ),
    'Drywall & Plaster': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.texture,
    ),
    'Windows & Doors': CategoryToken(
      color: AppTheme.orange500,
      tint: AppTheme.orangeTint,
      icon: Icons.window,
    ),
    'Garage Doors': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.garage,
    ),
    'Water Treatment': CategoryToken(
      color: AppTheme.navy700,
      tint: AppTheme.navyTint,
      icon: Icons.water_drop,
    ),
    'Guides': CategoryToken(
      color: AppTheme.teal500,
      tint: AppTheme.tealTint,
      icon: Icons.menu_book,
    ),
  };

  static CategoryToken forName(String name) => all[name] ?? fallback;
}

/// The supplied service artwork is deliberately one-to-one with the Browse
/// rail categories. Keep this registry as the single source of truth so a
/// service is never accidentally rendered with another service's icon.
class ServiceCategoryIcons {
  static const String _basePath = 'assets/icons/services';
  static const String _cleanBasePath = '$_basePath/clean';

  static const Map<String, String> _assets = {
    'All': '$_basePath/32.svg',
    'Moving': '$_basePath/1.svg',
    'Appliance Repair': '$_basePath/2.svg',
    'Concrete': '$_basePath/3.svg',
    'Garage Doors': '$_basePath/4.svg',
    'Flooring': '$_basePath/5.svg',
    'Plumbing': '$_basePath/6.svg',
    'HVAC': '$_basePath/7.svg',
    'Electrical': '$_basePath/8.svg',
    'Cleaning': '$_basePath/9.svg',
    'Landscaping': '$_basePath/10.svg',
    'Painting': '$_basePath/11.svg',
    'Water Treatment': '$_basePath/12.svg',
    'Roofing': '$_basePath/13.svg',
    'Windows & Doors': '$_basePath/14.svg',
    'Smart Home': '$_basePath/15.svg',
    'Solar Energy': '$_basePath/16.svg',
    'Tree Service': '$_basePath/17.svg',
    'Pest Control': '$_basePath/18.svg',
    'Home Security': '$_basePath/19.svg',
    'Insulation': '$_basePath/20.svg',
    'Locksmith': '$_basePath/21.svg',
    'Junk Removal': '$_basePath/22.svg',
    'Remodeling': '$_basePath/23.svg',
    'Fencing & Decks': '$_basePath/24.svg',
    'Drywall & Plaster': '$_basePath/25.svg',
    'Gutters': '$_basePath/26.svg',
    'Screen Repair': '$_basePath/27.svg',
    'Pool & Spa': '$_basePath/28.svg',
    'Fireplace & Chimney': '$_basePath/29.svg',
    'Siding': '$_basePath/30.svg',
    'Concrete & Masonry': '$_basePath/31.svg',
  };

  static String? assetFor(String category) => _cleanAssetFor(category);

  static String? sourceAssetFor(String category) =>
      _assets[category == 'All 31' ? 'All' : category];

  static String? _cleanAssetFor(String category) {
    final source = sourceAssetFor(category);
    return source
        ?.replaceFirst(_basePath, _cleanBasePath)
        .replaceFirst('.svg', '.png');
  }

  static bool get hasUniqueBrowseAssets {
    final values = _assets.values.toSet();
    return values.length == _assets.length && _assets.length == 32;
  }

  // The source artwork has varying visual density. These values keep each
  // supplied icon optically balanced within the same tile frame.
  static const Map<String, double> _scales = {
    'All': 0.88,
    'Moving': 0.94,
    'Appliance Repair': 0.98,
    'Concrete': 0.94,
    'Garage Doors': 0.96,
    'Flooring': 0.94,
    'Plumbing': 0.96,
    'HVAC': 0.94,
    'Electrical': 0.98,
    'Cleaning': 0.93,
    'Landscaping': 0.95,
    'Painting': 0.95,
    'Water Treatment': 0.96,
    'Roofing': 0.96,
    'Windows & Doors': 0.94,
    'Smart Home': 0.95,
    'Solar Energy': 0.94,
    'Tree Service': 0.95,
    'Pest Control': 0.94,
    'Home Security': 0.96,
    'Insulation': 0.95,
    'Locksmith': 0.96,
    'Junk Removal': 0.95,
    'Remodeling': 0.94,
    'Fencing & Decks': 0.94,
    'Drywall & Plaster': 0.95,
    'Gutters': 0.96,
    'Screen Repair': 0.94,
    'Pool & Spa': 0.95,
    'Fireplace & Chimney': 0.95,
    'Siding': 0.94,
    'Concrete & Masonry': 0.94,
  };

  static double scaleFor(String category) =>
      _scales[category == 'All 31' ? 'All' : category] ?? 0.95;
}

class ServiceCategoryIcon extends StatelessWidget {
  final String category;
  final double size;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const ServiceCategoryIcon({
    super.key,
    required this.category,
    required this.size,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: '$category service icon',
      child: SizedBox.square(
        dimension: size,
        child: Center(
          child: ExcludeSemantics(
            // The supplied legacy PNG artwork is too fine at mobile sizes.
            // Render the app's Material glyphs instead: they stay crisp across
            // densities and carry a consistent, stronger visual weight.
            child: Transform.scale(
              scale: 1.14,
              child: Icon(
                fallbackIcon,
                color: fallbackColor,
                size: size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TradeWorksCategoryTile extends StatelessWidget {
  final String label;
  final String? meta;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  const TradeWorksCategoryTile({
    super.key,
    required this.label,
    this.meta,
    required this.onTap,
    this.selected = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final token = TradeWorksCategoryTokens.forName(label);
    final background = selected ? token.color : token.tint;
    final foreground = selected ? Colors.white : AppTheme.ink;
    final iconColor = selected ? Colors.white : token.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: width,
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? token.color : token.color.withOpacity(0.12),
            width: selected ? 0 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: token.color.withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.16) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ServiceCategoryIcon(
                category: label,
                size: 28,
                fallbackIcon: token.icon,
                fallbackColor: iconColor,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.15,
              ),
            ),
            if (meta != null) ...[
              const SizedBox(height: 2),
              Text(
                meta!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected ? Colors.white.withOpacity(0.88) : AppTheme.gray,
                  fontWeight: FontWeight.w500,
                  fontSize: 9.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;

  const AnimatedEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.slideOffset = 30.0,
  });

  @override
  State<AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<AnimatedEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnimation =
        Tween<double>(begin: widget.slideOffset, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.translate(
            offset: Offset(0.0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

Route createPremiumRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.08);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;

      var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      var offsetAnimation = animation.drive(tween);

      var fadeTween =
          Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
      var fadeAnimation = animation.drive(fadeTween);

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: offsetAnimation,
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 400),
  );
}

class SegmentItem {
  final String label;
  final int? count;
  const SegmentItem({required this.label, this.count});
}

class SlidingSegmentControl extends StatelessWidget {
  final int currentIndex;
  final List<SegmentItem> items;
  final ValueChanged<int> onSegmentChanged;
  final Color activeColor;

  const SlidingSegmentControl({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onSegmentChanged,
    this.activeColor = const Color(0xFF1B3C6E),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.pageAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.line.withOpacity(0.5)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / items.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                left: currentIndex * width,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: activeColor,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = currentIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSegmentChanged(index),
                        child: Container(
                          color: Colors.transparent,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isSelected ? Colors.white : AppTheme.gray,
                                  fontSize: 12.5,
                                ),
                                child: Text(item.label),
                              ),
                              if (item.count != null && item.count! > 0) ...[
                                const SizedBox(width: 5),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.24)
                                        : AppTheme.line,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    item.count.toString(),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.gray,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
