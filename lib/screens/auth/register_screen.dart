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

  void _injectViewportFix() {
    _controller.runJavaScript('''
      (function() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.name = 'viewport';
          document.head.appendChild(meta);
        }
        meta.content = 'width=device-width, initial-scale=0.85, maximum-scale=1.0, user-scalable=no';
        var iframes = document.querySelectorAll('iframe');
        for (var i = 0; i < iframes.length; i++) { iframes[i].style.display = 'none'; }
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
        },
        onPageFinished: (_) {
          setState(() => _loading = false);
          _injectViewportFix();
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
