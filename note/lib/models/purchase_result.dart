class PurchaseResult {
  final bool success;
  final String message;
  final dynamic data;

  PurchaseResult({required this.success, required this.message, this.data});
}
