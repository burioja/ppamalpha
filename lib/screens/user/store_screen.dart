import 'package:flutter/material.dart';

class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('스토어'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 커버 + 배지
          Container(
            height: 140,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade200,
              image: const DecorationImage(
                image: AssetImage('assets/images/logo.png'),
                fit: BoxFit.cover,
                opacity: 0.15,
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('인증됨', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 기본 정보
          Row(
            children: [
              const CircleAvatar(radius: 26, child: Icon(Icons.store)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('가게명', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('서울시 어딘가 123', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 인증 섹션 (더미 동작)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('직원 인증', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('NFC 태그 확인: 더미 성공')),
                            );
                          },
                          icon: const Icon(Icons.nfc),
                          label: const Text('NFC 인증'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('WiFi 검증: 더미 성공')),
                            );
                          },
                          icon: const Icon(Icons.wifi),
                          label: const Text('WiFi 인증'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 미니 정보 + 길찾기 더미
          Card(
            child: ListTile(
              leading: const Icon(Icons.map),
              title: const Text('미니맵(더미)'),
              subtitle: const Text('길찾기 버튼으로 지도 앱 열기(더미)'),
              trailing: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('길찾기 실행(더미)')),
                  );
                },
                child: const Text('길찾기'),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 리뷰/평점 섹션(더미)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('리뷰 관리', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('리뷰 신고(더미)')),
                          );
                        },
                        child: const Text('신고'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('리뷰 블록(더미)')),
                          );
                        },
                        child: const Text('블록'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}



