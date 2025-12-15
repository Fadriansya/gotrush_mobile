// midtrans_payment_webview.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

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
  late StreamSubscription<DocumentSnapshot> orderSub;

  @override
  void initState() {
    super.initState();
    orderSub = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
          final status = doc['status'];
          if (status == 'completed') {
            if (mounted) {
              Navigator.pop(context, {'status': 'success'});
            }
          }
        });

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint("PAGE FINISHED: $url");
            if (url.contains("payment-finish")) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context, {'status': 'success'});
                }
              });
            }
          },

          onNavigationRequest: (request) {
            final url = request.url;
            debugPrint("NAV: $url");

            // ============================
            //  DETEKSI CALLBACK CUSTOM SCHEME
            // ============================
            if (url.startsWith(
                  "https://api-midtrans-teal.vercel.app/api/payment-finish",
                ) ||
                url.startsWith(
                  "http://api-midtrans-teal.vercel.app/api/payment-finish",
                )) {
              // Update status order ke 'payment_success' di Firestore
              FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .update({
                    'payment_status': 'success',
                    'status': 'payment_success',
                    'payment_time': Timestamp.now(),
                  });

              widget.onPaymentSuccess?.call();
              // Don't auto-pop, let user close manually
              return NavigationDecision.prevent;
            }

            if (url.startsWith(
                  "https://api-midtrans-teal.vercel.app/api/payment-error",
                ) ||
                url.startsWith(
                  "http://api-midtrans-teal.vercel.app/api/payment-error",
                )) {
              // Use addPostFrameCallback to prevent navigator lock
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context, {'status': 'error'});
                }
              });
              return NavigationDecision.prevent;
            }

            if (url.startsWith(
                  "https://api-midtrans-teal.vercel.app/api/payment-unfinish",
                ) ||
                url.startsWith(
                  "http://api-midtrans-teal.vercel.app/api/payment-unfinish",
                )) {
              // Use addPostFrameCallback to prevent navigator lock
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pop(context, {'status': 'cancel'});
                }
              });
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

  @override
  void dispose() {
    orderSub.cancel();
    super.dispose();
  }
}
