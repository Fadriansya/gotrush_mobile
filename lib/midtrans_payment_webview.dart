import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MidtransPaymentWebView extends StatefulWidget {
  final String snapUrl;
  final String orderId; // new required
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
  late final WebViewController controller;
  bool _checkingServer = false;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            debugPrint("MIDTRANS URL: $url");

            final successPatterns = [
              "status_code=200",
              "transaction_status=settlement",
              "/finish?",
              "success",
              "accept",
              "capture",
            ];

            final isSuccess = successPatterns.any(
              (pattern) => url.contains(pattern),
            );

            if (isSuccess && !_checkingServer) {
              _checkingServer = true;

              // show small progress indicator (optional)
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              // Poll server Firestore doc for status change (timeout 12s)
              _waitForServerConfirmation(
                widget.orderId,
                timeoutSeconds: 12,
              ).then((confirmed) {
                // close progress dialog if still open
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();

                if (confirmed) {
                  debugPrint(
                    "Payment confirmed by server for ${widget.orderId}",
                  );
                } else {
                  debugPrint(
                    "Server did not confirm in time for ${widget.orderId}",
                  );
                }

                if (widget.onPaymentSuccess != null) {
                  widget.onPaymentSuccess!();
                }

                if (mounted) Navigator.of(context).pop();
              });

              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.snapUrl));
  }

  Future<bool> _waitForServerConfirmation(
    String orderId, {
    int timeoutSeconds = 12,
  }) async {
    final docRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
    final end = DateTime.now().add(Duration(seconds: timeoutSeconds));

    while (DateTime.now().isBefore(end)) {
      final snap = await docRef.get();
      final status = (snap.data()?['status'] as String?) ?? '';
      if (status != 'pending_payment' && status != '') {
        // server sudah update (could be 'waiting' or 'payment_failed' etc)
        return true;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return false; // timeout
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pembayaran')),
      body: WebViewWidget(controller: controller),
    );
  }
}
