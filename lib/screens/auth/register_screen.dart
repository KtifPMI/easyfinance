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

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) {
          setState(() => _loading = false);
          _controller.runJavaScript('''
            (function() {
              var meta = document.querySelector('meta[name="viewport"]');
              if (meta) meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0';
              document.body.style.maxWidth = '100vw';
              document.body.style.overflowX = 'hidden';
            })();
          ''');
        },
        onNavigationRequest: (req) {
          final url = req.url;
          // После успешной регистрации EasyFinance редиректит в личный кабинет
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
