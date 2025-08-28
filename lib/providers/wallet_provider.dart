import 'package:flutter/material.dart';

class WalletProvider with ChangeNotifier {
  double _balance = 0.0;
  List<Transaction> _transactions = [];

  double get balance => _balance;
  List<Transaction> get transactions => _transactions;

  void addTransaction(Transaction transaction) {
    _transactions.add(transaction);
    _balance += transaction.amount;
    notifyListeners();
  }

  void setBalance(double balance) {
    _balance = balance;
    notifyListeners();
  }
}

class Transaction {
  final String id;
  final double amount;
  final String description;
  final DateTime timestamp;

  Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.timestamp,
  });
}