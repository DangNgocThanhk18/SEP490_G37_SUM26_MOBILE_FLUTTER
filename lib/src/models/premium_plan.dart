class PremiumPlanSettings {
  const PremiumPlanSettings({
    required this.monthlyPrice,
    required this.yearlyPrice,
    required this.benefits,
  });

  final double monthlyPrice;
  final double yearlyPrice;
  final List<String> benefits;

  factory PremiumPlanSettings.fromJson(Map<String, dynamic> json) {
    return PremiumPlanSettings(
      monthlyPrice: _asDouble(json['monthlyPrice']),
      yearlyPrice: _asDouble(json['yearlyPrice']),
      benefits:
          (json['benefits'] as List?)
              ?.map((item) => item.toString())
              .where((item) => item.trim().isNotEmpty)
              .toList() ??
          const [],
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.price,
    required this.currency,
    required this.billingInterval,
    required this.features,
    required this.recommended,
    this.badge,
  });

  final String id;
  final String code;
  final String name;
  final double price;
  final String currency;
  final String billingInterval;
  final List<String> features;
  final bool recommended;
  final String? badge;

  bool get isYearly => billingInterval.toUpperCase() == 'YEAR';

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    return SubscriptionPlan(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: PremiumPlanSettings._asDouble(json['price']),
      currency: (json['currency'] ?? 'VND').toString(),
      billingInterval: (json['billingInterval'] ?? '').toString(),
      features: rawFeatures is List
          ? rawFeatures
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [],
      recommended: json['recommended'] == true,
      badge: _optionalText(json['badge']),
    );
  }
}

class CheckoutSession {
  const CheckoutSession({required this.sessionId, required this.checkoutUrl});

  final String sessionId;
  final String checkoutUrl;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) =>
      CheckoutSession(
        sessionId: (json['sessionId'] ?? '').toString(),
        checkoutUrl: (json['checkoutUrl'] ?? '').toString(),
      );
}

class CheckoutStatus {
  const CheckoutStatus({
    required this.sessionId,
    required this.paymentStatus,
    required this.premiumActive,
  });

  final String sessionId;
  final String paymentStatus;
  final bool premiumActive;

  bool get completed => premiumActive || paymentStatus.toUpperCase() == 'PAID';

  factory CheckoutStatus.fromJson(Map<String, dynamic> json) => CheckoutStatus(
    sessionId: (json['sessionId'] ?? '').toString(),
    paymentStatus: (json['paymentStatus'] ?? '').toString(),
    premiumActive: json['premiumActive'] == true,
  );
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
