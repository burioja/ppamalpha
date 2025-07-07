import 'package:flutter/material.dart';

class PostPlaceScreen extends StatefulWidget {
  const PostPlaceScreen({super.key});

  @override
  State<PostPlaceScreen> createState() => _PostPlaceScreenState();
}

class _PostPlaceScreenState extends State<PostPlaceScreen> {
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  int get _totalPrice {
    final price = int.tryParse(_priceController.text) ?? 0;
    final amount = int.tryParse(_amountController.text) ?? 0;
    return price * amount;
  }

  final TextEditingController _periodController = TextEditingController();
  String _periodUnit = 'Hour';
  bool _usingSelected = false;
  bool _replySelected = false;

  String _gender = '상관없음';
  final TextEditingController _ageMinController = TextEditingController();
  final TextEditingController _ageMaxController = TextEditingController();

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
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Price"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Amount"),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text("Total: $_totalPrice"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 기능(Function)
            const Text("Function", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _periodController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Period"),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _periodUnit,
                  items: const [
                    DropdownMenuItem(value: 'Hour', child: Text('Hour')),
                    DropdownMenuItem(value: 'Day', child: Text('Day')),
                    DropdownMenuItem(value: 'Week', child: Text('Week')),
                  ],
                  onChanged: (value) {
                    setState(() => _periodUnit = value!);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _toggleButton("Using", _usingSelected, () {
                  setState(() => _usingSelected = !_usingSelected);
                }),
                _toggleButton("Reply", _replySelected, () {
                  setState(() => _replySelected = !_replySelected);
                }),
              ],
            ),
            const SizedBox(height: 24),

            // 타겟(Target)
            const Text("Target", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _gender,
              items: const [
                DropdownMenuItem(value: '남자', child: Text('남자')),
                DropdownMenuItem(value: '여자', child: Text('여자')),
                DropdownMenuItem(value: '상관없음', child: Text('상관없음')),
              ],
              onChanged: (value) {
                setState(() => _gender = value!);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageMinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Age (min)"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _ageMaxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Age (max)"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // PPAM 버튼
            Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'price': _priceController.text,
                    'amount': _amountController.text,
                    'totalPrice': _totalPrice,
                    'period': _periodController.text,
                    'periodUnit': _periodUnit,
                    'using': _usingSelected,
                    'reply': _replySelected,
                    'gender': _gender,
                    'ageMin': _ageMinController.text,
                    'ageMax': _ageMaxController.text,
                  });
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

  Widget _toggleButton(String label, bool selected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.purple : Colors.grey[300],
        foregroundColor: selected ? Colors.white : Colors.black,
      ),
      child: Text(label),
    );
  }

}
