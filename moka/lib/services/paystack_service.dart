import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/settings_model.dart';

class PaystackService {
  // ── Replace with your Paystack public key ──
  static const String _publicKey = 'pk_test_your_key_here';
  static const String _secretKey = 'sk_test_your_key_here'; // keep server-side ideally

  // ── Generate unique reference ──────────────────────────────────
  static String generateReference() {
    return 'ACCEPT_FEE_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ── Initialize transaction via Paystack API ───────────────────
  // Returns the authorization_url to load in WebView
  static Future<Map<String, dynamic>> initializeTransaction({
    required String email,
    required double amountGhc,
    required String reference,
    Map<String, dynamic>? metadata,
  }) async {
    // Paystack amount is in pesewas (GHC * 100)
    final amountPesewas = (amountGhc * 100).toInt();

    final response = await http.post(
      Uri.parse('https://api.paystack.co/transaction/initialize'),
      headers: {
        'Authorization': 'Bearer $_secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'amount': amountPesewas,
        'currency': 'GHS',
        'reference': reference,
        'metadata': metadata ?? {},
        'channels': ['mobile_money'], // MoMo only
        'mobile_money': {
          'phone': '', // user will enter in Paystack UI
          'provider': 'mtn', // mtn | vodafone | tigo
        },
      }),
    );

    final data = jsonDecode(response.body);
    if (data['status'] != true) {
      throw Exception(data['message'] ?? 'Failed to initialize payment');
    }

    return data['data']; // contains authorization_url, reference
  }

  // ── Verify transaction ────────────────────────────────────────
  static Future<Map<String, dynamic>> verifyTransaction(
      String reference) async {
    final response = await http.get(
      Uri.parse(
          'https://api.paystack.co/transaction/verify/$reference'),
      headers: {'Authorization': 'Bearer $_secretKey'},
    );

    final data = jsonDecode(response.body);
    if (data['status'] != true) {
      throw Exception('Verification failed');
    }

    return data['data']; // contains status, id, reference
  }
}

// ── Paystack WebView ──────────────────────────────────────────
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

          // Paystack redirects to callback URL on success
          if (url.contains('callback') ||
              url.contains('success') ||
              url.contains(widget.reference)) {
            widget.onSuccess();
            return NavigationDecision.prevent;
          }

          // Paystack redirects to cancel URL on cancel
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