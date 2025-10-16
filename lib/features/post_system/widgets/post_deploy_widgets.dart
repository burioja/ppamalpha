import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/models/post/post_model.dart';
import 'post_deploy_helpers.dart';

/// 포스트 배포 화면의 UI 위젯들
class PostDeployWidgets {
  // 포스트 선택 위젯
  static Widget buildPostSelector({
    required PostModel? selectedPost,
    required List<PostModel> posts,
    required ValueChanged<PostModel?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '포스트 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<PostModel>(
          value: selectedPost,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '포스트를 선택하세요',
          ),
          items: posts.map((post) {
            return DropdownMenuItem<PostModel>(
              value: post,
              child: Text(
                post.title,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // 위치 선택 위젯
  static Widget buildLocationSelector({
    required LatLng? selectedLocation,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '위치 선택',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedLocation != null
                        ? '${selectedLocation.latitude.toStringAsFixed(6)}, ${selectedLocation.longitude.toStringAsFixed(6)}'
                        : '위치를 선택하세요',
                    style: TextStyle(
                      color: selectedLocation != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 배포 방식 선택 위젯
  static Widget buildDeployTypeSelector({
    required String? selectedDeployType,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '배포 방식',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: selectedDeployType,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '배포 방식을 선택하세요',
          ),
          items: const [
            DropdownMenuItem(value: 'normal', child: Text('일반 배포')),
            DropdownMenuItem(value: 'building', child: Text('빌딩 배포')),
            DropdownMenuItem(value: 'unit', child: Text('단위 배포')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  // 빌딩명 입력 위젯
  static Widget buildBuildingNameField({
    required String? buildingName,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '빌딩명',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: buildingName,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '빌딩명을 입력하세요',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // 단위번호 입력 위젯
  static Widget buildUnitNumberField({
    required String? unitNumber,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '단위번호',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: unitNumber,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '단위번호를 입력하세요',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // 수량 입력 위젯
  static Widget buildQuantityField({
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '수량',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '수량을 입력하세요',
            suffixText: '개',
          ),
          keyboardType: TextInputType.number,
          validator: validator,
        ),
      ],
    );
  }

  // 가격 입력 위젯
  static Widget buildPriceField({
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '단가',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '단가를 입력하세요',
            suffixText: '원',
          ),
          keyboardType: TextInputType.number,
          validator: validator,
        ),
      ],
    );
  }

  // 기간 입력 위젯
  static Widget buildDurationField({
    required TextEditingController controller,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '배포 기간',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '배포 기간을 입력하세요',
            suffixText: '일',
          ),
          keyboardType: TextInputType.number,
          validator: validator,
        ),
      ],
    );
  }

  // 비용 계산 위젯
  static Widget buildCostCalculator({
    required int quantity,
    required int price,
    required int userPoints,
  }) {
    final totalCost = quantity * price;
    final canAfford = userPoints >= totalCost;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: canAfford ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canAfford ? Colors.green[200]! : Colors.red[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '배포 비용',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('수량: $quantity개'),
              Text('단가: ${PostDeployHelpers.formatPoints(price)}'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('총 비용:'),
              Text(
                PostDeployHelpers.formatPoints(totalCost),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: canAfford ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('보유 포인트:'),
              Text(
                PostDeployHelpers.formatPoints(userPoints),
                style: TextStyle(
                  fontSize: 14,
                  color: canAfford ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ],
          ),
          if (!canAfford) ...[
            const SizedBox(height: 8),
            Text(
              '포인트가 부족합니다',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 배포 미리보기 위젯
  static Widget buildDeployPreview({
    required Map<String, dynamic> previewData,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '배포 미리보기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          // 포스트 정보
          _buildPreviewRow('포스트', previewData['postTitle']),
          _buildPreviewRow('위치', previewData['location']),
          _buildPreviewRow('수량', '${previewData['quantity']}개'),
          _buildPreviewRow('단가', PostDeployHelpers.formatPoints(previewData['price'])),
          _buildPreviewRow('총 비용', PostDeployHelpers.formatPoints(previewData['totalCost'])),
          _buildPreviewRow('기간', '${previewData['duration']}일'),
          _buildPreviewRow('배포 방식', previewData['deployType']),
          _buildPreviewRow('배포 정보', previewData['deployInfo']),
          _buildPreviewRow('만료일', PostDeployHelpers.formatDate(previewData['expiresAt'])),
        ],
      ),
    );
  }

  // 미리보기 행 위젯
  static Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 배포 버튼 위젯
  static Widget buildDeployButton({
    required VoidCallback onPressed,
    required bool isLoading,
    required bool canDeploy,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canDeploy && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '포스트 배포',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // 로딩 위젯
  static Widget buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('데이터를 불러오는 중...'),
        ],
      ),
    );
  }

  // 에러 위젯
  static Widget buildErrorWidget(String message, VoidCallback? onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            '오류 발생',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('다시 시도'),
            ),
          ],
        ],
      ),
    );
  }

  // 빈 상태 위젯
  static Widget buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '데이터 없음',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 섹션 헤더 위젯
  static Widget buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 정보 카드 위젯
  static Widget buildInfoCard({
    required String title,
    required String content,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: iconColor ?? Colors.blue, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

