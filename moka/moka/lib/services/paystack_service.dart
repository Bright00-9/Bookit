import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaystackService {
  static String generateReference() {
    return 'PAYSTACK_${DateTime.now().millisecondsSinceEpoch}';
  }
}

class PaystackWebView extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  const PaystackWebView({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<PaystackWebView> createState() => _PaystackWebViewState();
}

class _PaystackWebViewState extends State<PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onNavigationRequest: (request) {
          final url = request.url;
          if (url.contains('callback') ||
              url.contains('success') ||
              url.contains(widget.reference)) {
            widget.onSuccess();
            return NavigationDecision.prevent;
          }

          if (url.contains('cancel') || url.contains('close')) {
            widget.onCancel();
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
