class MapBounds {
  static const maxPlaceLookupLatitudeSpan = 2.6;
  static const maxPlaceLookupLongitudeSpan = 2.6;

  const MapBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  double get latitudeSpan => (north - south).abs();
  double get longitudeSpan => (east - west).abs();

    bool get isTooBroadForPlaceLookup =>
      latitudeSpan > maxPlaceLookupLatitudeSpan ||
      longitudeSpan > maxPlaceLookupLongitudeSpan;
  bool get isTooBroadForUrbanSignalLookup =>
      latitudeSpan > 1.2 || longitudeSpan > 1.2;
}
