import 'dart:convert';
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
      await _showPdaDialog(store, user);
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
      await _showPdaDialog(store, user);
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

  Future<void> _showPdaDialog(FinanceStore store, User? user) async {
    final userLogin = user?.email.isNotEmpty == true ? user!.email
        : user?.login.isNotEmpty == true ? user!.login : null;
    if (userLogin == null || userLogin.isEmpty) return;

    final ctrl = TextEditingController();
    final useLogin = user?.login.isNotEmpty == true && user?.email.isNotEmpty == true;
    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Синхронизация целей'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Введите пароль от EasyFinance, чтобы синхронизировать цели и бюджеты с сервером.'),
            const SizedBox(height: 16),
            Text('Логин: $userLogin', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (useLogin)
              Text('Email: ${user!.email}', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: InputDecoration(labelText: 'Пароль', border: const OutlineInputBorder()),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Пропустить'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Войти'),
          ),
        ],
      ),
    );

    if (submitted != true || ctrl.text.isEmpty) return;

    final password = ctrl.text;
    final attempts = [userLogin];
    if (useLogin) attempts.add(user!.login);

    for (final attempt in attempts) {
      try {
        await store.authService.pdaClient.authenticate(attempt, password);
        final pdaToken = store.authService.pdaClient.authToken;
        if (pdaToken != null) {
          await store.authService.savePdaToken(pdaToken);
          await store.fetchAllData();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Синхронизация включена'), backgroundColor: Colors.green),
          );
        }
        return;
      } catch (_) {
        // try next login variant
      }
    }

    // Both attempts failed
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: неверный логин или пароль. Цели будут сохранены локально.'),
          backgroundColor: Colors.red,
        ),
      );
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
