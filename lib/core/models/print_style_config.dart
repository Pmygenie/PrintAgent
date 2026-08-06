class PrintStyleItem {
  // Windows PDF point sizes and weight.
  double size58;
  double size80;
  bool isBold;

  // Android ESC/POS character scale (1-8) and weight.
  int escSize58;
  int escSize80;
  bool escBold;

  PrintStyleItem({
    required this.size58,
    required this.size80,
    required this.isBold,
    this.escSize58 = 1,
    this.escSize80 = 1,
    this.escBold = false,
  });

  Map<String, dynamic> toJson() => {
        'size58': size58,
        'size80': size80,
        'isBold': isBold,
        'escSize58': escSize58,
        'escSize80': escSize80,
        'escBold': escBold,
      };

  factory PrintStyleItem.fromJson(
    Map<String, dynamic> json, {
    PrintStyleItem? fallback,
  }) {
    int escSize(String key, int defaultValue) {
      return ((json[key] as num?)?.toInt() ?? defaultValue).clamp(1, 8);
    }

    return PrintStyleItem(
      size58: (json['size58'] as num?)?.toDouble() ?? fallback?.size58 ?? 10.0,
      size80: (json['size80'] as num?)?.toDouble() ?? fallback?.size80 ?? 10.0,
      isBold: json['isBold'] as bool? ?? fallback?.isBold ?? false,
      escSize58: escSize('escSize58', fallback?.escSize58 ?? 1),
      escSize80: escSize('escSize80', fallback?.escSize80 ?? 1),
      escBold: json['escBold'] as bool? ?? fallback?.escBold ?? false,
    );
  }
}

class PrintStyleConfig {
  // BILL
  PrintStyleItem restaurantName;
  PrintStyleItem restaurantAddress;
  PrintStyleItem restaurantPhone;
  PrintStyleItem restaurantGst;
  PrintStyleItem restaurantFssai;

  PrintStyleItem billInfoRow1;
  PrintStyleItem billInfoRow2;
  PrintStyleItem billInfoRow3;
  PrintStyleItem billInfoRow4;

  PrintStyleItem billTableHeader;
  PrintStyleItem billTableContent;
  PrintStyleItem billTableQty;
  PrintStyleItem billTableMeta;

  PrintStyleItem orderNote;

  PrintStyleItem billAmountLine;
  PrintStyleItem billTotal;
  PrintStyleItem billGrandTotal;
  PrintStyleItem billPaidBy;

  PrintStyleItem deliveryHeader;
  PrintStyleItem deliveryContent;

  PrintStyleItem roomHeader;
  PrintStyleItem roomContent;

  PrintStyleItem footer;

  // KOT
  PrintStyleItem kotTitle;
  PrintStyleItem cancelKotTitle;

  PrintStyleItem kotOrderInfo1;
  PrintStyleItem kotOrderInfo2;
  PrintStyleItem kotOrderInfo3;
  PrintStyleItem kotOrderInfo4;

  PrintStyleItem kotTableHeader;
  PrintStyleItem kotTableContent;
  PrintStyleItem kotNote;

  //Universal
  String fontFamily;
  String dividerStyle;

  // Margins (mm)
  double marginTopMm;
  double marginBottomMm;
  double marginLeftMm;
  double marginRightMm;

  // Logo size (mm) — applied to bill prints only
  double logoWidthMm;
  double logoHeightMm;

  // QR code size (mm) — applied to bill prints only (Windows PDF path)
  double upiQrSizeMm;
  double feedbackQrSizeMm;

  // Android ESC/POS media sizes (shared by 58mm and 80mm).
  double escLogoSizeMm;
  double escUpiQrSizeMm;
  double escFeedbackQrSizeMm;

