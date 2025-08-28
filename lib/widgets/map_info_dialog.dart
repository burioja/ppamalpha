import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/post_model.dart';
import '../controllers/map_marker_controller.dart';

/// 마커 상세 정보를 표시하는 다이얼로그
class MapInfoDialog extends StatelessWidget {
  final MapMarkerItem? markerItem;
  final PostModel? post;
  final VoidCallback? onNavigate;
  final VoidCallback? onCollect;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isMyPost;

  const MapInfoDialog({
    super.key,
    this.markerItem,
    this.post,
    this.onNavigate,
    this.onCollect,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.isMyPost = false,
  }) : assert(markerItem != null || post != null, '마커 아이템 또는 포스트 중 하나는 필요합니다');

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 400.0,
          maxHeight: 600.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            _buildHeader(context),
            
            // 스크롤 가능한 내용
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 이미지 (있는 경우)
                    if (_hasImage) ...[
                      _buildImage(),
                      const SizedBox(height: 16.0),
                    ],
                    
                    // 기본 정보
                    _buildBasicInfo(),
                    
                    const SizedBox(height: 16.0),
                    
                    // 상세 정보
                    _buildDetailedInfo(),
                    
                    const SizedBox(height: 16.0),
                    
                    // 위치 정보
                    _buildLocationInfo(),
                    
                    const SizedBox(height: 16.0),
                    
                    // 만료 정보 (있는 경우)
                    if (_hasExpiry) ...[
                      _buildExpiryInfo(),
                      const SizedBox(height: 16.0),
                    ],
                    
