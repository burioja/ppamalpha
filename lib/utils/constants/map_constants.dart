// Map-specific constants
class MapConstants {
  // Default map settings
  static const double defaultZoom = 15.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;

  // Fog of War settings
  static const int fogTileSize = 256;
  static const double visitRadiusMeters = 50.0;

  // Marker settings
  static const double defaultMarkerSize = 40.0;
  static const double selectedMarkerSize = 50.0;

  // Performance settings
  static const int maxMarkersPerView = 100;
  static const int tileCacheSize = 1000;
}