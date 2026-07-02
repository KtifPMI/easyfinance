import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          _initialLoadDone = true;
          // Если после начальной загрузки оказались на другом URL — регистрация прошла
          if (url.contains('easyfinance.ru') && !url.contains('easyfinance.ru/registration')) {
            if (mounted) Navigator.pop(context);
          }
        },
        onNavigationRequest: (req) {
          final url = req.url;
          if (_initialLoadDone && url.contains('easyfinance.ru') && !url.contains('easyfinance.ru/registration')) {
            if (mounted) Navigator.pop(context);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse('https://easyfinance.ru/registration/'));
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