                    // 추가 정보 (있는 경우)
                    if (_hasAdditionalInfo) ...[
                      _buildAdditionalInfo(),
                      const SizedBox(height: 16.0),
                    ],
                  ],
                ),
              ),
            ),
            
            // 액션 버튼들
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  /// 헤더 생성
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[600]!,
            Colors.blue[400]!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      child: Row(
        children: [
          // 아이콘
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Icon(
              _getItemIcon(),
              color: Colors.white,
              size: 24.0,
            ),
          ),
          
          const SizedBox(width: 16.0),
          
          // 제목과 부제목
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getItemTitle(),
                  style: const TextStyle(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4.0),
                Text(
                  _getItemSubtitle(),
                  style: TextStyle(
                    fontSize: 14.0,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 이미지 생성
  Widget _buildImage() {
    final imageUrl = _getItemImageUrl();
    
    return Container(
      width: double.infinity,
      height: 200.0,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.0),
        image: DecorationImage(
          image: NetworkImage(imageUrl!),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  /// 기본 정보 생성
  Widget _buildBasicInfo() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기본 정보',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12.0),
            
            // 가격/보상
            _buildInfoRow(
              icon: Icons.attach_money,
              label: _isPostPlace() ? '보상' : '가격',
              value: '${_getItemPrice()}원',
              iconColor: Colors.green[600]!,
            ),
            
            const SizedBox(height: 8.0),
            
            // 수량
            _buildInfoRow(
              icon: Icons.inventory,
              label: '수량',
              value: '${_getItemQuantity()}개',
              iconColor: Colors.blue[600]!,
            ),
            
            const SizedBox(height: 8.0),
            
            // 생성자
            _buildInfoRow(
              icon: Icons.person,
              label: '생성자',
              value: _getItemCreator(),
              iconColor: Colors.purple[600]!,
            ),
          ],
        ),
      ),
    );
  }

  /// 상세 정보 생성
  Widget _buildDetailedInfo() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '상세 정보',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12.0),
            
            // 설명
            if (_hasDescription) ...[
              _buildInfoRow(
                icon: Icons.description,
                label: '설명',
                value: _getItemDescription()!,
                iconColor: Colors.orange[600]!,
                isMultiline: true,
              ),
              const SizedBox(height: 8.0),
            ],
            
            // 카테고리
            if (_hasCategory) ...[
              _buildInfoRow(
                icon: Icons.category,
                label: '카테고리',
                value: _getItemCategory()!,
                iconColor: Colors.indigo[600]!,
              ),
              const SizedBox(height: 8.0),
            ],
            
            // 생성 날짜
            _buildInfoRow(
              icon: Icons.calendar_today,
              label: '생성일',
              value: _formatDate(_getItemCreatedDate()),
              iconColor: Colors.teal[600]!,
            ),
          ],
        ),
      ),
    );
  }

  /// 위치 정보 생성
  Widget _buildLocationInfo() {
    final position = _getItemPosition();
    
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '위치 정보',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12.0),
            
            _buildInfoRow(
              icon: Icons.location_on,
              label: '위도',
              value: position.latitude.toStringAsFixed(6),
              iconColor: Colors.red[600]!,
            ),
            
            const SizedBox(height: 8.0),
            
            _buildInfoRow(
              icon: Icons.location_on,
              label: '경도',
              value: position.longitude.toStringAsFixed(6),
              iconColor: Colors.red[600]!,
            ),
            
            if (_hasAddress) ...[
              const SizedBox(height: 8.0),
              _buildInfoRow(
                icon: Icons.home,
                label: '주소',
                value: _getItemAddress()!,
                iconColor: Colors.brown[600]!,
                isMultiline: true,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 만료 정보 생성
  Widget _buildExpiryInfo() {
    final expiryDate = _getItemExpiryDate();
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      color: daysLeft <= 3 ? Colors.red[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: daysLeft <= 3 ? Colors.red[600] : Colors.orange[600],
                  size: 20.0,
                ),
                const SizedBox(width: 8.0),
                Text(
                  '만료 정보',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: daysLeft <= 3 ? Colors.red[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            
            Text(
              daysLeft <= 0 
                  ? '이미 만료되었습니다'
                  : daysLeft <= 3 
                      ? '⚠️ ${daysLeft}일 후 만료됩니다'
                      : '${daysLeft}일 후 만료됩니다',
              style: TextStyle(
                fontSize: 14.0,
                color: daysLeft <= 3 ? Colors.red[700] : Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 8.0),
            
            Text(
              '만료일: ${_formatDate(expiryDate)}',
              style: TextStyle(
                fontSize: 12.0,
                color: daysLeft <= 3 ? Colors.red[600] : Colors.orange[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 추가 정보 생성
  Widget _buildAdditionalInfo() {
    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '추가 정보',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12.0),
            
            // 타겟 성별
            if (_hasTargetGender) ...[
              _buildInfoRow(
                icon: Icons.people,
                label: '타겟 성별',
                value: _getItemTargetGender()!,
                iconColor: Colors.pink[600]!,
              ),
              const SizedBox(height: 8.0),
            ],
            
            // 타겟 연령
            if (_hasTargetAge) ...[
              _buildInfoRow(
                icon: Icons.person_outline,
                label: '타겟 연령',
                value: _getItemTargetAge()!,
                iconColor: Colors.cyan[600]!,
              ),
              const SizedBox(height: 8.0),
            ],
            
            // 권한 정보
            if (_hasPermissions) ...[
              _buildInfoRow(
                icon: Icons.security,
                label: '사용 가능',
                value: _getItemPermissions(),
                iconColor: Colors.green[600]!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 액션 버튼들 생성
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // 내비게이션 버튼
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onNavigate,
              icon: const Icon(Icons.directions, size: 18.0),
              label: const Text('길찾기'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.blue[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          
          const SizedBox(width: 12.0),
          
          // 수집/편집 버튼
          if (!isMyPost) ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCollect,
                icon: const Icon(Icons.collections_bookmark, size: 18.0),
                label: const Text('수집'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18.0),
                label: const Text('편집'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ],
          
          const SizedBox(width: 12.0),
          
          // 공유/삭제 버튼
          if (!isMyPost) ...[
            SizedBox(
              width: 48.0,
              child: IconButton(
                onPressed: onShare,
                icon: Icon(
                  Icons.share,
                  color: Colors.grey[600],
                  size: 20.0,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ] else ...[
            SizedBox(
              width: 48.0,
              child: IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete,
                  color: Colors.red[600],
                  size: 20.0,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 정보 행 생성
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    bool isMultiline = false,
  }) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 18.0,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.0,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2.0),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.grey[800],
                ),
                maxLines: isMultiline ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 헬퍼 메서드들
  
  /// 아이템 아이콘 가져오기
  IconData _getItemIcon() {
    if (post != null) {
      return Icons.post_add;
    } else if (markerItem != null) {
      return markerItem!.data['type'] == 'post_place' 
          ? Icons.post_add 
          : Icons.place;
    }
    return Icons.place;
  }

  /// 아이템 제목 가져오기
  String _getItemTitle() {
    if (post != null) {
      return post!.title;
    } else if (markerItem != null) {
      return markerItem!.title;
    }
    return '알 수 없음';
  }

  /// 아이템 부제목 가져오기
  String _getItemSubtitle() {
    if (post != null) {
      return '${post!.reward}원 보상';
    } else if (markerItem != null) {
      return '${markerItem!.price}원';
    }
    return '';
  }

  /// 아이템 이미지 URL 가져오기
  String? _getItemImageUrl() {
    if (post != null && post!.imageUrl.isNotEmpty) {
      return post!.imageUrl;
    } else if (markerItem != null) {
      return markerItem!.imageUrl;
    }
    return null;
  }

  /// 아이템 가격 가져오기
  String _getItemPrice() {
    if (post != null) {
      return post!.reward.toString();
    } else if (markerItem != null) {
      return markerItem!.price;
    }
    return '0';
  }

  /// 아이템 수량 가져오기
  int _getItemQuantity() {
    if (post != null) {
      return post!.remainingAmount;
    } else if (markerItem != null) {
      return markerItem!.remainingAmount;
    }
    return 0;
  }

  /// 아이템 생성자 가져오기
  String _getItemCreator() {
    if (post != null) {
      return post!.creatorName;
    } else if (markerItem != null) {
      return markerItem!.data['creatorName'] as String? ?? '알 수 없음';
    }
    return '알 수 없음';
  }

  /// 아이템 위치 가져오기
  LatLng _getItemPosition() {
    if (post != null) {
      return LatLng(post!.location.latitude, post!.location.longitude);
    } else if (markerItem != null) {
      return markerItem!.position;
    }
    return const LatLng(0, 0);
  }

  /// 아이템 설명 가져오기
  String? _getItemDescription() {
    if (post != null && post!.description.isNotEmpty) {
      return post!.description;
    } else if (markerItem != null) {
      return markerItem!.data['description'] as String?;
    }
    return null;
  }

  /// 아이템 카테고리 가져오기
  String? _getItemCategory() {
    if (post != null) {
      return post!.category;
    } else if (markerItem != null) {
      return markerItem!.data['category'] as String?;
    }
    return null;
  }

  /// 아이템 생성 날짜 가져오기
  DateTime _getItemCreatedDate() {
    if (post != null) {
      return post!.createdAt;
    } else if (markerItem != null) {
      return markerItem!.data['createdAt']?.toDate() ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// 아이템 만료 날짜 가져오기
  DateTime? _getItemExpiryDate() {
    if (post != null) {
      return post!.expiryDate;
    } else if (markerItem != null) {
      return markerItem!.expiryDate;
    }
    return null;
  }

  /// 아이템 주소 가져오기
  String? _getItemAddress() {
    if (post != null && post!.address.isNotEmpty) {
      return post!.address;
    } else if (markerItem != null) {
      return markerItem!.data['address'] as String?;
    }
    return null;
  }

  /// 아이템 타겟 성별 가져오기
  String? _getItemTargetGender() {
    if (post != null) {
      return post!.targetGender;
    } else if (markerItem != null) {
      return markerItem!.data['targetGender'] as String?;
    }
    return null;
  }

  /// 아이템 타겟 연령 가져오기
  String? _getItemTargetAge() {
    if (post != null) {
      return post!.targetAge;
    } else if (markerItem != null) {
      return markerItem!.data['targetAge'] as String?;
    }
    return null;
  }

  /// 아이템 권한 정보 가져오기
  String _getItemPermissions() {
    if (post != null) {
      final permissions = <String>[];
      if (post!.canUse) permissions.add('사용');
      if (post!.canRequestReward) permissions.add('보상 요청');
      if (post!.canRespond) permissions.add('응답');
      if (post!.canForward) permissions.add('전달');
      return permissions.join(', ');
    } else if (markerItem != null) {
      final permissions = <String>[];
      if (markerItem!.data['canUse'] == true) permissions.add('사용');
      if (markerItem!.data['canRequestReward'] == true) permissions.add('보상 요청');
      if (markerItem!.data['canRespond'] == true) permissions.add('응답');
      if (markerItem!.data['canForward'] == true) permissions.add('전달');
      return permissions.join(', ');
    }
    return '없음';
  }

  /// 포스트 플레이스인지 확인
  bool _isPostPlace() {
    if (post != null) {
      return true;
    } else if (markerItem != null) {
      return markerItem!.data['type'] == 'post_place';
    }
    return false;
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Getter 메서드들
  
  /// 이미지가 있는지 확인
  bool get _hasImage => _getItemImageUrl() != null;

  /// 설명이 있는지 확인
  bool get _hasDescription => _getItemDescription() != null && _getItemDescription()!.isNotEmpty;

  /// 카테고리가 있는지 확인
  bool get _hasCategory => _getItemCategory() != null && _getItemCategory()!.isNotEmpty;

  /// 만료 날짜가 있는지 확인
  bool get _hasExpiry => _getItemExpiryDate() != null;

  /// 주소가 있는지 확인
  bool get _hasAddress => _getItemAddress() != null && _getItemAddress()!.isNotEmpty;

  /// 타겟 성별이 있는지 확인
  bool get _hasTargetGender => _getItemTargetGender() != null && _getItemTargetGender()!.isNotEmpty;

  /// 타겟 연령이 있는지 확인
  bool get _hasTargetAge => _getItemTargetAge() != null && _getItemTargetAge()!.isNotEmpty;

  /// 권한 정보가 있는지 확인
  bool get _hasPermissions => _isPostPlace();

  /// 추가 정보가 있는지 확인
  bool get _hasAdditionalInfo => _hasTargetGender || _hasTargetAge || _hasPermissions;
}
