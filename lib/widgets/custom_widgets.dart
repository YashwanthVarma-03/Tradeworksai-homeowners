import 'package:flutter/material.dart';
import '../theme.dart';
import '../ui/tw.dart';

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
    this.borderRadius = 14.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        // v3.3 cards: hairline only, no shadow.
        border: Border.all(color: AppTheme.cardBorder, width: 1.0),
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

/// v3.3: delegates to the kit buttons — orange with a navy label (primary)
/// or white with a #D0D5DD border (secondary), radius 12, no shadow.
class _HoverButtonState extends State<HoverButton> {
  @override
  Widget build(BuildContext context) {
    final Widget button = widget.isSecondary
        ? TwSecondaryButton(
            label: widget.text,
            onPressed: widget.onPressed,
            height: widget.height,
          )
        : TwPrimaryButton(
            label: widget.text,
            onPressed: widget.onPressed,
          );
    return SizedBox(width: widget.width, child: button);
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

/// v3.3: category icons are ink outline glyphs on a neutral fill. They are
/// never tinted by category (no teal/blue per-category colour).
class TradeWorksCategoryTokens {
  static const CategoryToken fallback = CategoryToken(
    color: AppTheme.navy,
    tint: AppTheme.subtle,
    icon: Icons.home_repair_service_outlined,
  );

  static const Map<String, CategoryToken> all = {
    'All': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.apps_outlined,
    ),
    'HVAC': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.ac_unit_outlined,
    ),
    'Plumbing': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.plumbing_outlined,
    ),
    'Electrical': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.flash_on_outlined,
    ),
    'Cleaning': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.cleaning_services_outlined,
    ),
    'Roofing': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.roofing_outlined,
    ),
    'Landscaping': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.nature_people_outlined,
    ),
    'Lawn': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.nature_people_outlined,
    ),
    'Handyman': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.build_outlined,
    ),
    'Painting': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.format_paint_outlined,
    ),
    'Appliance Repair': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.kitchen_outlined,
    ),
    'Pool & Spa': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.pool_outlined,
    ),
    'Tree Service': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.park_outlined,
    ),
    'Pest Control': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.bug_report_outlined,
    ),
    'Flooring': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.layers_outlined,
    ),
    'Drywall & Plaster': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.texture_outlined,
    ),
    'Windows & Doors': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.window_outlined,
    ),
    'Garage Doors': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.garage_outlined,
    ),
    'Water Treatment': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.water_drop_outlined,
    ),
    'Guides': CategoryToken(
      color: AppTheme.navy,
      tint: AppTheme.subtle,
      icon: Icons.menu_book_outlined,
    ),
  };

  static CategoryToken forName(String name) => all[name] ?? fallback;
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
            child: Icon(
              fallbackIcon,
              color: fallbackColor,
              size: size,
            ),
          ),
        ),
      ),
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
    this.activeColor = AppTheme.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.subtle,
        borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppTheme.cardBorder),
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
                                  fontFamily: AppTheme.fontInter,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.navy
                                      : AppTheme.body,
                                  fontSize: 14,
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
                                    color: AppTheme.blueTint,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    item.count.toString(),
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontInter,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.blue,
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
