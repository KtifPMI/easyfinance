import 'package:flutter/material.dart';

const Map<String, IconData> accountIconMap = {
  'cash': Icons.money,
  'credit_card': Icons.credit_card,
  'savings': Icons.savings,
  'account_balance': Icons.account_balance,
  'wallet': Icons.account_balance_wallet,
  'payments': Icons.payments,
};

const Map<int, String> _idToType = {
  1: 'cash', 2: 'card', 5: 'deposit', 6: 'loan_given', 7: 'loan_received',
  8: 'credit_card', 9: 'credit', 10: 'oms', 11: 'stocks', 12: 'pif',
  13: 'ofbu', 14: 'pension', 15: 'electronic', 16: 'bank_account',
  17: 'real_estate', 18: 'car', 19: 'other_securities', 20: 'fund',
  21: 'insurance_savings', 22: 'savings_plan', 23: 'npf', 24: 'water_transport',
  25: 'art', 26: 'business', 27: 'other_property', 28: 'air_transport',
  29: 'motorcycle', 30: 'bonds', 31: 'pamm', 32: 'broker', 33: 'bonus_card',
};

const Map<String, String> _typeToId = {
  'cash': '1', 'card': '2', 'deposit': '5', 'loan_given': '6',
  'loan_received': '7', 'credit_card': '8', 'credit': '9', 'oms': '10',
  'stocks': '11', 'pif': '12', 'ofbu': '13', 'pension': '14',
  'electronic': '15', 'bank_account': '16', 'real_estate': '17', 'car': '18',
  'other_securities': '19', 'fund': '20', 'insurance_savings': '21',
  'savings_plan': '22', 'npf': '23', 'water_transport': '24', 'art': '25',
  'business': '26', 'other_property': '27', 'air_transport': '28',
  'motorcycle': '29', 'bonds': '30', 'pamm': '31', 'broker': '32',
  'bonus_card': '33',
};

String accountTypeFromId(int id) => _idToType[id] ?? 'cash';
String accountTypeToId(String type) => _typeToId[type] ?? '1';
