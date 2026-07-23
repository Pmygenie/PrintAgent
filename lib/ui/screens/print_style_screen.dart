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
