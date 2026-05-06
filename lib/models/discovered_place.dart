class DiscoveredPlace {
  const DiscoveredPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.placeType,
    this.population,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String placeType;
  final int? population;
}
