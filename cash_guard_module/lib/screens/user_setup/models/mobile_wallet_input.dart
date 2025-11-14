import 'package:flutter/material.dart';

class MobileWalletInput {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController balanceController = TextEditingController();

  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    balanceController.dispose();
  }
}
