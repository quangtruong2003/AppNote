import 'dart:convert';
import 'package:http/http.dart' as http;

class VNBankQR {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final double amount;
  final String message;
  String? _qrUrl;

  VNBankQR({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.amount,
    required this.message,
  });

  String? get qrUrl => _qrUrl;

  /// Generates QR content for Vietnamese bank transfers
  /// This follows the general QR format used by most Vietnamese banking apps
  String generateQRData() {
    // Simplification of the VietQR format
    return [
      'bankName=$bankName',
      'accountNumber=$accountNumber',
      'accountName=$accountName',
      'amount=${amount.toStringAsFixed(0)}',
      'description=$message',
    ].join('|');
  }

  /// Generate QR data specifically for VietQR format (more widely supported)
  String generateVietQR() {
    // This is a simplified version of the VietQR format
    return '2|99|$bankName|$accountNumber|$accountName|${amount.toStringAsFixed(0)}|$message';
  }

  /// Fetches an official VietQR URL for this bank transfer
  Future<String> fetchVietQRUrl() async {
    if (_qrUrl != null) return _qrUrl!;

    try {
      // Get bank ID from bank name
      final bankId = await _getBankId(bankName);
      if (bankId == null) throw Exception('Bank not found');

      // Build VietQR URL
      _qrUrl =
          'https://img.vietqr.io/image/$bankId-$accountNumber-compact.png?amount=${amount.toInt()}&addInfo=$message&accountName=$accountName';
      return _qrUrl!;
    } catch (e) {
      rethrow;
    }
  }

  /// Get bank ID from bank name using VietQR API
  Future<String?> _getBankId(String bankName) async {
    try {
      final response = await http.get(
        Uri.parse('https://api.vietqr.io/v2/banks'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(
          response.statusCode.toString().startsWith('2')
              ? response.body
              : '{"data":[]}',
        );

        // Find bank by name (case insensitive)
        final banks = data['data'] as List<dynamic>;
        final normalizedBankName = bankName.toLowerCase();

        for (var bank in banks) {
          if (bank['name'].toString().toLowerCase().contains(
                normalizedBankName,
              ) ||
              bank['shortName'].toString().toLowerCase().contains(
                normalizedBankName,
              )) {
            return bank['bin'].toString();
          }
        }

        // Bank not found in the list
        return _getDefaultBankId(bankName);
      } else {
        // If API fails, return default mapping
        return _getDefaultBankId(bankName);
      }
    } catch (e) {
      // If any error, return default mapping
      return _getDefaultBankId(bankName);
    }
  }

  /// Fallback method to map common Vietnamese banks to their IDs
  String? _getDefaultBankId(String bankName) {
    final normalizedName = bankName.toLowerCase();

    // Map of common Vietnamese banks and their IDs
    final Map<String, String> bankIds = {
      'vietcombank': 'vcb',
      'techcombank': 'tcb',
      'vietinbank': 'icb',
      'tpbank': 'tpb',
      'mbbank': 'mb',
      'acb': 'acb',
      'vpbank': 'vpb',
      'sacombank': 'scb',
      'bidv': 'bidv',
      'agribank': 'agribank',
      'timo': 'timo',
      'vib': 'vib',
    };

    for (final entry in bankIds.entries) {
      if (normalizedName.contains(entry.key)) {
        return entry.value;
      }
    }

    // Default to VCB if bank not recognized
    return 'vcb';
  }
}
