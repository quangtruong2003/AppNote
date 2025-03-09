class BankInfo {
  final String bankId;
  final String bankName;
  final String bankShortName;
  final String logo;

  BankInfo({
    required this.bankId,
    required this.bankName,
    required this.bankShortName,
    required this.logo,
  });

  factory BankInfo.fromJson(Map<String, dynamic> json) {
    return BankInfo(
      bankId: json['bin'] ?? '',
      bankName: json['name'] ?? '',
      bankShortName: json['shortName'] ?? '',
      logo: json['logo'] ?? '',
    );
  }

  @override
  String toString() {
    return bankShortName;
  }
}
