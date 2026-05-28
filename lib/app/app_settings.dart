import "../core/models/print_models.dart";

class AgentSettings {
  AgentSettings({
    required this.socketUrl,
    required this.restaurantId,
    required this.kitchenPrinterIp,
    required this.kitchenPaper,
    required this.billingPrinterIp,
    required this.billingPaper,
  });

  final String socketUrl;
  final int restaurantId;
  final String kitchenPrinterIp;
  final PaperKind kitchenPaper;
  final String billingPrinterIp;
  final PaperKind billingPaper;

  AgentSettings copyWith({
    String? socketUrl,
    int? restaurantId,
    String? kitchenPrinterIp,
    PaperKind? kitchenPaper,
    String? billingPrinterIp,
    PaperKind? billingPaper,
  }) {
    return AgentSettings(
      socketUrl: socketUrl ?? this.socketUrl,
      restaurantId: restaurantId ?? this.restaurantId,
      kitchenPrinterIp: kitchenPrinterIp ?? this.kitchenPrinterIp,
      kitchenPaper: kitchenPaper ?? this.kitchenPaper,
      billingPrinterIp: billingPrinterIp ?? this.billingPrinterIp,
      billingPaper: billingPaper ?? this.billingPaper,
    );
  }
}

class AgentSettingsDefaults {
  static AgentSettings values() {
    return AgentSettings(
      socketUrl: "https://presocket.mygenie.online",
      restaurantId: 618,
      kitchenPrinterIp: "192.168.1.100",
      kitchenPaper: PaperKind.mm58,
      billingPrinterIp: "192.168.1.101",
      billingPaper: PaperKind.mm80,
    );
  }
}
