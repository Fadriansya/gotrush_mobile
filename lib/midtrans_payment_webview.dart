import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Import paket webview

// 1. Ubah menjadi StatefulWidget
class MidtransPaymentWebView extends StatefulWidget {
  final String snapUrl;
  const MidtransPaymentWebView({required this.snapUrl, super.key});

  @override
  State<MidtransPaymentWebView> createState() => _MidtransPaymentWebViewState();
}

class _MidtransPaymentWebViewState extends State<MidtransPaymentWebView> {
  // 2. Deklarasikan dan inisialisasi WebViewController
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    // 2a. Buat konfigurasi controller
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Opsi tambahan yang mungkin Anda perlukan untuk Midtrans
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Opsional: Tampilkan indikator loading
          },
          onPageStarted: (String url) {
            // Opsional: Log saat halaman mulai dimuat
          },
          onPageFinished: (String url) {
            // Opsional: Log saat halaman selesai dimuat
          },
          onWebResourceError: (WebResourceError error) {
            // Opsional: Tangani error loading
          },
          // Ini PENTING untuk Midtrans:
          // Anda mungkin perlu mencegat URL spesifik (misalnya, 'midtrans://')
          // untuk mengarahkan pengguna kembali ke aplikasi Anda
          onNavigationRequest: (NavigationRequest request) {
            // Contoh sederhana:
            if (request.url.startsWith('https://google.com')) {
              // Misal: URL callback success Anda
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      // 2b. Muat URL Snap Midtrans
      ..loadRequest(Uri.parse(widget.snapUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      // 3. Gunakan WebViewWidget dan berikan controller
      body: WebViewWidget(controller: controller),
    );
  }
}
