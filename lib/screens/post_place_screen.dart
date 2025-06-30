import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PostPlaceScreen extends StatelessWidget {
  final LatLng latLng;
  final String address;

  const PostPlaceScreen({
    super.key,
    required this.latLng,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Address or GPS loc."),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📍 위치 정보 출력
            Text("📌 위도: ${latLng.latitude}", style: const TextStyle(fontSize: 14)),
            Text("📌 경도: ${latLng.longitude}", style: const TextStyle(fontSize: 14)),
            Text("📍 주소: $address", style: const TextStyle(fontSize: 14)),
            const Divider(height: 24, thickness: 1),

            // 상단 설정
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Post Set."),
                Text("Img. Chk."),
                Text("Recent Template"),
              ],
            ),
            const SizedBox(height: 8),

            // 포스트 선택 영역
            Container(
              height: 100,
              color: Colors.orange[100],
              alignment: Alignment.center,
              child: const Text("Select Post Carousel"),
            ),
            const SizedBox(height: 16),

            // 가격/수량
            Row(
              children: [
                Expanded(child: ElevatedButton(onPressed: () {}, child: const Text("Price"))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () {}, child: const Text("Amount"))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () {}, child: const Text("Total price"))),
              ],
            ),
            const SizedBox(height: 16),

            // 기능 선택
            const Text("Function"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _purpleButton("Period"),
                _purpleButton("Using"),
                _purpleButton("Reply"),
              ],
            ),
            const SizedBox(height: 16),

            // 타겟 설정
            const Text("Target"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _purpleButton("Gender"),
                _purpleButton("Age(min)"),
                _purpleButton("Age(max)"),
              ],
            ),
            const SizedBox(height: 24),

            // PPAM 버튼
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 전송 처리
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[200],
                ),
                child: const Text("PPAM!"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _purpleButton(String label) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
      child: Text(label),
    );
  }
}
