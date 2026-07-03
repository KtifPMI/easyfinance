import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';
import '../../store/finance_store.dart';
import '../../store/planned_payment_store.dart';

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
        onPageFinished: _onPageFinished,
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
        _pendingCode = uri.queryParameters['code']!;
        return NavigationDecision.navigate;
      }

      if (uri.queryParameters.containsKey('access_denied')) {
        if (mounted) Navigator.pop(context, false);
        return NavigationDecision.prevent;
      }
    }

    return NavigationDecision.navigate;
  }

  String? _pendingCode;

  Future<void> _onPageFinished(String url) async {
    setState(() => _loading = false);

    final uri = Uri.parse(url);
    if (uri.path.endsWith('/v2/result')) {
      if (uri.queryParameters.containsKey('access_token')) {
        _handleToken(uri.queryParameters['access_token']!);
        return;
      }
      if (uri.hasFragment) {
        final frag = Uri.splitQueryString(uri.fragment);
        if (frag.containsKey('access_token')) {
          _handleToken(frag['access_token']!);
          return;
        }
      }
      if (_pendingCode != null) {
        final code = _pendingCode!;
        _pendingCode = null;
        _handleCode(code);
      }
    }
  }

  Future<User?> _fetchUser() async {
    try {
      final store = context.read<FinanceStore>();
      return await store.authService.apiService.getUser();
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleToken(String token) async {
    try {
      final store = context.read<FinanceStore>();
      final plannedStore = context.read<PlannedPaymentStore>();
      store.apiClient.setAuth(accessToken: token);

      final user = await _fetchUser();
      if (user != null && user.id.isNotEmpty) {
        store.apiClient.setAuth(accessToken: token, userId: user.id);
        store.saveUser(user);
      }

      await plannedStore.clear();
      await store.authService.saveCredentials(
        appId: store.apiClient.appId,
        secretKey: store.apiClient.secretKey,
        accessToken: token,
        userId: user?.id,
      );
      await store.fetchAllData();
      NotificationService().rescheduleAll(); // fire-and-forget
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
      }
    } on ApiException catch (_) {
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  Future<void> _handleCode(String code) async {
    try {
      final store = context.read<FinanceStore>();
      final plannedStore = context.read<PlannedPaymentStore>();
      final token = await store.apiClient.exchangeCodeForToken(code);
      if (token.isEmpty) throw ApiException('Empty token', 'OAUTH_FAIL');

      store.apiClient.setAuth(accessToken: token);

      final user = await _fetchUser();
      if (user != null && user.id.isNotEmpty) {
        store.apiClient.setAuth(accessToken: token, userId: user.id);
        store.saveUser(user);
      }

      await plannedStore.clear();
      await store.authService.saveCredentials(
        appId: store.apiClient.appId,
        secretKey: store.apiClient.secretKey,
        accessToken: token,
        userId: user?.id,
      );

      await store.fetchAllData();
      NotificationService().rescheduleAll(); // fire-and-forget
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/main', (r) => false);
      }
    } on ApiException catch (_) {
      if (mounted) Navigator.pop(context, false);
    } catch (_) {
      if (mounted) Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auth.title_webview')), centerTitle: true),
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