  PrintStyleConfig({
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantPhone,
    required this.restaurantGst,
    required this.restaurantFssai,
    required this.billInfoRow1,
    required this.billInfoRow2,
    required this.billInfoRow3,
    required this.billInfoRow4,
    required this.billTableHeader,
    required this.billTableContent,
    required this.billTableQty,
    required this.billTableMeta,
    required this.orderNote,
    required this.billAmountLine,
    required this.billTotal,
    required this.billGrandTotal,
    required this.billPaidBy,
    required this.deliveryHeader,
    required this.deliveryContent,
    required this.roomHeader,
    required this.roomContent,
    required this.footer,
    required this.kotTitle,
    required this.cancelKotTitle,
    required this.kotOrderInfo1,
    required this.kotOrderInfo2,
    required this.kotOrderInfo3,
    required this.kotOrderInfo4,
    required this.kotTableHeader,
    required this.kotTableContent,
    required this.kotNote,
    required this.fontFamily,
    required this.dividerStyle,
    this.marginTopMm = 0.0,
    this.marginBottomMm = 0.0,
    this.marginLeftMm = 0.0,
    this.marginRightMm = 0.0,
    this.logoWidthMm = 30.0,
    this.logoHeightMm = 30.0,
    this.upiQrSizeMm = 25.0,
    this.feedbackQrSizeMm = 25.0,
    this.escLogoSizeMm = 30.0,
    this.escUpiQrSizeMm = 25.0,
    this.escFeedbackQrSizeMm = 25.0,
  });

