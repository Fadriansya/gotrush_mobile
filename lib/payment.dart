import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String?> getMidtransSnapUrl({
  required String orderId,
  required int grossAmount,
  required String name,
  required String email,
}) async {
  final url = Uri.parse('https://api-midtrans-teal.vercel.app/api/index');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'order_id': orderId,
      'gross_amount': grossAmount,
      'name': name,
      'email': email,
    }),
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['redirect_url']; // atau data['token'] jika pakai Snap SDK
  }
  return null;
}
