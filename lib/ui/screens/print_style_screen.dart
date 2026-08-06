import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printer_agent/core/constants.dart/print_style_constants.dart';
import '../../core/controller/print_style_controller.dart';
import '../../core/models/print_style_config.dart';

class PrintStyleScreen extends StatelessWidget {
  final VoidCallback onSaved;
  const PrintStyleScreen({Key? key, required this.onSaved}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PrintStyleController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Style Configuration'),
        centerTitle: true,
      ),
      body: GetBuilder<PrintStyleController>(
        builder: (ctrl) {
          if (ctrl.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final c = ctrl.config;

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              //GLOBAL SETTINGS SECTION
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('GLOBAL SETTINGS',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: c.fontFamily,
                        decoration: const InputDecoration(
                            labelText: 'Receipt Font Family',
                            border: OutlineInputBorder()),
                        items: PrintStyleConstants.availableFonts
                            .map((f) =>
                                DropdownMenuItem(value: f, child: Text(f)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) ctrl.updateFontFamily(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: c.dividerStyle,
                        decoration: const InputDecoration(
                            labelText: 'Divider Line Style',
                            border: OutlineInputBorder()),
                        items: PrintStyleConstants.availableDividers
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) ctrl.updateDividerStyle(v);
                        },
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Page Margins (mm)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMarginField(
                              label: 'Top',
                              value: c.marginTopMm,
                              onChanged: ctrl.updateMarginTop,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMarginField(
                              label: 'Bottom',
                              value: c.marginBottomMm,
                              onChanged: ctrl.updateMarginBottom,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMarginField(
                              label: 'Left',
                              value: c.marginLeftMm,
                              onChanged: ctrl.updateMarginLeft,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMarginField(
                              label: 'Right',
                              value: c.marginRightMm,
                              onChanged: ctrl.updateMarginRight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bill Logo Size (mm)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMarginField(
                              label: 'Width',
                              value: c.logoWidthMm,
                              onChanged: ctrl.updateLogoWidth,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMarginField(
                              label: 'Height',
                              value: c.logoHeightMm,
                              onChanged: ctrl.updateLogoHeight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'QR Code Size (mm)',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMarginField(
                              label: 'UPI QR',
                              value: c.upiQrSizeMm,
                              onChanged: ctrl.updateUpiQrSize,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMarginField(
                              label: 'Feedback QR',
                              value: c.feedbackQrSizeMm,
                              onChanged: ctrl.updateFeedbackQrSize,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('BILL SETTINGS',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('BILL SETTINGS',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ExpansionTile(
                title: const Text('Restaurant Header'),
                children: [
                  _buildStyleRow('Restaurant Name', c.restaurantName, ctrl),
                  _buildStyleRow(
                      'Restaurant Address', c.restaurantAddress, ctrl),
                  _buildStyleRow('Restaurant Phone', c.restaurantPhone, ctrl),
                  _buildStyleRow('GST', c.restaurantGst, ctrl),
                  _buildStyleRow('FSSAI', c.restaurantFssai, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Bill Information'),
                children: [
                  _buildStyleRow('Bill Info Row 1', c.billInfoRow1, ctrl),
                  _buildStyleRow('Bill Info Row 2', c.billInfoRow2, ctrl),
                  _buildStyleRow('Bill Info Row 3', c.billInfoRow3, ctrl),
                  _buildStyleRow('Bill Info Row 4', c.billInfoRow4, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Bill Table'),
                children: [
                  _buildStyleRow('Table Header', c.billTableHeader, ctrl),
                  _buildStyleRow('Table Content', c.billTableContent, ctrl),
                  _buildStyleRow('Table Qty', c.billTableQty, ctrl),
                  _buildStyleRow('Table Meta', c.billTableMeta, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Amount Section'),
                children: [
                  _buildStyleRow('Amount Breakdown', c.billAmountLine, ctrl),
                  _buildStyleRow('Total', c.billTotal, ctrl),
                  _buildStyleRow('Grand Total', c.billGrandTotal, ctrl),
                  _buildStyleRow('Paid By', c.billPaidBy, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Delivery Section'),
                children: [
                  _buildStyleRow('Delivery Header', c.deliveryHeader, ctrl),
                  _buildStyleRow('Delivery Content', c.deliveryContent, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Room Section'),
                children: [
                  _buildStyleRow('Room Header', c.roomHeader, ctrl),
                  _buildStyleRow('Room Content', c.roomContent, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('Footer'),
                children: [
                  _buildStyleRow('Footer Text', c.footer, ctrl),
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(top: 24.0, bottom: 8.0),
                child: Text('KOT SETTINGS',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ExpansionTile(
                title: const Text('KOT Header'),
                children: [
                  _buildStyleRow('KOT Title', c.kotTitle, ctrl),
                  _buildStyleRow('Cancel KOT Title', c.cancelKotTitle, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('KOT Information'),
                children: [
                  _buildStyleRow('Order Info Row 1', c.kotOrderInfo1, ctrl),
                  _buildStyleRow('Order Info Row 2', c.kotOrderInfo2, ctrl),
                  _buildStyleRow('Order Info Row 3', c.kotOrderInfo3, ctrl),
                  _buildStyleRow('Order Info Row 4', c.kotOrderInfo4, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('KOT Table'),
                children: [
                  _buildStyleRow('Table Header', c.kotTableHeader, ctrl),
                  _buildStyleRow('Table Content', c.kotTableContent, ctrl),
                ],
              ),
              ExpansionTile(
                title: const Text('KOT Notes'),
                children: [
                  _buildStyleRow('Note', c.kotNote, ctrl),
                ],
              ),

              const Padding(
                padding: EdgeInsets.only(top: 32.0, bottom: 8.0),
                child: Text(
                  'ANDROID ESC/POS SETTINGS',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Android thermal printers support character sizes 1–8. '
                  'The 58mm and 80mm settings are independent.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              ..._buildAndroidStyleSections(c, ctrl),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.resetDefaults(),
                  child: const Text('RESET DEFAULTS'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => controller.saveConfig(context, onSaved),
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAndroidStyleSections(
      PrintStyleConfig c, PrintStyleController ctrl) {
    return [
      Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Android Global Settings',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildMarginField(
                label: 'Logo Size',
                value: c.escLogoSizeMm,
                onChanged: ctrl.updateEscLogoSize,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMarginField(
                      label: 'UPI QR Size',
                      value: c.escUpiQrSizeMm,
                      onChanged: ctrl.updateEscUpiQrSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMarginField(
                      label: 'Feedback QR Size',
                      value: c.escFeedbackQrSizeMm,
                      onChanged: ctrl.updateEscFeedbackQrSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ExpansionTile(
        title: const Text('Android Restaurant Header'),
        children: [
          _buildAndroidStyleRow('Restaurant Name', c.restaurantName, ctrl),
          _buildAndroidStyleRow(
              'Restaurant Address', c.restaurantAddress, ctrl),
          _buildAndroidStyleRow('Restaurant Phone', c.restaurantPhone, ctrl),
          _buildAndroidStyleRow('GST', c.restaurantGst, ctrl),
          _buildAndroidStyleRow('FSSAI', c.restaurantFssai, ctrl),
        ],
      ),
      ExpansionTile(
        title: const Text('Android Bill Information'),
        children: [
          _buildAndroidStyleRow('Bill Info Row 1', c.billInfoRow1, ctrl),
          _buildAndroidStyleRow('Bill Info Row 2', c.billInfoRow2, ctrl),
          _buildAndroidStyleRow('Bill Info Row 3', c.billInfoRow3, ctrl),
          _buildAndroidStyleRow('Bill Info Row 4', c.billInfoRow4, ctrl),
        ],
      ),
      ExpansionTile(
        title: const Text('Android Bill Table'),
        children: [
          _buildAndroidStyleRow('Table Header', c.billTableHeader, ctrl),
          _buildAndroidStyleRow('Table Content', c.billTableContent, ctrl),
          _buildAndroidStyleRow('Table Qty', c.billTableQty, ctrl),
          _buildAndroidStyleRow('Table Meta', c.billTableMeta, ctrl),
          _buildAndroidStyleRow('Order Note', c.orderNote, ctrl),
        ],
      ),
      ExpansionTile(
        title: const Text('Android Amount Section'),
        children: [
          _buildAndroidStyleRow('Amount Breakdown', c.billAmountLine, ctrl),
          _buildAndroidStyleRow('Total', c.billTotal, ctrl),
          _buildAndroidStyleRow('Grand Total', c.billGrandTotal, ctrl),
          _buildAndroidStyleRow('Paid By', c.billPaidBy, ctrl),
        ],
      ),
      ExpansionTile(
        title: const Text('Android Delivery and Room'),
        children: [
          _buildAndroidStyleRow('Delivery Header', c.deliveryHeader, ctrl),
          _buildAndroidStyleRow('Delivery Content', c.deliveryContent, ctrl),
          _buildAndroidStyleRow('Room Header', c.roomHeader, ctrl),
          _buildAndroidStyleRow('Room Content', c.roomContent, ctrl),
          _buildAndroidStyleRow('Footer Text', c.footer, ctrl),
        ],
      ),
      ExpansionTile(
        title: const Text('Android KOT'),
        children: [
          _buildAndroidStyleRow('KOT Title', c.kotTitle, ctrl),
          _buildAndroidStyleRow('Cancel KOT Title', c.cancelKotTitle, ctrl),
          _buildAndroidStyleRow('Order Info Row 1', c.kotOrderInfo1, ctrl),
          _buildAndroidStyleRow('Order Info Row 2', c.kotOrderInfo2, ctrl),
          _buildAndroidStyleRow('Order Info Row 3', c.kotOrderInfo3, ctrl),
          _buildAndroidStyleRow('Order Info Row 4', c.kotOrderInfo4, ctrl),
          _buildAndroidStyleRow('Table Header', c.kotTableHeader, ctrl),
          _buildAndroidStyleRow('Table Content', c.kotTableContent, ctrl),
          _buildAndroidStyleRow('Note', c.kotNote, ctrl),
        ],
      ),
    ];
  }

  Widget _buildAndroidStyleRow(
      String label, PrintStyleItem item, PrintStyleController ctrl) {
    final sizes = List<int>.generate(8, (index) => index + 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: item.escSize58,
                  decoration: const InputDecoration(
                    labelText: '58mm Size',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: sizes
                      .map((size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) ctrl.updateEscSize58(item, value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: item.escSize80,
                  decoration: const InputDecoration(
                    labelText: '80mm Size',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: sizes
                      .map((size) => DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) ctrl.updateEscSize80(item, value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const Text('Bold', style: TextStyle(fontSize: 12)),
                  Checkbox(
                    value: item.escBold,
                    onChanged: (value) {
                      if (value != null) ctrl.updateEscBold(item, value);
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildStyleRow(
      String label, PrintStyleItem item, PrintStyleController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.size58.toString(),
                  decoration: const InputDecoration(
                    labelText: '58mm Size',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => ctrl.updateFont58(item, val),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  initialValue: item.size80.toString(),
                  decoration: const InputDecoration(
                    labelText: '80mm Size',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => ctrl.updateFont80(item, val),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  const Text('Bold', style: TextStyle(fontSize: 12)),
                  Checkbox(
                    value: item.isBold,
                    onChanged: (val) {
                      if (val != null) ctrl.updateBold(item, val);
                    },
                  ),
                ],
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildMarginField({
    required String label,
    required double value,
    required void Function(double) onChanged,
  }) {
    return TextFormField(
      initialValue: value.toStringAsFixed(1),
      decoration: InputDecoration(
        labelText: '$label (mm)',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null && parsed >= 0) onChanged(parsed);
      },
    );
  }
}
