import 'package:flutter/material.dart';

/// 롱프레스 메뉴 위젯
class MapLongPressMenu extends StatelessWidget {
  final VoidCallback onDeployHere;
  final VoidCallback onDeployAddress;
  final VoidCallback? onDeployBusiness;

  const MapLongPressMenu({
    super.key,
    required this.onDeployHere,
    required this.onDeployAddress,
    this.onDeployBusiness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들 바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 제목
            const Text(
              '포스트 배포',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // 설명
            const Text(
              '이 위치에 포스트를 배포하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // 메뉴 옵션들
            Expanded(
              child: Column(
                children: [
                  // 이 위치에 뿌리기
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDeployHere();
                      },
                      icon: const Icon(Icons.location_on, color: Colors.white),
                      label: const Text(
                        '이 위치에 뿌리기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4D4DFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 이 주소에 뿌리기
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onDeployAddress();
                      },
                      icon: const Icon(Icons.home, color: Colors.white),
                      label: const Text(
                        '이 주소에 뿌리기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 근처 업종에 뿌리기 (작업중)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: onDeployBusiness,
                      icon: const Icon(Icons.business, color: Colors.white),
                      label: const Text(
                        '근처 업종에 뿌리기 (작업중)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 롱프레스 메뉴를 표시하는 헬퍼 함수
void showMapLongPressMenu({
  required BuildContext context,
  required VoidCallback onDeployHere,
  required VoidCallback onDeployAddress,
  VoidCallback? onDeployBusiness,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => MapLongPressMenu(
      onDeployHere: onDeployHere,
      onDeployAddress: onDeployAddress,
      onDeployBusiness: onDeployBusiness,
    ),
  );
}

