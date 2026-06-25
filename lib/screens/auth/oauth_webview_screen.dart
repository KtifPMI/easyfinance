import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/api_client.dart';
import '../../store/finance_store.dart';

class OAuthWebViewScreen extends StatefulWidget {
  const OAuthWebViewScreen({super.key});
  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final store = context.read<FinanceStore>();
    final uri = store.apiClient.buildOAuthCodeUrl();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: _interceptNav,
      ))
      ..loadRequest(uri);
  }

  Future<NavigationDecision> _interceptNav(NavigationRequest req) async {
    final uri = Uri.parse(req.url);

    if (uri.path.endsWith('/v2/result')) {
      if (uri.queryParameters.containsKey('access_token')) {
        _handleToken(uri.queryParameters['access_token']!);
        return NavigationDecision.prevent;
      }

      if (uri.hasFragment) {
        final frag = Uri.splitQueryString(uri.fragment);
        if (frag.containsKey('access_token')) {
          _handleToken(frag['access_token']!);
          return NavigationDecision.prevent;
        }
      }

      if (uri.queryParameters.containsKey('code')) {
        _handleCode(uri.queryParameters['code']!);
        return NavigationDecision.prevent;
      }

      if (uri.queryParameters.containsKey('access_denied')) {
        if (mounted) Navigator.pop(context, false);
        return NavigationDecision.prevent;
      }
    }

    return NavigationDecision.navigate;
  }

  Future<void> _handleToken(String token) async {
    try {
      final store = context.read<FinanceStore>();
      store.apiClient.setAuth(accessToken: token);
      await store.authService.saveCredentials(
        appId: store.apiClient.appId,
        secretKey: store.apiClient.secretKey,
        accessToken: token,
      );
      await store.fetchAllData();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, false);
      }
    }
  }

  Future<void> _handleCode(String code) async {
    try {
      final store = context.read<FinanceStore>();

      // First try using code directly as access_token
      store.apiClient.setAuth(accessToken: code);
      try {
        await store.apiClient.get('accounts.get');
        final token = code;
        await store.authService.saveCredentials(
          appId: store.apiClient.appId,
          secretKey: store.apiClient.secretKey,
          accessToken: token,
        );
        await store.fetchAllData();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
        }
        return;
      } on ApiException {
        // code is not a token, try exchange
      }

      // Exchange code for token
      final token = await store.apiClient.exchangeCodeForToken(code);
      if (token.isEmpty) throw ApiException('Empty token', 'OAUTH_FAIL');

      await store.authService.saveCredentials(
        appId: store.apiClient.appId,
        secretKey: store.apiClient.secretKey,
        accessToken: token,
      );

      await store.fetchAllData();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка авторизации: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Авторизация EasyFinance'), centerTitle: true),
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
