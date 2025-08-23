import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('예산'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: uid == null
          ? const Center(child: Text('로그인이 필요합니다.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('wallets').doc(uid).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? {};
                final int balance = (data['balance'] ?? 0) as int;
                final int escrow = (data['escrow'] ?? 0) as int;
                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade50,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metric('가용 잔액', balance),
                          _metric('에스크로', escrow),
                        ],
                      ),
                    ),
                    ButtonBar(
                      alignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(onPressed: (){}, child: const Text('충전')),
                        ElevatedButton(onPressed: (){}, child: const Text('출금')),
                        ElevatedButton(onPressed: (){}, child: const Text('내역')),
                        ElevatedButton(onPressed: (){}, child: const Text('연동')),
                      ],
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('wallet_transactions')
                            .doc(uid)
                            .collection('items')
                            .orderBy('ts', descending: true)
                            .snapshots(),
                        builder: (context, snap) {
                          final txs = snap.data?.docs ?? [];
                          if (txs.isEmpty) {
                            return const Center(child: Text('거래 내역이 없습니다.'));
                          }
                          return ListView.builder(
                            itemCount: txs.length,
                            itemBuilder: (context, index) {
                              final t = txs[index].data();
                              final type = (t['type'] ?? 'unknown').toString();
                              final amount = (t['amount'] ?? 0).toString();
                              final fee = (t['fee'] ?? 0).toString();
                              return ListTile(
                                leading: const Icon(Icons.receipt_long),
                                title: Text('$type · ₩$amount'),
                                subtitle: Text('수수료 ₩$fee'),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
      ),
    );
  }
}

Widget _metric(String label, int value) {
  return Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 4),
      Text('₩${_formatCurrency(value)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ],
  );
}

String _formatCurrency(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}
