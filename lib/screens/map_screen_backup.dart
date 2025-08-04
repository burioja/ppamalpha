import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


/// ??ë§ˆì»¤ ?„ì´???´ë˜??class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl; // ?´ë?ì§€ URL ì¶”ê?
  final int remainingAmount; // ?¨ì? ?˜ëŸ‰
  final DateTime? expiryDate; // ë§Œë£Œ ? ì§œ

  MarkerItem({
    required this.id,
    required this.title,
    required this.price,
    required this.amount,
    required this.userId,
    required this.data,
    required this.position,
    this.imageUrl,
    required this.remainingAmount,
    this.expiryDate,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);
  static final GlobalKey<_MapScreenState> mapKey = GlobalKey<_MapScreenState>();

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  final String _googleApiKey = "YOUR_API_KEY"; // ë°”ê¿”ì¤?  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  final Set<Marker> _markers = {};
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // ë§ˆì»¤ ê´€??ë³€?˜ë“¤
  final List<MarkerItem> _markerItems = [];
  double _currentZoom = 15.0;
  final Set<Marker> _clusteredMarkers = {};
  bool _isClustered = false;

  @override
  void initState() {
    super.initState();
    _setInitialLocation();
    _loadMapStyle();
    _loadCustomMarker();
    _loadMarkersFromFirestore();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
    }
  }

  Future<void> _setInitialLocation() async {
    try {
      Position? position = await LocationService.getCurrentPosition();
      setState(() {
        _currentPosition = position != null
            ? LatLng(position.latitude, position.longitude)
            : const LatLng(37.495872, 127.025046);
      });
    } catch (_) {
      _currentPosition = const LatLng(37.492894, 127.012469);
    }
  }

  Future<void> _loadCustomMarker() async {
    try {
      // ?´ë?ì§€ ?Œì¼??ë°”ì´?¸ë¡œ ë¡œë“œ
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // ?´ë?ì§€ë¥?ì½”ë“œë¡??”ì½”??      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      // ?í•˜???¬ê¸°ë¡?ë¦¬ì‚¬?´ì¦ˆ (?????¬ê¸°)
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // ë§ˆì»¤ ?¬ê¸°ë¥?200x200?¼ë¡œ ?¤ì •?˜ê³  ?µì»¤ ?¬ì¸??ê³ ë ¤
      final double targetSize = 48.0;
      final Rect rect = Rect.fromLTWH(0, 0, targetSize, targetSize);
      
      // ?´ë?ì§€ ë¹„ìœ¨ ? ì??˜ë©´??ì¤‘ì•™ ?•ë ¬
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        // ?´ë?ì§€ê°€ ???“ìŒ - ?’ì´??ë§ì¶¤
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        // ?´ë?ì§€ê°€ ???’ìŒ - ?ˆë¹„??ë§ì¶¤
        drawWidth = targetSize;
        drawHeight = targetSize / imageRatio;
        offsetY = (targetSize - drawHeight) / 2;
      }
      
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight),
        Paint(),
      );
      
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(targetSize.toInt(), targetSize.toInt());
      final ByteData? resizedData = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedData != null) {
        final icon = BitmapDescriptor.fromBytes(resizedData.buffer.asUint8List());
        setState(() {
          _customMarkerIcon = icon;
        });
        print('ë§ˆì»¤ ?¬ê¸° ì¡°ì • ?„ë£Œ: ${targetSize.toInt()}x${targetSize.toInt()} (?µì»¤ ?¬ì¸??ê³ ë ¤)');
      }
    } catch (e) {
      // print ¹® Á¦°ÅµÊ
      // ?¤ë¥˜ ??ê¸°ë³¸ ë°©ë²•?¼ë¡œ ?´ë°±
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(),
        'assets/images/ppam_work.png',
      );
      setState(() {
        _customMarkerIcon = icon;
      });
    }
  }

  void goToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_currentPosition!, 15.0));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) controller.setMapStyle(_mapStyle);
  }

  /// ??ê°„ë‹¨???´ëŸ¬?¤í„°ë§??¨ìˆ˜
  void _updateClustering() {
    // print ¹® Á¦°ÅµÊ
    
    if (_currentZoom < 12.0 && _markerItems.length > 1) {
      // ì¤Œì´ ë©€ê³?ë§ˆì»¤ê°€ 2ê°??´ìƒ?´ë©´ ?´ëŸ¬?¤í„°ë§??ìš©
      _createClusters();
    } else {
      // ì¤Œì´ ê°€ê¹Œìš°ê±°ë‚˜ ë§ˆì»¤ê°€ 1ê°??´í•˜ë©?ê°œë³„ ë§ˆì»¤ ?œì‹œ
      _showIndividualMarkers();
    }
  }

  /// ???´ëŸ¬?¤í„° ?ì„±
  void _createClusters() {
    // print ¹® Á¦°ÅµÊ
    
    _clusteredMarkers.clear();
    final clusters = <String, List<MarkerItem>>{};
    
    // ë§ˆì»¤?¤ì„ ê·¸ë£¹??(???¸ë???ê·¸ë¦¬??ê¸°ë°˜)
    for (final item in _markerItems) {
      // ???‘ì? ê·¸ë¦¬?œë¡œ ë¶„í• ?˜ì—¬ ?´ëŸ¬?¤í„°ë§??¨ê³¼ ?¥ìƒ
      final gridKey = '${(item.position.latitude * 1000).round()}_${(item.position.longitude * 1000).round()}';
      clusters.putIfAbsent(gridKey, () => []).add(item);
    }
    
    // print ¹® Á¦°ÅµÊ
    
    // ?´ëŸ¬?¤í„° ë§ˆì»¤ ?ì„±
    for (final cluster in clusters.values) {
      if (cluster.length == 1) {
        // ?¨ì¼ ë§ˆì»¤??ê·¸ë?ë¡??œì‹œ
        final item = cluster.first;
        _clusteredMarkers.add(_createMarker(item));
      } else {
        // ?¬ëŸ¬ ë§ˆì»¤???´ëŸ¬?¤í„°ë¡??œì‹œ
        final center = _calculateClusterCenter(cluster);
        _clusteredMarkers.add(_createClusterMarker(center, cluster.length));
        // print ¹® Á¦°ÅµÊ
      }
    }
    
    setState(() {
      _isClustered = true;
    });
    
    // print ¹® Á¦°ÅµÊ
  }

  /// ??ê°œë³„ ë§ˆì»¤ ?œì‹œ
  void _showIndividualMarkers() {
    // print ¹® Á¦°ÅµÊ
    
    _clusteredMarkers.clear();
    for (final item in _markerItems) {
      _clusteredMarkers.add(_createMarker(item));
    }
    
    setState(() {
      _isClustered = false;
    });
    
    // print ¹® Á¦°ÅµÊ
  }

  /// ???´ëŸ¬?¤í„° ì¤‘ì‹¬??ê³„ì‚°
  LatLng _calculateClusterCenter(List<MarkerItem> cluster) {
    double totalLat = 0;
    double totalLng = 0;
    
    for (final item in cluster) {
      totalLat += item.position.latitude;
      totalLng += item.position.longitude;
    }
    
    return LatLng(totalLat / cluster.length, totalLng / cluster.length);
  }

  /// ??ë§ˆì»¤ ?ì„±
  Marker _createMarker(MarkerItem item) {
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 1.0), // ë§ˆì»¤ ?˜ë‹¨ ì¤‘ì•™???µì»¤ ?¤ì •
      infoWindow: InfoWindow(
        title: item.title,
        snippet: '?¨ì? ?˜ëŸ‰: ${item.remainingAmount}ê°?,
      ),
      onTap: () {
        if (item.userId == userId) {
          _showMarkerActionMenu(item.id, item.data);
        } else {
          _showMarkerInfo(item.data);
        }
      },
    );
  }

  /// ???´ëŸ¬?¤í„° ë§ˆì»¤ ?ì„±
  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 1.0), // ë§ˆì»¤ ?˜ë‹¨ ì¤‘ì•™???µì»¤ ?¤ì •
      infoWindow: InfoWindow(
        title: '?´ëŸ¬?¤í„°',
        snippet: '$countê°œì˜ ë§ˆì»¤',
      ),
      onTap: () {
        // ?´ëŸ¬?¤í„° ??‹œ ì¤???        mapController.animateCamera(CameraUpdate.zoomIn());
      },
    );
  }

  /// ??Firestore?ì„œ ë§ˆì»¤ ë¶ˆëŸ¬?¤ê¸°
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    // print ¹® Á¦°ÅµÊ

    _markerItems.clear();
    _markers.clear();
    _clusteredMarkers.clear();
    
    for (var doc in docs) {
      final data = doc.data();
      final LatLng pos = LatLng(data['lat'], data['lng']);
      
      // ë§Œë£Œ ? ì§œ ?•ì¸
      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      final expiryDate = expiryTimestamp?.toDate();
      
      // ë§Œë£Œ??ë§ˆì»¤??ê±´ë„ˆ?°ê¸°
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        // print ¹® Á¦°ÅµÊ
        continue;
      }
      
      final markerItem = MarkerItem(
        id: doc.id,
        title: data['title'] ?? 'PPAM Marker',
        price: data['price']?.toString() ?? '0',
        amount: data['amount']?.toString() ?? '0',
        userId: data['userId'] ?? '',
        data: data,
        position: pos,
        imageUrl: data['imageUrl'],
        remainingAmount: data['remainingAmount'] ?? int.parse(data['amount']?.toString() ?? '0'),
        expiryDate: expiryDate,
      );
      
      _markerItems.add(markerItem);
    }
    
    // print ¹® Á¦°ÅµÊ
    
    // ?´ëŸ¬?¤í„°ë§??ìš©
    _updateClustering();
  }

  /// ??Firestore??ë§ˆì»¤ ?€??  Future<void> _addMarkerToFirestore(LatLng position, Map<String, dynamic> result) async {
    if (userId == null) return;
    
    // ë§Œë£Œ ? ì§œ ê³„ì‚°
    final period = int.tryParse(result['period']?.toString() ?? '24') ?? 24;
    final periodUnit = result['periodUnit'] ?? 'Hour';
    final expiryDate = _calculateExpiryDate(period, periodUnit);
    
    final doc = await FirebaseFirestore.instance.collection('markers').add({
      'lat': position.latitude,
      'lng': position.longitude,
      'title': 'PPAM Marker',
      'price': result['price'],
      'amount': result['amount'],
      'userId': userId,
      'imageUrl': result['imageUrl'],
      'remainingAmount': int.tryParse(result['amount']?.toString() ?? '0') ?? 0, // ì´ˆê¸° ?˜ëŸ‰
      'expiryDate': expiryDate,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final markerData = {
      'title': 'PPAM Marker',
      'price': result['price'],
      'amount': result['amount'],
      'userId': userId,
      'imageUrl': result['imageUrl'],
      'remainingAmount': int.tryParse(result['amount']?.toString() ?? '0') ?? 0,
      'expiryDate': expiryDate,
    };

    // ?ˆë¡œ??ë§ˆì»¤ ?„ì´???ì„±
    final markerItem = MarkerItem(
      id: doc.id,
      title: 'PPAM Marker',
      price: result['price']?.toString() ?? '0',
      amount: result['amount']?.toString() ?? '0',
      userId: userId ?? '',
      data: markerData,
      position: position,
      imageUrl: result['imageUrl'],
      remainingAmount: int.tryParse(result['amount']?.toString() ?? '0') ?? 0,
      expiryDate: expiryDate,
    );

    // ë§ˆì»¤ ì¶”ê?
    _markerItems.add(markerItem);
    
    // ?´ëŸ¬?¤í„°ë§??…ë°?´íŠ¸
    _updateClustering();
  }

  /// ??ë§Œë£Œ ? ì§œ ê³„ì‚°
  DateTime _calculateExpiryDate(int period, String unit) {
    final now = DateTime.now();
    switch (unit) {
      case 'Hour':
        return now.add(Duration(hours: period));
      case 'Day':
        return now.add(Duration(days: period));
      case 'Week':
        return now.add(Duration(days: period * 7));
      default:
        return now.add(Duration(hours: 24));
    }
  }

  /// ??ë§ˆì»¤ ?¡ì…˜ ë©”ë‰´ ?œì‹œ (?Œìœ ?ìš©)
  void _showMarkerActionMenu(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '?„ë‹¨ì§€ ë©”ë‰´'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('ê°€ê²? ${data['price']}??),
              const SizedBox(height: 8),
              Text('ì´??˜ëŸ‰: ${data['amount']}ê°?),
              const SizedBox(height: 8),
              Text('?¨ì? ?˜ëŸ‰: $remainingAmountê°?, 
                style: TextStyle(
                  color: remainingAmount > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '?í•˜???‘ì—…??? íƒ?˜ì„¸??',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showMarkerInfo(data);
              },
              child: const Text('?•ë³´ ë³´ê¸°'),
            ),
            if (remainingAmount > 0)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showRecoveryDialog(markerId, data);
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
                child: const Text('?Œìˆ˜?˜ê¸°'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ì·¨ì†Œ'),
            ),
          ],
        );
      },
    );
  }

  /// ??ë§ˆì»¤ ?•ë³´ ?œì‹œ
  void _showMarkerInfo(Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '?„ë‹¨ì§€ ?•ë³´'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 200,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text('ê°€ê²? ${data['price']}??),
              const SizedBox(height: 8),
              Text('?¨ì? ?˜ëŸ‰: $remainingAmountê°?),
              const SizedBox(height: 16),
              if (remainingAmount > 0) ...[
                const Text(
                  '??ë§ˆì»¤ ê·¼ì²˜(30m ?´ë‚´)?ì„œ ?˜ë ¹?????ˆìŠµ?ˆë‹¤.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _checkProximityAndReceive(data);
                  },
                  child: const Text('ê·¼ì²˜?ì„œ ?˜ë ¹?˜ê¸°'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?•ì¸'),
            ),
          ],
        );
      },
    );
  }

  /// ??GPS ê·¼ì ‘ ?•ì¸ ë°??˜ë ¹
  Future<void> _checkProximityAndReceive(Map<String, dynamic> data) async {
    try {
      // ?„ì¬ ?„ì¹˜ ê°€?¸ì˜¤ê¸?      Position? currentPosition = await LocationService.getCurrentPosition();
      if (currentPosition == null) {
        _showErrorDialog('?„ì¹˜ ?•ë³´ë¥?ê°€?¸ì˜¬ ???†ìŠµ?ˆë‹¤.');
        return;
      }

      final currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
      final markerLatLng = LatLng(data['lat'], data['lng']);
      
      // ê±°ë¦¬ ê³„ì‚° (ë¯¸í„° ?¨ìœ„)
      final distance = _calculateDistance(currentLatLng, markerLatLng);
      
      if (distance <= 30) { // 30m ?´ë‚´
        await _receiveImage(data);
      } else {
        _showErrorDialog('ë§ˆì»¤ë¡œë????ˆë¬´ ë©€ë¦??ˆìŠµ?ˆë‹¤.\nê±°ë¦¬: ${distance.toStringAsFixed(1)}m');
      }
    } catch (e) {
      _showErrorDialog('?¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤: $e');
    }
  }

  /// ??ê±°ë¦¬ ê³„ì‚° (ë¯¸í„° ?¨ìœ„)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // ì§€êµ?ë°˜ì?ë¦?(ë¯¸í„°)
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// ???´ë?ì§€ ?˜ë ¹
  Future<void> _receiveImage(Map<String, dynamic> data) async {
    final markerId = data['id'];
    final imageUrl = data['imageUrl'];
    final currentAmount = data['remainingAmount'] ?? 0;
    
    if (currentAmount <= 0) {
      _showErrorDialog('?˜ë ¹ ê°€?¥í•œ ?˜ëŸ‰???†ìŠµ?ˆë‹¤.');
      return;
    }

    try {
      // Firestore?ì„œ ?˜ëŸ‰ ê°ì†Œ
      await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
        'remainingAmount': currentAmount - 1,
      });

      // ?¬ìš©???”ë ›???´ë?ì§€ ì¶”ê?
      if (userId != null && imageUrl != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('received_images')
            .add({
          'imageUrl': imageUrl,
          'receivedAt': FieldValue.serverTimestamp(),
          'markerId': markerId,
        });
      }

      // ë§ˆì»¤ ëª©ë¡ ?…ë°?´íŠ¸
      await _loadMarkersFromFirestore();

      _showSuccessDialog('?´ë?ì§€ë¥??±ê³µ?ìœ¼ë¡??˜ë ¹?ˆìŠµ?ˆë‹¤!');
    } catch (e) {
      _showErrorDialog('?˜ë ¹ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤: $e');
    }
  }

  /// ???¤ë¥˜ ?¤ì´?¼ë¡œê·?  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?¤ë¥˜'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?•ì¸'),
            ),
          ],
        );
      },
    );
  }

  /// ???±ê³µ ?¤ì´?¼ë¡œê·?  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?±ê³µ'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?•ì¸'),
            ),
          ],
        );
      },
    );
  }

  /// ??ë§ˆì»¤ ?Œìˆ˜ ?•ì¸ ?¤ì´?¼ë¡œê·?  void _showRecoveryDialog(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?„ë‹¨ì§€ ?Œìˆ˜'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data['title'] ?? '?„ë‹¨ì§€'}ë¥??Œìˆ˜?˜ì‹œê² ìŠµ?ˆê¹Œ?'),
              const SizedBox(height: 8),
              Text('?¨ì? ?˜ëŸ‰: $remainingAmountê°?),
              const SizedBox(height: 16),
              const Text(
                '?Œìˆ˜ ?µì…˜??? íƒ?˜ì„¸??',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _recoverPartialAmount(markerId, data, remainingAmount);
                },
                child: Text('?„ì²´ ?Œìˆ˜ ($remainingAmountê°?'),
              ),
              if (remainingAmount > 1)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPartialRecoveryDialog(markerId, data, remainingAmount);
                  },
                  child: const Text('?¼ë? ?Œìˆ˜'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ì·¨ì†Œ'),
            ),
          ],
        );
      },
    );
  }

  /// ???¼ë? ?Œìˆ˜ ?¤ì´?¼ë¡œê·?  void _showPartialRecoveryDialog(String markerId, Map<String, dynamic> data, int maxAmount) {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?Œìˆ˜???˜ëŸ‰ ?…ë ¥'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ìµœë? ?Œìˆ˜ ê°€?? $maxAmountê°?),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '?Œìˆ˜???˜ëŸ‰',
                  hintText: '?«ìë¥??…ë ¥?˜ì„¸??,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ì·¨ì†Œ'),
            ),
            TextButton(
              onPressed: () {
                final amount = int.tryParse(amountController.text);
                if (amount != null && amount > 0 && amount <= maxAmount) {
                  Navigator.of(context).pop();
                  _recoverPartialAmount(markerId, data, amount);
                } else {
                  _showErrorDialog('?¬ë°”ë¥??˜ëŸ‰???…ë ¥?˜ì„¸??(1-$maxAmount)');
                }
              },
              child: const Text('?Œìˆ˜'),
            ),
          ],
        );
      },
    );
  }

  /// ??ë¶€ë¶??Œìˆ˜ ?¤í–‰
  Future<void> _recoverPartialAmount(String markerId, Map<String, dynamic> data, int amount) async {
    try {
      final currentAmount = data['remainingAmount'] ?? 0;
      final newAmount = currentAmount - amount;
      
      if (newAmount >= 0) {
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'remainingAmount': newAmount,
        });
        
        // ë§ˆì»¤ ëª©ë¡ ?…ë°?´íŠ¸
        await _loadMarkersFromFirestore();
        
        _showRecoverySuccessDialog(amount);
      } else {
        _showErrorDialog('?Œìˆ˜???˜ëŸ‰??ë¶€ì¡±í•©?ˆë‹¤.');
      }
    } catch (e) {
      _showErrorDialog('?Œìˆ˜ ì¤??¤ë¥˜ê°€ ë°œìƒ?ˆìŠµ?ˆë‹¤: $e');
    }
  }

  /// ???Œìˆ˜ ?„ë£Œ ?¤ì´?¼ë¡œê·?  void _showRecoverySuccessDialog([int? amount]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?Œìˆ˜ ?„ë£Œ'),
          content: Text(amount != null 
            ? '$amountê°œì˜ ?„ë‹¨ì§€ê°€ ?±ê³µ?ìœ¼ë¡??Œìˆ˜?˜ì—ˆ?µë‹ˆ??'
            : '?„ë‹¨ì§€ê°€ ?±ê³µ?ìœ¼ë¡??Œìˆ˜?˜ì—ˆ?µë‹ˆ??'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?•ì¸'),
            ),
          ],
        );
      },
    );
  }

  /// ??ë§ˆì»¤ ?? œ (Firestore + UI)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    
    // ë§ˆì»¤ ?œê±°
    _markerItems.removeWhere((item) => item.id == markerId);
    
    // ?´ëŸ¬?¤í„°ë§??…ë°?´íŠ¸
    _updateClustering();
  }

  /// ??ë§ˆì»¤ ì¶”ê?
  Future<void> _handleAddMarker() async {
    // ?„ì¬ ê¸¸ê²Œ ?„ë¥¸ ?„ì¹˜ ?€??    final pressedPosition = _longPressedLatLng;
    
    // ?ì—… ì°??«ê¸°
    setState(() {
      _longPressedLatLng = null;
    });

    // PostPlaceScreen???? œ?˜ì–´ ê¸°ëŠ¥??ë¹„í™œ?±í™”
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('??ê¸°ëŠ¥?€ ?„ì¬ ?¬ìš©?????†ìŠµ?ˆë‹¤.')),
    );
  }

  Widget _buildPopupWidget() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("???„ì¹˜??ë¿Œë¦¬ê¸?),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("??ì£¼ì†Œ??ë¿Œë¦¬ê¸?),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("ì£¼ë? ?¬ì—…?ì—ê²?ë¿Œë¦¬ê¸?),
            ),
            const Divider(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text("ì·¨ì†Œ", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentPosition == null
          ? const Center(child: Text("?„ì¬ ?„ì¹˜ë¥?ë¶ˆëŸ¬?¤ëŠ” ì¤‘ì…?ˆë‹¤..."))
          : Stack(
        children: [
          GoogleMap(
            key: mapWidgetKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 15.0,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            onLongPress: (LatLng latLng) {
              setState(() {
                _longPressedLatLng = latLng;
              });
            },
            markers: {
              ..._clusteredMarkers,
              if (_longPressedLatLng != null)
                Marker(
                  markerId: const MarkerId('long_press_marker'),
                  position: _longPressedLatLng!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                  infoWindow: const InfoWindow(title: "? íƒ???„ì¹˜"),
                ),
            },
            onCameraMove: (CameraPosition position) {
              _currentZoom = position.zoom;
            },
            onCameraIdle: () {
              _updateClustering();
            },

          ),
          if (_longPressedLatLng != null)
            Center(child: _buildPopupWidget()),
        ],
      ),
    );
  }
}
