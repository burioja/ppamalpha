import 'package:flutter/material.dart';

class PostPlaceScreen extends StatelessWidget {
  const PostPlaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Address or GPS loc."),
        backgroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 설정
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text("Post Set."),
                Text("Img. Chk."),
                Text("Recent Template"),
              ],
            ),
            const SizedBox(height: 12),

            // 포스트 선택 영역
            Container(
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.orange[100],
                border: Border.all(color: Colors.orange),
              ),
              child: const Text(
                "Select Post Carousel",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),

            // 가격/수량/총액
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Price"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text("Amount"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue[100],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    child: const Text("Total price"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 기능(Function)
            const Text("Function", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _purpleButton("Period"),
                _purpleButton("Using"),
                _purpleButton("Reply"),
              ],
            ),
            const SizedBox(height: 24),

            // 타겟(Target)
            const Text("Target", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _purpleButton("Gender"),
                _purpleButton("Age(min)"),
                _purpleButton("Age(max)"),
              ],
            ),
            const SizedBox(height: 32),

            // PPAM 버튼
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 실제 전송 로직
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[200],
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                ),
                child: const Text("PPAM!"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _purpleButton(String label) {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label),
    );
  }
}
