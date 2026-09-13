import 'package:flutter_test/flutter_test.dart';
import 'package:homeowners_app/widgets/custom_widgets.dart';

void main() {
  test('browse service icon registry has one clean asset per rail category', () {
    expect(ServiceCategoryIcons.hasUniqueBrowseAssets, isTrue);
    expect(ServiceCategoryIcons.assetFor('HVAC'), endsWith('/7.png'));
    expect(ServiceCategoryIcons.assetFor('Plumbing'), endsWith('/6.png'));
    expect(ServiceCategoryIcons.assetFor('All'), endsWith('/32.png'));
    expect(ServiceCategoryIcons.sourceAssetFor('HVAC'), endsWith('/7.svg'));
  });
}
