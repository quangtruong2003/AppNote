import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class QRService {
  static const String _apiBaseUrl = 'https://api.vietqr.io/v2';

  /// Fetch list of all Vietnamese banks
  static Future<List<Map<String, dynamic>>> fetchBanks() async {
    try {
      final response = await http.get(Uri.parse('$_apiBaseUrl/banks'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        debugPrint('Failed to fetch banks: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching banks: $e');
      return [];
    }
  }

  /// Generate a VietQR URL based on bank and account details
  static String generateVietQRUrl({
    required String bankId,
    required String accountNumber,
    required String accountName,
    double? amount,
    String? message,
    String template = 'compact2',
  }) {
    final Uri uri = Uri.parse(
      'https://img.vietqr.io/image/$bankId-$accountNumber-$template.png',
    );

    final queryParams = <String, String>{};

    if (amount != null && amount > 0) {
      queryParams['amount'] = amount.toInt().toString();
    }

    if (message != null && message.isNotEmpty) {
      queryParams['addInfo'] = message;
    }

    if (accountName.isNotEmpty) {
      queryParams['accountName'] = accountName;
    }

    return uri.replace(queryParameters: queryParams).toString();
  }

  /// Look up bank ID from bank name
  static Future<String?> getBankIdFromName(String bankName) async {
    try {
      final banks = await fetchBanks();
      final normalizedName = bankName.toLowerCase();

      for (var bank in banks) {
        if (bank['name'].toString().toLowerCase().contains(normalizedName) ||
            bank['shortName'].toString().toLowerCase().contains(
              normalizedName,
            )) {
          return bank['bin'].toString();
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error looking up bank ID: $e');
      return null;
    }
  }

  /// Get a fallback bank ID based on common Vietnamese banks
  static String getFallbackBankId(String bankName) {
    final normalizedName = bankName.toLowerCase();

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
      'eximbank': 'eib',
      'oceanbank': 'oceanbank',
      'hdbank': 'hdb',
      'vib': 'vib',
      'seabank': 'seab',
      'baovietbank': 'bvb',
      'namabank': 'nab',
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
