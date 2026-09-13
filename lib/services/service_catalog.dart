/// The homeowner-facing services offered by the app.
///
/// Keep every entry here so the home shortcut, full service list, and search
/// suggestions stay in agreement as services are added or retired.
class ServiceCatalogItem {
  final String name;
  final String category;

  const ServiceCatalogItem(this.name, this.category);
}

class ServiceCatalog {
  static const List<ServiceCatalogItem> items = [
    ServiceCatalogItem('AC repair', 'HVAC'),
    ServiceCatalogItem('Drain cleaning', 'Plumbing'),
    ServiceCatalogItem('Water heater replacement', 'Plumbing'),
    ServiceCatalogItem('Ceiling fan install', 'Electrical'),
    ServiceCatalogItem('Fence repair', 'Fencing & Decks'),
    ServiceCatalogItem('Interior painting', 'Painting'),
    ServiceCatalogItem('Lawn maintenance', 'Landscaping'),
    ServiceCatalogItem('Smart thermostat install', 'HVAC'),
    ServiceCatalogItem('Plumbing', 'Plumbing'),
    ServiceCatalogItem('Electrical', 'Electrical'),
    ServiceCatalogItem('Cleaning', 'Cleaning'),
    ServiceCatalogItem('Roofing', 'Roofing'),
    ServiceCatalogItem('Handyman', 'Handyman'),
    ServiceCatalogItem('Appliance repair', 'Appliance Repair'),
    ServiceCatalogItem('Pool & spa', 'Pool & Spa'),
    ServiceCatalogItem('Tree service', 'Tree Service'),
    ServiceCatalogItem('Pest control', 'Pest Control'),
    ServiceCatalogItem('Flooring', 'Flooring'),
    ServiceCatalogItem('Drywall & plaster', 'Drywall & Plaster'),
    ServiceCatalogItem('Windows & doors', 'Windows & Doors'),
    ServiceCatalogItem('Garage doors', 'Garage Doors'),
    ServiceCatalogItem('Water treatment', 'Water Treatment'),
  ];

  static List<String> get names =>
      List<String>.unmodifiable(items.map((service) => service.name));
}
