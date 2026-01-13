import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const String kMidtransApiUrl = 'https://api-midtrans-teal.vercel.app/api';

Future<String?> getMidtransSnapUrl({
  required String orderId,
  required int grossAmount,
  required String name,
  required String email,
}) async {
  final payload = {
    "order_id": orderId,
    "gross_amount": grossAmount,
    "name": name,
    "email": email,
  };

  debugPrint('▶ Mengirim request ke backend: $kMidtransApiUrl');
  debugPrint('Payload: $payload');

  try {
    final response = await http.post(
      Uri.parse(kMidtransApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    debugPrint("Status Code: ${response.statusCode}");
    debugPrint("Response Body: ${response.body}");

    if (response.statusCode != 200) {
      debugPrint("❌ SERVER ERROR (${response.statusCode})");
      return null;
    }

    final data = jsonDecode(response.body);

    final redirectUrl = data['redirect_url'];
    if (redirectUrl == null) {
      debugPrint("❌ redirect_url tidak ditemukan!");
      return null;
    }

    debugPrint("✔ redirect_url diterima: $redirectUrl");
    return redirectUrl;
  } catch (e) {
    debugPrint("❌ EXCEPTION: $e");
    return null;
  }
}
