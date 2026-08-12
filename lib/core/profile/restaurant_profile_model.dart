class RestaurantProfileModel {
  final int restaurantId;
  final String restaurantName;
  final String restaurantPhone;
  final String restaurantEmail;
  final String restaurantAddress;
  final String restaurantLogo;
  final String billLogo;
  final dynamic gstStatus;
  final String gstCode;
  final dynamic vatStatus;
  final String vatCode;
  final String fssai;
  final String footerText;
  final String deliveryContactNo;
  final String kotLanguage;

  const RestaurantProfileModel({
    this.restaurantId = 0,
    required this.restaurantName,
    required this.restaurantPhone,
    required this.restaurantEmail,
    required this.restaurantAddress,
    required this.restaurantLogo,
    required this.billLogo,
    required this.gstStatus,
    required this.gstCode,
    required this.vatStatus,
    required this.vatCode,
    required this.fssai,
    required this.footerText,
    required this.deliveryContactNo,
    this.kotLanguage = 'English',
  });

  factory RestaurantProfileModel.empty() {
    return const RestaurantProfileModel(
      restaurantName: '',
      restaurantPhone: '',
      restaurantEmail: '',
      restaurantAddress: '',
      restaurantLogo: '',
      billLogo: '',
      gstStatus: '',
      gstCode: '',
      vatStatus: '',
      vatCode: '',
      fssai: '',
      footerText: '',
      deliveryContactNo: '',
    );
  }

  factory RestaurantProfileModel.fromApi(Map<String, dynamic> json) {
    final restaurants = (json['restaurants'] as List?) ?? const [];
    final restaurant = restaurants.isNotEmpty
        ? Map<String, dynamic>.from(restaurants.first as Map)
        : <String, dynamic>{};

    final vatInfo = json['vat_info'] is Map
        ? Map<String, dynamic>.from(json['vat_info'] as Map)
        : <String, dynamic>{};

    final settings = restaurant['settings'] is Map
        ? Map<String, dynamic>.from(restaurant['settings'] as Map)
        : <String, dynamic>{};

    return RestaurantProfileModel(
      restaurantId: int.tryParse(restaurant['id']?.toString() ?? '') ?? 0,
      restaurantName: restaurant['name']?.toString() ?? '',
      restaurantPhone: json['phone']?.toString() ?? '',
      restaurantEmail: restaurant['email']?.toString() ?? '',
      restaurantAddress: restaurant['address']?.toString() ?? '',
      restaurantLogo: restaurant['logo_path']?.toString() ?? '',
      billLogo: restaurant['bill_logo_path']?.toString() ?? '',
      gstStatus: restaurant['gst_status'],
      gstCode: restaurant['gst_code']?.toString() ?? '',
      vatStatus: vatInfo['status'],
      vatCode: vatInfo['code']?.toString() ?? '',
      fssai: restaurant['fssai']?.toString() ?? '',
      footerText: restaurant['footer_text']?.toString() ?? '',
      deliveryContactNo: restaurant['delivery_contact_no']?.toString() ?? '',
      kotLanguage: settings['kot_language']?.toString() ?? 'English',
    );
  }

  factory RestaurantProfileModel.fromJson(Map<String, dynamic> json) {
    return RestaurantProfileModel(
      restaurantId: int.tryParse(json['restaurantId']?.toString() ?? '') ?? 0,
      restaurantName: json['restaurantName']?.toString() ?? '',
      restaurantPhone: json['restaurantPhone']?.toString() ?? '',
      restaurantEmail: json['restaurantEmail']?.toString() ?? '',
      restaurantAddress: json['restaurantAddress']?.toString() ?? '',
      restaurantLogo: json['restaurantLogo']?.toString() ?? '',
      billLogo: json['billLogo']?.toString() ?? '',
      gstStatus: json['gstStatus'],
      gstCode: json['gstCode']?.toString() ?? '',
      vatStatus: json['vatStatus'],
      vatCode: json['vatCode']?.toString() ?? '',
      fssai: json['fssai']?.toString() ?? '',
      footerText: json['footerText']?.toString() ?? '',
      deliveryContactNo: json['deliveryContactNo']?.toString() ?? '',
      kotLanguage: json['kotLanguage']?.toString() ?? 'English',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'restaurantPhone': restaurantPhone,
      'restaurantEmail': restaurantEmail,
      'restaurantAddress': restaurantAddress,
      'restaurantLogo': restaurantLogo,
      'billLogo': billLogo,
      'gstStatus': gstStatus,
      'gstCode': gstCode,
      'vatStatus': vatStatus,
      'vatCode': vatCode,
      'fssai': fssai,
      'footerText': footerText,
      'deliveryContactNo': deliveryContactNo,
      'kotLanguage': kotLanguage,
    };
  }

  bool get isEmpty =>
      restaurantName.isEmpty &&
      restaurantPhone.isEmpty &&
      restaurantEmail.isEmpty &&
      restaurantAddress.isEmpty &&
      restaurantLogo.isEmpty &&
      billLogo.isEmpty &&
      gstCode.isEmpty &&
      vatCode.isEmpty &&
      fssai.isEmpty &&
      footerText.isEmpty &&
      deliveryContactNo.isEmpty;

  bool get isNotEmpty => !isEmpty;
}