  factory PrintStyleConfig.defaults() {
    return PrintStyleConfig(
      // BILL HEADERS
      restaurantName: PrintStyleItem(
        size58: 11,
        size80: 14,
        isBold: true,
        escSize58: 2,
        escSize80: 2,
        escBold: true,
      ),
      restaurantAddress: PrintStyleItem(size58: 6, size80: 7, isBold: false),
      restaurantPhone: PrintStyleItem(size58: 6, size80: 7, isBold: false),
      restaurantGst: PrintStyleItem(size58: 6, size80: 7, isBold: false),
      restaurantFssai: PrintStyleItem(size58: 6, size80: 7, isBold: false),

      // BILL INFO
      billInfoRow1:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      billInfoRow2:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      billInfoRow3:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      billInfoRow4:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),

      // BILL TABLE
      billTableHeader:
          PrintStyleItem(size58: 7, size80: 8, isBold: true, escBold: true),
      billTableContent: PrintStyleItem(size58: 7, size80: 8, isBold: false),
      billTableQty: PrintStyleItem(size58: 7, size80: 8, isBold: false),
      billTableMeta: PrintStyleItem(size58: 6, size80: 7, isBold: false),
      orderNote:
          PrintStyleItem(size58: 7, size80: 8, isBold: true, escBold: true),

      // BILL TOTALS
      billAmountLine: PrintStyleItem(size58: 6, size80: 7, isBold: false),
      billTotal:
          PrintStyleItem(size58: 7, size80: 8, isBold: true, escBold: true),
      billGrandTotal:
          PrintStyleItem(size58: 7, size80: 8, isBold: true, escBold: true),
      billPaidBy: PrintStyleItem(
          size58: 5.5, size80: 6.5, isBold: false, escBold: true),

      // DELIVERY & ROOM
      deliveryHeader:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      deliveryContent:
          PrintStyleItem(size58: 6, size80: 7, isBold: true, escBold: false),
      roomHeader:
          PrintStyleItem(size58: 6, size80: 7, isBold: true, escBold: true),
      roomContent: PrintStyleItem(size58: 6, size80: 7, isBold: false),

      footer: PrintStyleItem(size58: 6, size80: 7, isBold: false),

      // KOT
      kotTitle: PrintStyleItem(
        size58: 11,
        size80: 14,
        isBold: true,
        escSize58: 2,
        escSize80: 2,
        escBold: true,
      ),
      cancelKotTitle: PrintStyleItem(
        size58: 9,
        size80: 14,
        isBold: true,
        escSize58: 2,
        escSize80: 2,
        escBold: true,
      ),
      kotOrderInfo1:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      kotOrderInfo2:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      kotOrderInfo3:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      kotOrderInfo4:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      kotTableHeader:
          PrintStyleItem(size58: 6, size80: 7, isBold: true, escBold: true),
      kotTableContent:
          PrintStyleItem(size58: 6, size80: 7, isBold: false, escBold: true),
      kotNote:
          PrintStyleItem(size58: 6, size80: 7, isBold: true, escBold: true),

      //Universal
      fontFamily: 'Montserrat',
      dividerStyle: 'Dashed',
    );
  }

  Map<String, dynamic> toJson() => {
        'restaurantName': restaurantName.toJson(),
        'restaurantAddress': restaurantAddress.toJson(),
        'restaurantPhone': restaurantPhone.toJson(),
        'restaurantGst': restaurantGst.toJson(),
        'restaurantFssai': restaurantFssai.toJson(),
        'billInfoRow1': billInfoRow1.toJson(),
        'billInfoRow2': billInfoRow2.toJson(),
        'billInfoRow3': billInfoRow3.toJson(),
        'billInfoRow4': billInfoRow4.toJson(),
        'billTableHeader': billTableHeader.toJson(),
        'billTableContent': billTableContent.toJson(),
        'billTableQty': billTableQty.toJson(),
        'billTableMeta': billTableMeta.toJson(),
        'orderNote': orderNote.toJson(),
        'billAmountLine': billAmountLine.toJson(),
        'billTotal': billTotal.toJson(),
        'billGrandTotal': billGrandTotal.toJson(),
        'billPaidBy': billPaidBy.toJson(),
        'deliveryHeader': deliveryHeader.toJson(),
        'deliveryContent': deliveryContent.toJson(),
        'roomHeader': roomHeader.toJson(),
        'roomContent': roomContent.toJson(),
        'footer': footer.toJson(),
        'kotTitle': kotTitle.toJson(),
        'cancelKotTitle': cancelKotTitle.toJson(),
        'kotOrderInfo1': kotOrderInfo1.toJson(),
        'kotOrderInfo2': kotOrderInfo2.toJson(),
        'kotOrderInfo3': kotOrderInfo3.toJson(),
        'kotOrderInfo4': kotOrderInfo4.toJson(),
        'kotTableHeader': kotTableHeader.toJson(),
        'kotTableContent': kotTableContent.toJson(),
        'kotNote': kotNote.toJson(),
        'fontFamily': fontFamily,
        'dividerStyle': dividerStyle,
        'marginTopMm': marginTopMm,
        'marginBottomMm': marginBottomMm,
        'marginLeftMm': marginLeftMm,
        'marginRightMm': marginRightMm,
        'logoWidthMm': logoWidthMm,
        'logoHeightMm': logoHeightMm,
        'upiQrSizeMm': upiQrSizeMm,
        'feedbackQrSizeMm': feedbackQrSizeMm,
        'escLogoSizeMm': escLogoSizeMm,
        'escUpiQrSizeMm': escUpiQrSizeMm,
        'escFeedbackQrSizeMm': escFeedbackQrSizeMm,
      };

  factory PrintStyleConfig.fromJson(Map<String, dynamic> json) {
    final def = PrintStyleConfig.defaults();
    PrintStyleItem parseItem(String key, PrintStyleItem fallback) {
      if (json[key] is Map) {
        return PrintStyleItem.fromJson(
          Map<String, dynamic>.from(json[key] as Map),
          fallback: fallback,
        );
      }
      return fallback;
    }

    return PrintStyleConfig(
      restaurantName: parseItem('restaurantName', def.restaurantName),
      restaurantAddress: parseItem('restaurantAddress', def.restaurantAddress),
      restaurantPhone: parseItem('restaurantPhone', def.restaurantPhone),
      restaurantGst: parseItem('restaurantGst', def.restaurantGst),
      restaurantFssai: parseItem('restaurantFssai', def.restaurantFssai),
      billInfoRow1: parseItem('billInfoRow1', def.billInfoRow1),
      billInfoRow2: parseItem('billInfoRow2', def.billInfoRow2),
      billInfoRow3: parseItem('billInfoRow3', def.billInfoRow3),
      billInfoRow4: parseItem('billInfoRow4', def.billInfoRow4),
      billTableHeader: parseItem('billTableHeader', def.billTableHeader),
      billTableContent: parseItem('billTableContent', def.billTableContent),
      billTableQty: parseItem('billTableQty', def.billTableQty),
      billTableMeta: parseItem('billTableMeta', def.billTableMeta),
      orderNote: parseItem('orderNote', def.orderNote),
      billAmountLine: parseItem('billAmountLine', def.billAmountLine),
      billTotal: parseItem('billTotal', def.billTotal),
      billGrandTotal: parseItem('billGrandTotal', def.billGrandTotal),
      billPaidBy: parseItem('billPaidBy', def.billPaidBy),
      deliveryHeader: parseItem('deliveryHeader', def.deliveryHeader),
      deliveryContent: parseItem('deliveryContent', def.deliveryContent),
      roomHeader: parseItem('roomHeader', def.roomHeader),
      roomContent: parseItem('roomContent', def.roomContent),
      footer: parseItem('footer', def.footer),
      kotTitle: parseItem('kotTitle', def.kotTitle),
      cancelKotTitle: parseItem('cancelKotTitle', def.cancelKotTitle),
      kotOrderInfo1: parseItem('kotOrderInfo1', def.kotOrderInfo1),
      kotOrderInfo2: parseItem('kotOrderInfo2', def.kotOrderInfo2),
      kotOrderInfo3: parseItem('kotOrderInfo3', def.kotOrderInfo3),
      kotOrderInfo4: parseItem('kotOrderInfo4', def.kotOrderInfo4),
      kotTableHeader: parseItem('kotTableHeader', def.kotTableHeader),
      kotTableContent: parseItem('kotTableContent', def.kotTableContent),
      kotNote: parseItem('kotNote', def.kotNote),
      fontFamily: json['fontFamily']?.toString() ?? def.fontFamily,
      dividerStyle: json['dividerStyle']?.toString() ?? def.dividerStyle,
      marginTopMm: (json['marginTopMm'] as num?)?.toDouble() ?? 0.0,
      marginBottomMm: (json['marginBottomMm'] as num?)?.toDouble() ?? 0.0,
      marginLeftMm: (json['marginLeftMm'] as num?)?.toDouble() ?? 0.0,
      marginRightMm: (json['marginRightMm'] as num?)?.toDouble() ?? 0.0,
      logoWidthMm: (json['logoWidthMm'] as num?)?.toDouble() ?? 30.0,
      logoHeightMm: (json['logoHeightMm'] as num?)?.toDouble() ?? 30.0,
      upiQrSizeMm: (json['upiQrSizeMm'] as num?)?.toDouble() ?? 25.0,
      feedbackQrSizeMm: (json['feedbackQrSizeMm'] as num?)?.toDouble() ?? 25.0,
      escLogoSizeMm: (json['escLogoSizeMm'] as num?)?.toDouble() ??
          (json['logoWidthMm'] as num?)?.toDouble() ??
          def.escLogoSizeMm,
      escUpiQrSizeMm:
          _escQrSizeMm(json['escUpiQrSizeMm'], def.escUpiQrSizeMm),
      escFeedbackQrSizeMm:
          _escQrSizeMm(json['escFeedbackQrSizeMm'], def.escFeedbackQrSizeMm),
    );
  }

  /// Older configs stored a 1–8 ESC/POS module size under these keys. Such a
  /// value is far too small to be a millimetre size, so fall back to the
  /// default instead of printing a QR a few millimetres wide.
  static double _escQrSizeMm(dynamic raw, double fallback) {
    final value = (raw as num?)?.toDouble();
    if (value == null || value < 10.0) return fallback;
    return value;
  }
}
