import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MidtransPaymentWebView extends StatefulWidget {
  final String snapUrl;
  final String orderId;
  final VoidCallback? onPaymentSuccess;

  const MidtransPaymentWebView({
    required this.snapUrl,
    required this.orderId,
    this.onPaymentSuccess,
    super.key,
  });

  @override
  State<MidtransPaymentWebView> createState() => _MidtransPaymentWebViewState();
}

class _MidtransPaymentWebViewState extends State<MidtransPaymentWebView> {
  late WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint("NAV: $url");

            // ============================
            //  DETEKSI CALLBACK CUSTOM SCHEME
            // ============================
            if (url.startsWith(
              "http://api-midtrans-teal.vercel.app/api/payment-finish",
            )) {
              widget.onPaymentSuccess?.call();
              Navigator.pop(context, {'status': 'success'});
              return NavigationDecision.prevent;
            }

            if (url.startsWith(
              "http://api-midtrans-teal.vercel.app/api/payment-error",
            )) {
              Navigator.pop(context, {'status': 'error'});
              return NavigationDecision.prevent;
            }

            if (url.startsWith(
              "http://api-midtrans-teal.vercel.app/api/payment-unfinish",
            )) {
              Navigator.pop(context, {'status': 'cancel'});
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.snapUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pembayaran")),
      body: WebViewWidget(controller: controller),
    );
  }
}
