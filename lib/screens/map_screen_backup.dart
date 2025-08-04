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


/// ??마커 ?�이???�래??class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl; // ?��?지 URL 추�?
  final int remainingAmount; // ?��? ?�량
  final DateTime? expiryDate; // 만료 ?�짜

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
  final String _googleApiKey = "YOUR_API_KEY"; // 바꿔�?  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  final Set<Marker> _markers = {};
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // 마커 관??변?�들
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
      // print �� ���ŵ�
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
      // ?��?지 ?�일??바이?�로 로드
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // ?��?지�?코드�??�코??      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      // ?�하???�기�?리사?�즈 (?????�기)
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // 마커 ?�기�?200x200?�로 ?�정?�고 ?�커 ?�인??고려
      final double targetSize = 48.0;
      final Rect rect = Rect.fromLTWH(0, 0, targetSize, targetSize);
      
      // ?��?지 비율 ?��??�면??중앙 ?�렬
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        // ?��?지가 ???�음 - ?�이??맞춤
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        // ?��?지가 ???�음 - ?�비??맞춤
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
        print('마커 ?�기 조정 ?�료: ${targetSize.toInt()}x${targetSize.toInt()} (?�커 ?�인??고려)');
      }
    } catch (e) {
      // print �� ���ŵ�
      // ?�류 ??기본 방법?�로 ?�백
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

  /// ??간단???�러?�터�??�수
  void _updateClustering() {
    // print �� ���ŵ�
    
    if (_currentZoom < 12.0 && _markerItems.length > 1) {
      // 줌이 멀�?마커가 2�??�상?�면 ?�러?�터�??�용
      _createClusters();
    } else {
      // 줌이 가까우거나 마커가 1�??�하�?개별 마커 ?�시
      _showIndividualMarkers();
    }
  }

  /// ???�러?�터 ?�성
  void _createClusters() {
    // print �� ���ŵ�
    
    _clusteredMarkers.clear();
    final clusters = <String, List<MarkerItem>>{};
    
    // 마커?�을 그룹??(???��???그리??기반)
    for (final item in _markerItems) {
      // ???��? 그리?�로 분할?�여 ?�러?�터�??�과 ?�상
      final gridKey = '${(item.position.latitude * 1000).round()}_${(item.position.longitude * 1000).round()}';
      clusters.putIfAbsent(gridKey, () => []).add(item);
    }
    
    // print �� ���ŵ�
    
    // ?�러?�터 마커 ?�성
    for (final cluster in clusters.values) {
      if (cluster.length == 1) {
        // ?�일 마커??그�?�??�시
        final item = cluster.first;
        _clusteredMarkers.add(_createMarker(item));
      } else {
        // ?�러 마커???�러?�터�??�시
        final center = _calculateClusterCenter(cluster);
        _clusteredMarkers.add(_createClusterMarker(center, cluster.length));
        // print �� ���ŵ�
      }
    }
    
    setState(() {
      _isClustered = true;
    });
    
    // print �� ���ŵ�
  }

  /// ??개별 마커 ?�시
  void _showIndividualMarkers() {
    // print �� ���ŵ�
    
    _clusteredMarkers.clear();
    for (final item in _markerItems) {
      _clusteredMarkers.add(_createMarker(item));
    }
    
    setState(() {
      _isClustered = false;
    });
    
    // print �� ���ŵ�
  }

  /// ???�러?�터 중심??계산
  LatLng _calculateClusterCenter(List<MarkerItem> cluster) {
    double totalLat = 0;
    double totalLng = 0;
    
    for (final item in cluster) {
      totalLat += item.position.latitude;
      totalLng += item.position.longitude;
    }
    
    return LatLng(totalLat / cluster.length, totalLng / cluster.length);
  }

  /// ??마커 ?�성
  Marker _createMarker(MarkerItem item) {
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 1.0), // 마커 ?�단 중앙???�커 ?�정
      infoWindow: InfoWindow(
        title: item.title,
        snippet: '?��? ?�량: ${item.remainingAmount}�?,
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

  /// ???�러?�터 마커 ?�성
  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 1.0), // 마커 ?�단 중앙???�커 ?�정
      infoWindow: InfoWindow(
        title: '?�러?�터',
        snippet: '$count개의 마커',
      ),
      onTap: () {
        // ?�러?�터 ??�� �???        mapController.animateCamera(CameraUpdate.zoomIn());
      },
    );
  }

  /// ??Firestore?�서 마커 불러?�기
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    // print �� ���ŵ�

    _markerItems.clear();
    _markers.clear();
    _clusteredMarkers.clear();
    
    for (var doc in docs) {
      final data = doc.data();
      final LatLng pos = LatLng(data['lat'], data['lng']);
      
      // 만료 ?�짜 ?�인
      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      final expiryDate = expiryTimestamp?.toDate();
      
      // 만료??마커??건너?�기
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        // print �� ���ŵ�
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
    
    // print �� ���ŵ�
    
    // ?�러?�터�??�용
    _updateClustering();
  }

  /// ??Firestore??마커 ?�??  Future<void> _addMarkerToFirestore(LatLng position, Map<String, dynamic> result) async {
    if (userId == null) return;
    
    // 만료 ?�짜 계산
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
      'remainingAmount': int.tryParse(result['amount']?.toString() ?? '0') ?? 0, // 초기 ?�량
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

    // ?�로??마커 ?�이???�성
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

    // 마커 추�?
    _markerItems.add(markerItem);
    
    // ?�러?�터�??�데?�트
    _updateClustering();
  }

  /// ??만료 ?�짜 계산
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

  /// ??마커 ?�션 메뉴 ?�시 (?�유?�용)
  void _showMarkerActionMenu(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '?�단지 메뉴'),
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
              Text('가�? ${data['price']}??),
              const SizedBox(height: 8),
              Text('�??�량: ${data['amount']}�?),
              const SizedBox(height: 8),
              Text('?��? ?�량: $remainingAmount�?, 
                style: TextStyle(
                  color: remainingAmount > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '?�하???�업???�택?�세??',
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
              child: const Text('?�보 보기'),
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
                child: const Text('?�수?�기'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  /// ??마커 ?�보 ?�시
  void _showMarkerInfo(Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '?�단지 ?�보'),
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
              Text('가�? ${data['price']}??),
              const SizedBox(height: 8),
              Text('?��? ?�량: $remainingAmount�?),
              const SizedBox(height: 16),
              if (remainingAmount > 0) ...[
                const Text(
                  '??마커 근처(30m ?�내)?�서 ?�령?????�습?�다.',
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
                  child: const Text('근처?�서 ?�령?�기'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?�인'),
            ),
          ],
        );
      },
    );
  }

  /// ??GPS 근접 ?�인 �??�령
  Future<void> _checkProximityAndReceive(Map<String, dynamic> data) async {
    try {
      // ?�재 ?�치 가?�오�?      Position? currentPosition = await LocationService.getCurrentPosition();
      if (currentPosition == null) {
        _showErrorDialog('?�치 ?�보�?가?�올 ???�습?�다.');
        return;
      }

      final currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
      final markerLatLng = LatLng(data['lat'], data['lng']);
      
      // 거리 계산 (미터 ?�위)
      final distance = _calculateDistance(currentLatLng, markerLatLng);
      
      if (distance <= 30) { // 30m ?�내
        await _receiveImage(data);
      } else {
        _showErrorDialog('마커로�????�무 멀�??�습?�다.\n거리: ${distance.toStringAsFixed(1)}m');
      }
    } catch (e) {
      _showErrorDialog('?�류가 발생?�습?�다: $e');
    }
  }

  /// ??거리 계산 (미터 ?�위)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지�?반�?�?(미터)
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// ???��?지 ?�령
  Future<void> _receiveImage(Map<String, dynamic> data) async {
    final markerId = data['id'];
    final imageUrl = data['imageUrl'];
    final currentAmount = data['remainingAmount'] ?? 0;
    
    if (currentAmount <= 0) {
      _showErrorDialog('?�령 가?�한 ?�량???�습?�다.');
      return;
    }

    try {
      // Firestore?�서 ?�량 감소
      await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
        'remainingAmount': currentAmount - 1,
      });

      // ?�용???�렛???��?지 추�?
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

      // 마커 목록 ?�데?�트
      await _loadMarkersFromFirestore();

      _showSuccessDialog('?��?지�??�공?�으�??�령?�습?�다!');
    } catch (e) {
      _showErrorDialog('?�령 �??�류가 발생?�습?�다: $e');
    }
  }

  /// ???�류 ?�이?�로�?  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?�류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?�인'),
            ),
          ],
        );
      },
    );
  }

  /// ???�공 ?�이?�로�?  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?�공'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?�인'),
            ),
          ],
        );
      },
    );
  }

  /// ??마커 ?�수 ?�인 ?�이?�로�?  void _showRecoveryDialog(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?�단지 ?�수'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data['title'] ?? '?�단지'}�??�수?�시겠습?�까?'),
              const SizedBox(height: 8),
              Text('?��? ?�량: $remainingAmount�?),
              const SizedBox(height: 16),
              const Text(
                '?�수 ?�션???�택?�세??',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _recoverPartialAmount(markerId, data, remainingAmount);
                },
                child: Text('?�체 ?�수 ($remainingAmount�?'),
              ),
              if (remainingAmount > 1)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPartialRecoveryDialog(markerId, data, remainingAmount);
                  },
                  child: const Text('?��? ?�수'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  /// ???��? ?�수 ?�이?�로�?  void _showPartialRecoveryDialog(String markerId, Map<String, dynamic> data, int maxAmount) {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?�수???�량 ?�력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('최�? ?�수 가?? $maxAmount�?),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '?�수???�량',
                  hintText: '?�자�??�력?�세??,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final amount = int.tryParse(amountController.text);
                if (amount != null && amount > 0 && amount <= maxAmount) {
                  Navigator.of(context).pop();
                  _recoverPartialAmount(markerId, data, amount);
                } else {
                  _showErrorDialog('?�바�??�량???�력?�세??(1-$maxAmount)');
                }
              },
              child: const Text('?�수'),
            ),
          ],
        );
      },
    );
  }

  /// ??부�??�수 ?�행
  Future<void> _recoverPartialAmount(String markerId, Map<String, dynamic> data, int amount) async {
    try {
      final currentAmount = data['remainingAmount'] ?? 0;
      final newAmount = currentAmount - amount;
      
      if (newAmount >= 0) {
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'remainingAmount': newAmount,
        });
        
        // 마커 목록 ?�데?�트
        await _loadMarkersFromFirestore();
        
        _showRecoverySuccessDialog(amount);
      } else {
        _showErrorDialog('?�수???�량??부족합?�다.');
      }
    } catch (e) {
      _showErrorDialog('?�수 �??�류가 발생?�습?�다: $e');
    }
  }

  /// ???�수 ?�료 ?�이?�로�?  void _showRecoverySuccessDialog([int? amount]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('?�수 ?�료'),
          content: Text(amount != null 
            ? '$amount개의 ?�단지가 ?�공?�으�??�수?�었?�니??'
            : '?�단지가 ?�공?�으�??�수?�었?�니??'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('?�인'),
            ),
          ],
        );
      },
    );
  }

  /// ??마커 ??�� (Firestore + UI)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    
    // 마커 ?�거
    _markerItems.removeWhere((item) => item.id == markerId);
    
    // ?�러?�터�??�데?�트
    _updateClustering();
  }

  /// ??마커 추�?
  Future<void> _handleAddMarker() async {
    // ?�재 길게 ?�른 ?�치 ?�??    final pressedPosition = _longPressedLatLng;
    
    // ?�업 �??�기
    setState(() {
      _longPressedLatLng = null;
    });

    // PostPlaceScreen????��?�어 기능??비활?�화
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('??기능?� ?�재 ?�용?????�습?�다.')),
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
              child: const Text("???�치??뿌리�?),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("??주소??뿌리�?),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("주�? ?�업?�에�?뿌리�?),
            ),
            const Divider(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text("취소", style: TextStyle(color: Colors.red)),
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
          ? const Center(child: Text("?�재 ?�치�?불러?�는 중입?�다..."))
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
                  infoWindow: const InfoWindow(title: "?�택???�치"),
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
