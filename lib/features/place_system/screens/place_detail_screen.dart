import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/models/place/place_model.dart';
import '../../../core/services/data/place_service.dart';
import '../widgets/place_detail_helpers.dart';
import '../widgets/place_detail_widgets.dart';

/// 플레이스 상세 화면
class PlaceDetailScreen extends StatefulWidget {
  final String placeId;

  const PlaceDetailScreen({super.key, required this.placeId});

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  final PlaceService _placeService = PlaceService();
  Future<PlaceModel?>? _placeFuture; // Future 캐싱
  PageController? _pageController; // 이미지 캐러셀 컨트롤러 (nullable)
  int _currentImageIndex = 0; // 현재 이미지 인덱스

  @override
  void initState() {
    super.initState();
    // initState에서 Future를 한 번만 생성
    _placeFuture = PlaceDetailHelpers.loadPlace(widget.placeId);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  /// 이미지 인덱스 변경 처리
  void _onImageChanged(int index) {
    setState(() {
      _currentImageIndex = index;
    });
  }

  /// 플레이스 데이터 새로고침
  Future<void> _refreshPlace() async {
    setState(() {
      _placeFuture = PlaceDetailHelpers.loadPlace(widget.placeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[600]!, Colors.purple[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            '플레이스 상세',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  /// 메인 바디 위젯
  Widget _buildBody() {
    return FutureBuilder<PlaceModel?>(
      future: _placeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return PlaceDetailWidgets.buildLoadingWidget();
        }

        if (snapshot.hasError) {
          return PlaceDetailWidgets.buildErrorWidget(
            '데이터를 불러오는 중 오류가 발생했습니다.',
            _refreshPlace,
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return PlaceDetailWidgets.buildEmptyWidget(
            '플레이스 정보를 찾을 수 없습니다.',
          );
        }

        final place = snapshot.data!;
        
        // 이미지가 있을 때만 PageController 생성
        if (place.imageUrls.isNotEmpty && _pageController == null) {
          _pageController = PageController();
        }

        return RefreshIndicator(
          onRefresh: _refreshPlace,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                // 플레이스 헤더 (이미지 캐러셀 + 정보 오버레이)
                PlaceDetailWidgets.buildPlaceHeader(
                  place: place,
                  currentImageIndex: _currentImageIndex,
                  pageController: _pageController!,
                  onImageChanged: _onImageChanged,
                ),
                
                // 기본 정보 섹션
                PlaceDetailWidgets.buildBasicInfoSection(place),
                
                // 운영 정보 섹션
                PlaceDetailWidgets.buildOperatingInfoSection(place),
                
                // 추가 정보 섹션
                PlaceDetailWidgets.buildAdditionalInfoSection(place),
                
                // 지도 섹션
                PlaceDetailWidgets.buildMapSection(place),
                
                // 액션 버튼들
                PlaceDetailWidgets.buildActionButtons(place),
                
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}