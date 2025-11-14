import 'package:flutter/material.dart';

class BankCardInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController bankController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    numberController.dispose();
    bankController.dispose();
    balanceController.dispose();
  }
}
