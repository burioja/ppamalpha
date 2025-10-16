import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';

// Handler imports
import '../handlers/map_fog_handler.dart';
import '../handlers/map_marker_handler.dart';
import '../handlers/map_post_handler.dart';
import '../handlers/map_location_handler.dart';

// Widget imports
import '../widgets/map_main_widget.dart';

/// 깔끔하게 리팩토링된 지도 화면
class MapScreen extends StatefulWidget {
  final Function(String)? onAddressChanged;
  final VoidCallback? onNavigateToInbox;

  const MapScreen({
    super.key,
    this.onAddressChanged,
    this.onNavigateToInbox,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // ==================== 핸들러 ====================
  late MapLocationHandler _locationHandler;
  late MapFogHandler _fogHandler;
  late MapMarkerHandler _markerHandler;
  late MapPostHandler _postHandler;

  // ==================== 핵심 상태 ====================
  MapController? _mapController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeHandlers();
    _initialize();
  }

  void _initializeHandlers() {
    _locationHandler = MapLocationHandler();
    _fogHandler = MapFogHandler();
    _markerHandler = MapMarkerHandler();
    _postHandler = MapPostHandler();
  }

  Future<void> _initialize() async {
    _mapController = MapController();
    await _locationHandler.initialize();
    await _fogHandler.initialize();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _locationHandler.dispose();
    _fogHandler.dispose();
    _markerHandler.dispose();
    _postHandler.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: MapMainWidget(
        mapController: _mapController!,
        locationHandler: _locationHandler,
        fogHandler: _fogHandler,
        markerHandler: _markerHandler,
        postHandler: _postHandler,
        onAddressChanged: widget.onAddressChanged,
        onNavigateToInbox: widget.onNavigateToInbox,
      ),
    );
  }
}

