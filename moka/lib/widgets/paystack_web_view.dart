import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  State<PaystackWebView> createState() =>
      _PaystackWebViewState();
}

class _PaystackWebViewState
    extends State<PaystackWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(
          JavaScriptMode.unrestricted)
      ..setBackgroundColor(
          const Color(0xFF0D0D0D))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted)
              setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted)
              setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final url = request.url.toLowerCase();

            // Paystack success indicators
            if (url.contains('callback') ||
                url.contains('success') ||
                url.contains(
                    widget.reference.toLowerCase()) ||
                url.contains('trxref=') ||
                url.contains('transaction_id=')) {
              widget.onSuccess();
              return NavigationDecision.prevent;
            }

            // Paystack cancel indicators
            if (url.contains('cancel') ||
                url.contains('close') ||
                url.contains('declined')) {
              widget.onCancel();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint(
                'WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(
          Uri.parse(widget.authorizationUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white),
          onPressed: () {
            widget.onCancel();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Complete Payment',
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16),
        ),
        // Secure indicator
        actions: [
          Container(
            margin: const EdgeInsets.only(
                right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50)
                  .withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF4CAF50)
                      .withOpacity(0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline,
                    color: Color(0xFF4CAF50),
                    size: 12),
                SizedBox(width: 4),
                Text('Secure',
                    style: TextStyle(
                        color: Color(0xFF4CAF50),
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: const Color(0xFF0D0D0D),
              child: const Center(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                        color: Color(0xFFFF6B00)),
                    SizedBox(height: 16),
                    Text('Loading payment...',
                        style: TextStyle(
                            color:
                                Color(0xFF888888),
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}