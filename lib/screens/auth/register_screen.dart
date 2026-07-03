import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  Timer? _fixTimer;

  void _injectViewportFix() {
    _controller.runJavaScript('''
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        document.documentElement.style.width = '100%';
        document.documentElement.style.maxWidth = '100%';
        document.documentElement.style.overflowX = 'hidden';
        document.body.style.width = '100%';
        document.body.style.maxWidth = '100%';
        document.body.style.overflowX = 'hidden';
        document.body.style.margin = '0';
        document.body.style.padding = '0';
        var els = document.querySelectorAll('iframe, [class*="support"], [class*="chat"], [class*="widget"], [id*="support"]');
        for (var i = 0; i < els.length; i++) { els[i].style.display = 'none'; }
      })();
    ''');
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          setState(() => _loading = true);
          _fixTimer?.cancel();
        },
        onPageFinished: (_) {
          setState(() => _loading = false);
          _injectViewportFix();
          _fixTimer = Timer(const Duration(milliseconds: 500), _injectViewportFix);
        },
        onNavigationRequest: (req) {
          final url = req.url;
          if (url.contains('easyfinance.ru/my/') || url.contains('/v2/result')) {
            if (mounted) Navigator.pop(context);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://easyfinance.ru/registration/'));
  }

  @override
  void dispose() {
    _fixTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация'), centerTitle: true),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
