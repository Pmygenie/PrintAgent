import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../models/print_style_config.dart';
import '../services/print_style_service.dart';

class PrintStyleController extends GetxController {
  PrintStyleConfig config = PrintStyleConfig.defaults();
  bool isLoading = true;

  @override
  void onInit() {
    super.onInit();
    loadConfig();
  }

  Future<void> loadConfig() async {
    isLoading = true;
    update();

    config = await PrintStyleService.getConfig();

    isLoading = false;
    update();
  }

  void updateFont58(PrintStyleItem item, String value) {
    item.size58 = double.tryParse(value) ?? item.size58;
    update(); // Optional: remove if you don't need real-time UI updates while typing
  }

  void updateFont80(PrintStyleItem item, String value) {
    item.size80 = double.tryParse(value) ?? item.size80;
    update();
  }

  void updateBold(PrintStyleItem item, bool value) {
    item.isBold = value;
    update();
  }

  void updateFontFamily(String value) {
    config.fontFamily = value;
    update();
  }

  void updateDividerStyle(String value) {
    config.dividerStyle = value;
    update();
  }

  void updateMarginTop(double value) {
    config.marginTopMm = value;
    update();
  }

  void updateMarginBottom(double value) {
    config.marginBottomMm = value;
    update();
  }

  void updateMarginLeft(double value) {
    config.marginLeftMm = value;
    update();
  }

  void updateMarginRight(double value) {
    config.marginRightMm = value;
    update();
  }

  void updateLogoWidth(double value) {
    config.logoWidthMm = value;
    update();
  }

  void updateLogoHeight(double value) {
    config.logoHeightMm = value;
    update();
  }

  void updateUpiQrSize(double value) {
    config.upiQrSizeMm = value;
    update();
  }

  void updateFeedbackQrSize(double value) {
    config.feedbackQrSizeMm = value;
    update();
  }

 
  Future<void> saveConfig(BuildContext context, VoidCallback onSaved) async {
    await PrintStyleService.saveConfig(config);
    
    // Trigger the socket reconnect on the HomeScreen
    onSaved(); 

    // Show success message
    Get.snackbar(
      '', '', 
      titleText: const Text(
        '✅ Styles saved — reconnecting socket...',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.green,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
    );

    // Wait 1 second, then pop using native Navigator
    await Future.delayed(const Duration(seconds: 1));
    if (context.mounted) {
      Navigator.pop(context); 
    }
  }

  Future<void> resetDefaults() async {
    await PrintStyleService.resetDefaults();
    config = PrintStyleConfig.defaults();
    update();
    Get.snackbar('Reset', 'Restored to default styles.');
  }

  
}
