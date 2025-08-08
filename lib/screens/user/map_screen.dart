import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/location_service.dart';
import '../../services/post_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/post_model.dart';

/// 마커 아이템 클래스
class MarkerItem {
  final String id;
  final String title;
  final String price;
  final String amount;
  final String userId;
  final Map<String, dynamic> data;
  final LatLng position;
  final String? imageUrl;
  final int remainingAmount;
  final DateTime? expiryDate;

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
  final String _googleApiKey = "YOUR_API_KEY";
  final GlobalKey mapWidgetKey = GlobalKey();
  LatLng? _longPressedLatLng;
  String? _mapStyle;
  BitmapDescriptor? _customMarkerIcon;
  final Set<Marker> _markers = {};
  final userId = FirebaseAuth.instance.currentUser?.uid;
  final PostService _postService = PostService();
  
  final List<MarkerItem> _markerItems = [];
  final List<PostModel> _posts = [];
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
    _loadPostsFromFirestore();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await DefaultAssetBundle.of(context).loadString('assets/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      // 스타일 로드 실패 시 무시
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
      final ByteData data = await rootBundle.load('assets/images/ppam_work.png');
      final Uint8List bytes = data.buffer.asUint8List();
      
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;
      
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      
      final double targetSize = 48.0;
      final Rect rect = Rect.fromLTWH(0, 0, targetSize, targetSize);
      
      final double imageRatio = image.width / image.height;
      final double targetRatio = targetSize / targetSize;
      
      double drawWidth = targetSize;
      double drawHeight = targetSize;
      double offsetX = 0;
      double offsetY = 0;
      
      if (imageRatio > targetRatio) {
        drawHeight = targetSize;
        drawWidth = targetSize * imageRatio;
        offsetX = (targetSize - drawWidth) / 2;
      } else {
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
      final ByteData? resizedBytes = await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      
      if (resizedBytes != null) {
        final Uint8List resizedUint8List = resizedBytes.buffer.asUint8List();
        setState(() {
          _customMarkerIcon = BitmapDescriptor.fromBytes(resizedUint8List);
        });
      }
    } catch (e) {
      // 커스텀 마커 로드 실패 시 기본 마커 사용
    }
  }



  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle != null) {
      controller.setMapStyle(_mapStyle);
    }
  }

  void _updateClustering() {
    if (_currentZoom < 12.0) {
      _clusterMarkers();
    } else {
      _showIndividualMarkers();
    }
  }

  void _showPostInfo(PostModel flyer) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(flyer.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('발행자: ${flyer.creatorName}'),
              const SizedBox(height: 8),
              Text('리워드: ${flyer.reward}원'),
              const SizedBox(height: 8),
              Text('타겟: ${flyer.targetGender == 'all' ? '전체' : flyer.targetGender == 'male' ? '남성' : '여성'} ${flyer.targetAge[0]}~${flyer.targetAge[1]}세'),
              const SizedBox(height: 8),
              if (flyer.targetInterest.isNotEmpty)
                Text('관심사: ${flyer.targetInterest.join(', ')}'),
              const SizedBox(height: 8),
              Text('만료일: ${_formatDate(flyer.expiresAt)}'),
              const SizedBox(height: 8),
              if (flyer.canRespond) const Text('✓ 응답 가능'),
              if (flyer.canForward) const Text('✓ 전달 가능'),
              if (flyer.canRequestReward) const Text('✓ 리워드 수령 가능'),
              if (flyer.canUse) const Text('✓ 사용 가능'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            // 발행자만 회수 가능
            if (userId != null && userId == flyer.creatorId)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectPost(flyer);
                },
                child: const Text('회수'),
              ),
            // 조건에 맞는 사용자는 수령 가능
            if (userId != null && userId != flyer.creatorId && flyer.canRequestReward)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _collectFlyer(flyer);
                },
                child: const Text('수령'),
              ),
          ],
        );
      },
    );
  }

  // 발행자가 전단지 회수
  Future<void> _collectPost(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        await _postService.collectFlyer(
          flyerId: flyer.flyerId,
          userId: currentUserId,
        );
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('전단지를 회수했습니다!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전단지 회수에 실패했습니다: $e')),
        );
      }
    }
  }

  // 사용자가 전단지 수령
  Future<void> _collectFlyer(PostModel flyer) async {
    try {
      final currentUserId = userId;
      if (currentUserId != null) {
        // TODO: 전단지 수령 로직 구현 (월렛에 추가, 리워드 지급 등)
        
        setState(() {
          _posts.removeWhere((f) => f.flyerId == flyer.flyerId);
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('전단지를 수령했습니다! ${flyer.reward}원 리워드가 지급되었습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('전단지 수령에 실패했습니다: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _clusterMarkers() {
    if (_isClustered) return;
    
    final clusters = <String, List<dynamic>>{};
    const double clusterRadius = 0.01; // 약 1km
    
    // 기존 마커 아이템들 클러스터링
    for (final item in _markerItems) {
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final distance = _calculateDistance(clusterCenter, item.position);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(item);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${item.position.latitude},${item.position.longitude}';
        clusters[key] = [item];
      }
    }
    
    // 포스트들 클러스터링
    for (final post in _posts) {
      bool addedToCluster = false;
      
      for (final clusterKey in clusters.keys) {
        final clusterCenter = _parseLatLng(clusterKey);
        final postLatLng = LatLng(post.location.latitude, post.location.longitude);
        final distance = _calculateDistance(clusterCenter, postLatLng);
        
        if (distance <= clusterRadius) {
          clusters[clusterKey]!.add(post);
          addedToCluster = true;
          break;
        }
      }
      
      if (!addedToCluster) {
        final key = '${post.location.latitude},${post.location.longitude}';
        clusters[key] = [post];
      }
    }
    
    final Set<Marker> newMarkers = {};
    
    clusters.forEach((key, items) {
      if (items.length == 1) {
        final item = items.first;
        if (item is MarkerItem) {
          newMarkers.add(_createMarker(item));
        } else if (item is PostModel) {
          newMarkers.add(_createPostMarker(item));
        }
      } else {
        final center = _parseLatLng(key);
        newMarkers.add(_createClusterMarker(center, items.length));
      }
    });
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = true;
    });
  }

  void _showIndividualMarkers() {
    if (!_isClustered) return;
    
    final Set<Marker> newMarkers = {};
    
    // 기존 마커들 추가
    for (final item in _markerItems) {
      newMarkers.add(_createMarker(item));
    }
    
    // 포스트 마커들 추가
    for (final post in _posts) {
      newMarkers.add(_createPostMarker(post));
    }
    
    setState(() {
      _clusteredMarkers.clear();
      _clusteredMarkers.addAll(newMarkers);
      _isClustered = false;
    });
  }

  LatLng _parseLatLng(String key) {
    final parts = key.split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    return sqrt(pow(point1.latitude - point2.latitude, 2) + 
                pow(point1.longitude - point2.longitude, 2));
  }

  Marker _createMarker(MarkerItem item) {
    // 전단지 타입인지 확인
    final isPostPlace = item.data['type'] == 'post_place';
    
    return Marker(
      markerId: MarkerId(item.id),
      position: item.position,
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: item.title,
        snippet: isPostPlace 
            ? '${item.price}원 - ${item.data['creatorName'] ?? '알 수 없음'}'
            : '${item.price}원 - ${item.amount}개',
      ),
      onTap: () => _showMarkerInfo(item),
    );
  }

  Marker _createPostMarker(PostModel flyer) {
    return Marker(
      markerId: MarkerId(flyer.markerId),
      position: LatLng(flyer.location.latitude, flyer.location.longitude),
      icon: _customMarkerIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(
        title: flyer.title,
        snippet: '${flyer.reward}원 - ${flyer.creatorName}',
      ),
      onTap: () => _showPostInfo(flyer),
    );
  }

  Marker _createClusterMarker(LatLng position, int count) {
    return Marker(
      markerId: MarkerId('cluster_${position.latitude}_${position.longitude}'),
      position: position,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: InfoWindow(
        title: '클러스터',
        snippet: '$count개의 마커',
      ),
      onTap: () => _showClusterInfo(position, count),
    );
  }

  void _showMarkerInfo(MarkerItem item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // 전단지 타입인지 확인
        final isPostPlace = item.data['type'] == 'post_place';
        
        return AlertDialog(
          title: Text(item.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isPostPlace) ...[
                Text('발행자: ${item.data['creatorName'] ?? '알 수 없음'}'),
                const SizedBox(height: 8),
                Text('리워드: ${item.price}원'),
                const SizedBox(height: 8),
                if (item.data['description'] != null && item.data['description'].isNotEmpty)
                  Text('설명: ${item.data['description']}'),
                const SizedBox(height: 8),
                if (item.data['targetGender'] != null)
                  Text('타겟 성별: ${item.data['targetGender'] == 'all' ? '전체' : item.data['targetGender'] == 'male' ? '남성' : '여성'}'),
                const SizedBox(height: 8),
                if (item.data['targetAge'] != null)
                  Text('타겟 나이: ${item.data['targetAge'][0]}~${item.data['targetAge'][1]}세'),
                const SizedBox(height: 8),
                if (item.data['address'] != null)
                  Text('주소: ${item.data['address']}'),
                const SizedBox(height: 8),
                if (item.expiryDate != null)
                  Text('만료일: ${_formatDate(item.expiryDate!)}'),
              ] else ...[
                Text('가격: ${item.price}원'),
                const SizedBox(height: 8),
                Text('수량: ${item.amount}개'),
                const SizedBox(height: 8),
                Text('남은 수량: ${item.remainingAmount}개'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            if (isPostPlace) ...[
              // 전단지 수령 버튼
              if (item.data['canRequestReward'] == true)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _handleFlyerRecovery(item);
                  },
                  child: const Text('수령'),
                ),
            ] else ...[
              // 일반 마커 수령 버튼
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleRecovery(item.id, item.data);
                },
                child: const Text('수령'),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showClusterInfo(LatLng position, int count) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('클러스터 정보'),
          content: Text('이 지역에 $count개의 마커가 있습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }

  void _handleRecovery(String markerId, Map<String, dynamic> data) {
    // 수령 로직 구현
    print('수령 처리: $markerId');
  }

  // 전단지 수령 처리
  void _handleFlyerRecovery(MarkerItem item) async {
    try {
      final flyerId = item.data['flyerId'] as String;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      if (currentUserId != null) {
        // PostService를 통해 전단지 수령
        await _postService.collectFlyer(
          flyerId: flyerId,
          userId: currentUserId,
        );
        
        // 마커 목록에서 제거
        setState(() {
          _markerItems.removeWhere((marker) => marker.id == item.id);
        });
        
        // 클러스터링 업데이트
        _updateClustering();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('전단지를 수령했습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('전단지 수령에 실패했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('markers')
          .get();
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final geoPoint = data['position'] as GeoPoint;
        
        final markerItem = MarkerItem(
          id: doc.id,
          title: data['title'] ?? '',
          price: data['price']?.toString() ?? '0',
          amount: data['amount']?.toString() ?? '0',
          userId: data['userId'] ?? '',
          data: data,
          position: LatLng(geoPoint.latitude, geoPoint.longitude),
          imageUrl: data['imageUrl'],
          remainingAmount: data['remainingAmount'] ?? 0,
          expiryDate: data['expiryDate']?.toDate(),
        );
        
        _markerItems.add(markerItem);
      }
      
      _updateClustering();
    } catch (e) {
      print('마커 로드 오류: $e');
    }
  }

  Future<void> _loadPostsFromFirestore() async {
    try {
      if (_currentPosition != null) {
        // 사용자 정보 가져오기 (실제로는 사용자 프로필에서 가져와야 함)
        final userGender = 'male'; // 임시 값
        final userAge = 25; // 임시 값
        final userInterests = ['패션', '뷰티']; // 임시 값
        final userPurchaseHistory = ['화장품']; // 임시 값
        
        // 새로운 flyer 시스템에서 전단지 로드
        final flyers = await _postService.getFlyersNearLocation(
          location: GeoPoint(_currentPosition!.latitude, _currentPosition!.longitude),
          radiusInKm: 5.0, // 5km 반경 내 전단지 조회
          userGender: userGender,
          userAge: userAge,
          userInterests: userInterests,
          userPurchaseHistory: userPurchaseHistory,
        );
        
        setState(() {
          _posts.clear();
          _posts.addAll(flyers);
        });
        
        _updateClustering();
      }
    } catch (e) {
      print('전단지 로드 오류: $e');
    }
  }



  void _addMarkerToMap(MarkerItem markerItem) {
    setState(() {
      _markerItems.add(markerItem);
      _clusteredMarkers.add(_createMarker(markerItem));
    });
    
    // Firestore에 저장
    _saveMarkerToFirestore(markerItem);
  }

  Future<void> _saveMarkerToFirestore(MarkerItem markerItem) async {
    try {
      await FirebaseFirestore.instance.collection('markers').add({
        'title': markerItem.title,
        'price': int.parse(markerItem.price),
        'amount': int.parse(markerItem.amount),
        'userId': markerItem.userId,
        'position': GeoPoint(markerItem.position.latitude, markerItem.position.longitude),
        'remainingAmount': markerItem.remainingAmount,
        'createdAt': FieldValue.serverTimestamp(),
        'expiryDate': markerItem.expiryDate,
      });
    } catch (e) {
      print('마커 저장 오류: $e');
    }
  }

  void _handleAddMarker() async {
    if (_longPressedLatLng != null) {
      // 선택된 위치의 주소 가져오기
      try {
        final address = await LocationService.getAddressFromCoordinates(
          _longPressedLatLng!.latitude,
          _longPressedLatLng!.longitude,
        );
        
        // 주소 확인 팝업 표시
        _showAddressConfirmationDialog(address);
      } catch (e) {
        // 주소 가져오기 실패 시 기본 메시지로 진행
        _showAddressConfirmationDialog('주소를 가져올 수 없습니다');
      }
    }
  }

  void _showAddressConfirmationDialog(String address) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text('주소 확인'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '이 주소가 맞습니까?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 2),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.shade50,
                ),
                child: Text(
                  address,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _longPressedLatLng = null;
                });
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToPostPlaceWithAddress(address);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
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
              onPressed: () => _navigateToPostPlace(),
              child: const Text("이 위치에 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("주소로 뿌리기"),
            ),
            TextButton(
              onPressed: _handleAddMarker,
              child: const Text("주변 업소에 뿌리기"),
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

  void _navigateToPostPlace() async {
    final result = await Navigator.pushNamed(context, '/post-place');
    _handlePostPlaceResult(result);
  }

  void _navigateToPostPlaceWithAddress(String address) async {
    // 주소 정보와 함께 포스트 화면으로 이동
    final result = await Navigator.pushNamed(
      context, 
      '/post-place',
      arguments: {
        'location': _longPressedLatLng,
        'address': address,
      },
    );
    _handlePostPlaceResult(result);
  }

  void _handlePostPlaceResult(dynamic result) {
    // 전단지 생성 후 지도 새로고침
    if (result != null && result is Map<String, dynamic>) {
      // 새로 생성된 전단지 정보를 MarkerItem으로 변환
      if (result['location'] != null && result['flyerId'] != null) {
        final location = result['location'] as LatLng;
        final flyerId = result['flyerId'] as String;
        final address = result['address'] as String?;
        
        try {
          // PostService에서 실제 전단지 정보 가져오기
          final flyer = await _postService.getFlyerById(flyerId);
          
          if (flyer != null) {
            // MarkerItem 생성 (실제 전단지 정보 사용)
            final markerItem = MarkerItem(
              id: flyerId,
              title: flyer.title,
              price: flyer.reward.toString(),
              amount: '1', // 전단지는 개별 단위
              userId: flyer.creatorId,
              data: {
                'address': address,
                'flyerId': flyerId,
                'type': 'post_place',
                'creatorName': flyer.creatorName,
                'description': flyer.description,
                'targetGender': flyer.targetGender,
                'targetAge': flyer.targetAge,
                'canRespond': flyer.canRespond,
                'canForward': flyer.canForward,
                'canRequestReward': flyer.canRequestReward,
                'canUse': flyer.canUse,
              },
              position: location,
              remainingAmount: 1, // 전단지는 개별 단위
              expiryDate: flyer.expiresAt,
            );
            
            // 마커 추가
            _addMarkerToMap(markerItem);
            
            // 생성된 전단지 위치로 카메라 이동
            mapController.animateCamera(
              CameraUpdate.newLatLng(location),
            );
            
            // 성공 메시지 표시
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('전단지가 생성되었습니다! 지도에 마커가 표시됩니다.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('전단지 정보를 가져오는데 실패했습니다: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  void goToCurrentLocation() {
    if (_currentPosition != null) {
      mapController.animateCamera(
        CameraUpdate.newLatLng(_currentPosition!),
      );
    }
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

 