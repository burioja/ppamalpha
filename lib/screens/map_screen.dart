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
import 'post_place_screen.dart';

/// ✅ 마커 아이템 클래스
class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl; // 이미지 URL 추가
  final int remainingAmount; // 남은 수량
  final DateTime? expiryDate; // 만료 날짜

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
  final String _googleApiKey = "YOUR_API_KEY"; // 바꿔줘
  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  final Set<Marker> _markers = {};
  final userId = FirebaseAuth.instance.currentUser?.uid;
  
  // 마커 관련 변수들
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
      print('맵 스타일 로드 오류: $e');
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
      // 이미지 파일을 바이트로 로드
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // 이미지를 코드로 디코드
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      // 원하는 크기로 리사이즈 (더 큰 크기)
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      // 마커 크기를 200x200으로 설정하고 앵커 포인트 고려
      final double targetSize = 48.0;
      final Rect rect = Rect.fromLTWH(0, 0, targetSize, targetSize);
      
      // 이미지 비율 유지하면서 중앙 정렬
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        // 이미지가 더 넓음 - 높이에 맞춤
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
        // 이미지가 더 높음 - 너비에 맞춤
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
        print('마커 크기 조정 완료: ${targetSize.toInt()}x${targetSize.toInt()} (앵커 포인트 고려)');
      }
    } catch (e) {
      print('마커 크기 조정 오류: $e');
      // 오류 시 기본 방법으로 폴백
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

  /// ✅ 간단한 클러스터링 함수
  void _updateClustering() {
    print('현재 줌 레벨: $_currentZoom, 마커 개수: ${_markerItems.length}');
    
    if (_currentZoom < 12.0 && _markerItems.length > 1) {
      // 줌이 멀고 마커가 2개 이상이면 클러스터링 적용
      _createClusters();
    } else {
      // 줌이 가까우거나 마커가 1개 이하면 개별 마커 표시
      _showIndividualMarkers();
    }
  }

  /// ✅ 클러스터 생성
  void _createClusters() {
    print('클러스터 생성 시작 - 마커 개수: ${_markerItems.length}');
    
    _clusteredMarkers.clear();
    final clusters = <String, List<MarkerItem>>{};
    
    // 마커들을 그룹화 (더 세밀한 그리드 기반)
    for (final item in _markerItems) {
      // 더 작은 그리드로 분할하여 클러스터링 효과 향상
      final gridKey = '${(item.position.latitude * 1000).round()}_${(item.position.longitude * 1000).round()}';
      clusters.putIfAbsent(gridKey, () => []).add(item);
    }
    
    print('생성된 클러스터 개수: ${clusters.length}');
    
    // 클러스터 마커 생성
    for (final cluster in clusters.values) {
      if (cluster.length == 1) {
        // 단일 마커는 그대로 표시
        final item = cluster.first;
        _clusteredMarkers.add(_createMarker(item));
      } else {
        // 여러 마커는 클러스터로 표시
        final center = _calculateClusterCenter(cluster);
        _clusteredMarkers.add(_createClusterMarker(center, cluster.length));
        print('클러스터 생성: ${cluster.length}개 마커');
      }
    }
    
    setState(() {
      _isClustered = true;
    });
    
    print('클러스터링 완료 - 표시될 마커 개수: ${_clusteredMarkers.length}');
  }

  /// ✅ 개별 마커 표시
  void _showIndividualMarkers() {
    print('개별 마커 표시 - 마커 개수: ${_markerItems.length}');
    
    _clusteredMarkers.clear();
    for (final item in _markerItems) {
      _clusteredMarkers.add(_createMarker(item));
    }
    
    setState(() {
      _isClustered = false;
    });
    
    print('개별 마커 표시 완료 - 표시될 마커 개수: ${_clusteredMarkers.length}');
  }

  /// ✅ 클러스터 중심점 계산
  LatLng _calculateClusterCenter(List<MarkerItem> cluster) {
    double totalLat = 0;
    double totalLng = 0;
    
    for (final item in cluster) {
      totalLat += item.position.latitude;
      totalLng += item.position.longitude;
    }
    
    return LatLng(totalLat / cluster.length, totalLng / cluster.length);
  }

  /// ✅ 마커 생성
  Marker _createMarker(MarkerItem item) {
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarker,
      anchor: const Offset(0.5, 1.0), // 마커 하단 중앙에 앵커 설정
      infoWindow: InfoWindow(
        title: item.title,
        snippet: '남은 수량: ${item.remainingAmount}개',
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

  /// ✅ 클러스터 마커 생성
  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      anchor: const Offset(0.5, 1.0), // 마커 하단 중앙에 앵커 설정
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
      ),
      onTap: () {
        // 클러스터 탭시 줌 인
        mapController.animateCamera(CameraUpdate.zoomIn());
      },
    );
  }

  /// ✅ Firestore에서 마커 불러오기
  Future<void> _loadMarkersFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('markers').get();
    final docs = snapshot.docs;

    print('Firestore에서 ${docs.length}개의 마커 데이터 로드');

    _markerItems.clear();
    _markers.clear();
    _clusteredMarkers.clear();
    
    for (var doc in docs) {
      final data = doc.data();
      final LatLng pos = LatLng(data['lat'], data['lng']);
      
      // 만료 날짜 확인
      final expiryTimestamp = data['expiryDate'] as Timestamp?;
      final expiryDate = expiryTimestamp?.toDate();
      
      // 만료된 마커는 건너뛰기
      if (expiryDate != null && DateTime.now().isAfter(expiryDate)) {
        print('만료된 마커 건너뛰기: ${doc.id}');
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
    
    print('마커 아이템 생성 완료: ${_markerItems.length}개');
    
    // 클러스터링 적용
    _updateClustering();
  }

  /// ✅ Firestore에 마커 저장
  Future<void> _addMarkerToFirestore(LatLng position, Map<String, dynamic> result) async {
    if (userId == null) return;
    
    // 만료 날짜 계산
    final period = int.tryParse(result['period']?.toString() ?? '24');
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
      'remainingAmount': result['amount'], // 초기 수량
      'expiryDate': expiryDate,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final markerData = {
      'title': 'PPAM Marker',
      'price': result['price'],
      'amount': result['amount'],
      'userId': userId,
      'imageUrl': result['imageUrl'],
      'remainingAmount': result['amount'],
      'expiryDate': expiryDate,
    };

    // 새로운 마커 아이템 생성
    final markerItem = MarkerItem(
      id: doc.id,
      title: 'PPAM Marker',
      price: result['price']?.toString() ?? '0',
      amount: result['amount']?.toString() ?? '0',
      userId: userId ?? '',
      data: markerData,
      position: position,
      imageUrl: result['imageUrl'],
      remainingAmount: result['amount'],
      expiryDate: expiryDate,
    );

    // 마커 추가
    _markerItems.add(markerItem);
    
    // 클러스터링 업데이트
    _updateClustering();
  }

  /// ✅ 만료 날짜 계산
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

  /// ✅ 마커 액션 메뉴 표시 (소유자용)
  void _showMarkerActionMenu(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '전단지 메뉴'),
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
              Text('가격: ${data['price']}원'),
              const SizedBox(height: 8),
              Text('총 수량: ${data['amount']}개'),
              const SizedBox(height: 8),
              Text('남은 수량: $remainingAmount개', 
                style: TextStyle(
                  color: remainingAmount > 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '원하는 작업을 선택하세요:',
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
              child: const Text('정보 보기'),
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
                child: const Text('회수하기'),
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

  /// ✅ 마커 정보 표시
  void _showMarkerInfo(Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    final imageUrl = data['imageUrl'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(data['title'] ?? '전단지 정보'),
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
              Text('가격: ${data['price']}원'),
              const SizedBox(height: 8),
              Text('남은 수량: $remainingAmount개'),
              const SizedBox(height: 16),
              if (remainingAmount > 0) ...[
                const Text(
                  '이 마커 근처(30m 이내)에서 수령할 수 있습니다.',
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
                  child: const Text('근처에서 수령하기'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ GPS 근접 확인 및 수령
  Future<void> _checkProximityAndReceive(Map<String, dynamic> data) async {
    try {
      // 현재 위치 가져오기
      Position? currentPosition = await LocationService.getCurrentPosition();
      if (currentPosition == null) {
        _showErrorDialog('위치 정보를 가져올 수 없습니다.');
        return;
      }

      final currentLatLng = LatLng(currentPosition.latitude, currentPosition.longitude);
      final markerLatLng = LatLng(data['lat'], data['lng']);
      
      // 거리 계산 (미터 단위)
      final distance = _calculateDistance(currentLatLng, markerLatLng);
      
      if (distance <= 30) { // 30m 이내
        await _receiveImage(data);
      } else {
        _showErrorDialog('마커로부터 너무 멀리 있습니다.\n거리: ${distance.toStringAsFixed(1)}m');
      }
    } catch (e) {
      _showErrorDialog('오류가 발생했습니다: $e');
    }
  }

  /// ✅ 거리 계산 (미터 단위)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // 지구 반지름 (미터)
    
    final lat1Rad = point1.latitude * (pi / 180);
    final lat2Rad = point2.latitude * (pi / 180);
    final deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  /// ✅ 이미지 수령
  Future<void> _receiveImage(Map<String, dynamic> data) async {
    final markerId = data['id'];
    final imageUrl = data['imageUrl'];
    final currentAmount = data['remainingAmount'] ?? 0;
    
    if (currentAmount <= 0) {
      _showErrorDialog('수령 가능한 수량이 없습니다.');
      return;
    }

    try {
      // Firestore에서 수량 감소
      await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
        'remainingAmount': currentAmount - 1,
      });

      // 사용자 월렛에 이미지 추가
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

      // 마커 목록 업데이트
      await _loadMarkersFromFirestore();

      _showSuccessDialog('이미지를 성공적으로 수령했습니다!');
    } catch (e) {
      _showErrorDialog('수령 중 오류가 발생했습니다: $e');
    }
  }

  /// ✅ 오류 다이얼로그
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('오류'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 성공 다이얼로그
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('성공'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 마커 회수 확인 다이얼로그
  void _showRecoveryDialog(String markerId, Map<String, dynamic> data) {
    final remainingAmount = data['remainingAmount'] ?? 0;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('전단지 회수'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${data['title'] ?? '전단지'}를 회수하시겠습니까?'),
              const SizedBox(height: 8),
              Text('남은 수량: $remainingAmount개'),
              const SizedBox(height: 16),
              const Text(
                '회수 옵션을 선택하세요:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _recoverPartialAmount(markerId, data, remainingAmount);
                },
                child: Text('전체 회수 ($remainingAmount개)'),
              ),
              if (remainingAmount > 1)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showPartialRecoveryDialog(markerId, data, remainingAmount);
                  },
                  child: const Text('일부 회수'),
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

  /// ✅ 일부 회수 다이얼로그
  void _showPartialRecoveryDialog(String markerId, Map<String, dynamic> data, int maxAmount) {
    final TextEditingController amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회수할 수량 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('최대 회수 가능: $maxAmount개'),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '회수할 수량',
                  hintText: '숫자를 입력하세요',
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
                  _showErrorDialog('올바른 수량을 입력하세요 (1-$maxAmount)');
                }
              },
              child: const Text('회수'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 부분 회수 실행
  Future<void> _recoverPartialAmount(String markerId, Map<String, dynamic> data, int amount) async {
    try {
      final currentAmount = data['remainingAmount'] ?? 0;
      final newAmount = currentAmount - amount;
      
      if (newAmount >= 0) {
        await FirebaseFirestore.instance.collection('markers').doc(markerId).update({
          'remainingAmount': newAmount,
        });
        
        // 마커 목록 업데이트
        await _loadMarkersFromFirestore();
        
        _showRecoverySuccessDialog(amount);
      } else {
        _showErrorDialog('회수할 수량이 부족합니다.');
      }
    } catch (e) {
      _showErrorDialog('회수 중 오류가 발생했습니다: $e');
    }
  }

  /// ✅ 회수 완료 다이얼로그
  void _showRecoverySuccessDialog([int? amount]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('회수 완료'),
          content: Text(amount != null 
            ? '$amount개의 전단지가 성공적으로 회수되었습니다.'
            : '전단지가 성공적으로 회수되었습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  /// ✅ 마커 삭제 (Firestore + UI)
  Future<void> _removeMarker(String markerId) async {
    await FirebaseFirestore.instance.collection('markers').doc(markerId).delete();
    
    // 마커 제거
    _markerItems.removeWhere((item) => item.id == markerId);
    
    // 클러스터링 업데이트
    _updateClustering();
  }

  /// ✅ 마커 추가
  Future<void> _handleAddMarker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostPlaceScreen()),
    );

    if (result != null && _longPressedLatLng != null) {
      await _addMarkerToFirestore(_longPressedLatLng!, result);
      setState(() {
        _longPressedLatLng = null;
      });
    }
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
              child: const Text("이 위치에 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("이 주소에 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("주변 사업자에게 뿌리기"),
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
          ? const Center(child: Text("현재 위치를 불러오는 중입니다..."))
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
                  infoWindow: const InfoWindow(title: "선택한 위치"),
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
