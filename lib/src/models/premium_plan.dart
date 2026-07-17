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
