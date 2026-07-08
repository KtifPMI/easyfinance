import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_client.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

class _MethodItem {
  final String label;
  final String apiMethod;

  const _MethodItem(this.label, this.apiMethod);
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String? _selectedMethod;
  DebugResponse? _response;
  bool _loading = false;
  bool _prettyPrint = true;
  final _paramsCtrl = TextEditingController();
  final _postBodyCtrl = TextEditingController();
  final _webLoginCtrl = TextEditingController();
  final _webPassCtrl = TextEditingController();
  bool _webLoggedIn = false;
  String _postMethod = 'operations.post';

  static const methods = [
    _MethodItem('accounts.get', 'accounts.get'),
    _MethodItem('accounts.post', 'accounts.post'),
    _MethodItem('accounts.set', 'accounts.set'),
    _MethodItem('operations.get', 'operations.get'),
    _MethodItem('operations.post', 'operations.post'),
    _MethodItem('operations.set', 'operations.set'),
    _MethodItem('categories.get', 'categories.get'),
    _MethodItem('currencies.get', 'currencies.get'),
    _MethodItem('budget.get', 'budget.get'),
    _MethodItem('budget.post', 'budget.post'),
    _MethodItem('budget.set', 'budget.set'),
    _MethodItem('users.get', 'users.get'),
    _MethodItem('users.post — with goals', 'users.post'),
    _MethodItem('goals.get', 'goals.get'),
    _MethodItem('goals.post', 'goals.post'),
    _MethodItem('goals.set', 'goals.set'),
    _MethodItem('operationPatterns.get', 'operationPatterns.get'),
  ];

  static const webMethods = [
    _MethodItem('📊 Tachometers', 'https://easyfinance.ru/my/info/get-tachometers'),
  ];

  static const _templates = {
    'operations.post': '''{
  "request": {
    "request_data": {
      "operations": [
        {
          "user_id": "USER_ID",
          "account_id": "ACCOUNT_ID",
          "category_id": "551145691",
          "amount": "-100.00",
          "date": "DATE",
          "time": "TIME",
          "type": "0",
          "accepted": true,
          "created_at": "DATE",
          "updated_at": "DATE",
          "deleted_at": null,
          "client_id": CLIENT_ID
        }
      ]
    }
  }
}''',
    'accounts.post': '''{
  "request": {
    "request_data": {
      "accounts": [
        {
          "name": "Test Account",
          "init_balance": "10000",
          "type_id": "2",
          "state": "1",
          "currency_id": "1",
          "icon": "accountimage1",
          "created_at": "DATE",
          "updated_at": "DATE"
        }
      ]
    }
  }
}''',
    'accounts.set': '''{
  "request": {
    "request_data": {
      "accounts": [
        {
          "id": "ACCOUNT_ID",
          "name": "Updated Name",
          "init_balance": "20000",
          "type_id": "2",
          "state": "1",
          "currency_id": "1",
          "icon": "accountimage1",
          "updated_at": "DATE"
        }
      ]
    }
  }
}''',
    'budget.post': '''{
  "request": {
    "request_data": {
      "budgets": [
        {
          "category_id": "551145669",
          "planned": "30000"
        }
      ]
    }
  }
}''',
    'budget.set': '''{
  "request": {
    "request_data": {
      "budgets": [
        {
          "category_id": "551145669",
          "planned": "35000"
        }
      ]
    }
  }
}''',
    'users.post — with goals': '''{
  "request": {
    "request_data": {
      "users": [
        {
          "id": "USER_ID",
          "goals": [
            {
              "title": "New Goal",
              "amount": 100000,
              "amount_done": 0,
              "end": "2026-12-31",
              "done": 0
            }
          ]
        }
      ]
    }
  }
}''',
    'goals.post': '''{
  "request": {
    "request_data": {
      "goals": [
        {
          "title": "Save for car",
          "amount": 500000,
          "amount_done": 0,
          "end": "2026-12-31"
        }
      ]
    }
  }
}''',
    'goals.set': '''{
  "request": {
    "request_data": {
      "goals": [
        {
          "id": "GOAL_ID",
          "amount_done": 50000
        }
      ]
    }
  }
}''',
  };

  String _templateKey(_MethodItem m) {
    if (_templates.containsKey(m.label)) return m.label;
    return m.apiMethod;
  }

  Map<String, String> _builtinParams(String method) {
    if (method == 'accounts.get') {
      return {'fields': 'id,name,type_id,currency_id,state,balance,init_balance,description,created_at,updated_at,user_id'};
    }
    return {};
  }

  Map<String, String> _customParams() {
    final raw = _paramsCtrl.text.trim();
    if (raw.isEmpty) return {};
    final map = <String, String>{};
    for (final pair in raw.split(',')) {
      final parts = pair.split('=');
      if (parts.length == 2) map[parts[0].trim()] = parts[1].trim();
    }
    return map;
  }

  Future<void> _callMethod(String method) async {
    setState(() {
      _selectedMethod = method;
      _loading = true;
      _response = null;
    });

    try {
      final api = context.read<FinanceStore>().apiClient;
      final params = {..._builtinParams(method), ..._customParams()};
      final resp = await api.getRaw(method, params: params.isEmpty ? null : params);
      if (mounted) setState(() => _response = resp);
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = DebugResponse(statusCode: 0, body: 'Exception: $e', url: '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _callWeb(String url) async {
    setState(() {
      _selectedMethod = url;
      _loading = true;
      _response = null;
    });

    try {
      final api = context.read<FinanceStore>().apiClient;
      final resp = await api.getDirect(url);
      final authInfo = api.webSessionId != null
          ? 'Cookie: PHPSESSID=${api.webSessionId}'
          : 'Query: access_token=<token>';

      if (mounted) {
        setState(() {
          _response = DebugResponse(
            statusCode: resp.statusCode,
            body: '--- REQUEST ---\nGET $url\n$authInfo\n\n--- RESPONSE HEADERS ---\n${resp.headers?.entries.map((e) => '${e.key}: ${e.value}').join('\n') ?? 'N/A'}\n\n--- RESPONSE BODY (${resp.body.length} chars) ---\n${resp.body.isEmpty ? '(empty)' : _formatBody(resp.body)}',
            url: url,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = DebugResponse(statusCode: 0, body: 'Exception: $e', url: '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _webLogin() async {
    final login = _webLoginCtrl.text.trim();
    final pass = _webPassCtrl.text.trim();
    if (login.isEmpty || pass.isEmpty) return;

    setState(() {
      _selectedMethod = 'Web Login';
      _loading = true;
      _response = null;
    });

    try {
      final api = context.read<FinanceStore>().apiClient;
      await api.loginWeb(login, pass);
      _webLoggedIn = true;
      if (mounted) {
        setState(() {
          _response = DebugResponse(
            statusCode: 200,
            body: 'Web login OK. PHPSESSID: ${api.webSessionId}',
            url: '',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = DebugResponse(statusCode: 0, body: 'Exception: $e', url: '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPost() async {
    setState(() {
      _selectedMethod = 'POST $_postMethod';
      _loading = true;
      _response = null;
    });

    try {
      final store = context.read<FinanceStore>();
      final api = store.apiClient;
      final now = DateTime.now();
      final tz = now.timeZoneOffset;
      final tzStr = '${tz.isNegative ? '-' : '+'}${tz.inHours.abs().toString().padLeft(2, '0')}:${(tz.inMinutes % 60).abs().toString().padLeft(2, '0')}';
      final isoStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}$tzStr';
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      var body = _postBodyCtrl.text;
      body = body.replaceAll('USER_ID', api.userId ?? '')
          .replaceAll('ACCOUNT_ID', store.accounts.isNotEmpty ? store.accounts.first.id : '1')
          .replaceAll('DATE', isoStr)
          .replaceAll('TIME', timeStr)
          .replaceAll('CLIENT_ID', '${now.millisecondsSinceEpoch % 100000}');

      final uri = api.buildPostUri(_postMethod);
      final resp = await http.post(uri, body: body, headers: {'Content-Type': 'application/json'}).timeout(const Duration(seconds: 15));

      if (mounted) {
        setState(() {
          _response = DebugResponse(
            statusCode: resp.statusCode,
            body: '--- REQUEST URL ---\n$uri\n\n--- REQUEST BODY ---\n${_formatBody(body)}\n\n--- RESPONSE (${resp.statusCode}) ---\n${_formatBody(resp.body)}',
            url: uri.toString(),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _response = DebugResponse(statusCode: 0, body: 'Exception: $e', url: '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatBody(String body) {
    if (!_prettyPrint) return body;
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }

  Color _statusColor(int code) {
    if (code == 200) return Colors.green;
    if (code >= 400 && code < 500) return Colors.orange;
    if (code >= 500) return Colors.red;
    return Colors.grey;
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied'), duration: Duration(seconds: 1)),
    );
  }

  @override
  void initState() {
    super.initState();
    _postBodyCtrl.text = _templates['operations.post']!;
  }

  @override
  void dispose() {
    _paramsCtrl.dispose();
    _postBodyCtrl.dispose();
    _webLoginCtrl.dispose();
    _webPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API Debug'),
        actions: [
          IconButton(
            icon: Icon(_prettyPrint ? Icons.code_off : Icons.code),
            onPressed: () => setState(() => _prettyPrint = !_prettyPrint),
            tooltip: 'Pretty print',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedMethod != null && !_selectedMethod!.startsWith('POST ') ? () => _callMethod(_selectedMethod!) : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: methods.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = methods[i];
                final isGet = m.apiMethod.endsWith('.get');
                final tplKey = _templateKey(m);
                return MaterialButton(
                  onPressed: _loading ? null : () {
                    if (isGet) {
                      _callMethod(m.apiMethod);
                    } else {
                      setState(() {
                        _postMethod = m.apiMethod;
                        _postBodyCtrl.text = _templates[tplKey] ?? _postBodyCtrl.text;
                      });
                    }
                  },
                  color: _postMethod == m.apiMethod && _postBodyCtrl.text == _templates[tplKey] || _selectedMethod == m.apiMethod
                      ? Theme.of(context).colorScheme.primaryContainer : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isGet ? Icons.download : Icons.upload,
                        size: 20,
                        color: (_postMethod == m.apiMethod && _postBodyCtrl.text == _templates[tplKey]) || _selectedMethod == m.apiMethod
                            ? Theme.of(context).colorScheme.primary : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          m.label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: !isGet && !m.apiMethod.endsWith('.get') && m.label != m.apiMethod ? FontWeight.w400 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (_loading && (_selectedMethod == m.apiMethod || _selectedMethod == 'POST $_postMethod'))
                        const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text('--- Web (direct) ---', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondaryFor(context))),
          ),
          if (!_webLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _webLoginCtrl, decoration: const InputDecoration(hintText: 'Web login', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)), style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _webPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password', isDense: true, border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6)), style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  SizedBox(height: 36, child: ElevatedButton(onPressed: _loading ? null : _webLogin, child: const Text('Login', style: TextStyle(fontSize: 12)))),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text('Web session: active', style: TextStyle(fontSize: 12, color: Colors.green))),
                  SizedBox(height: 28, child: TextButton(onPressed: () { context.read<FinanceStore>().apiClient.clearWebSession(); setState(() => _webLoggedIn = false); }, child: const Text('Logout', style: TextStyle(fontSize: 12)))),
                ],
              ),
            ),
          ...webMethods.map((m) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _callWeb(m.apiMethod),
                icon: const Icon(Icons.language, size: 18),
                label: Text(m.label, style: const TextStyle(fontSize: 13)),
              ),
            ),
          )),
          if (_selectedMethod == 'accounts.get')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _paramsCtrl,
              decoration: InputDecoration(
                hintText: context.tr('debug.extra_params'),
                isDense: true, border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 13),
              onSubmitted: _selectedMethod != null && !_selectedMethod!.startsWith('POST ') ? (_) => _callMethod(_selectedMethod!) : null,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _postBodyCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'POST body for $_postMethod',
                isDense: true, border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: SizedBox(
              width: double.infinity,
              child: MaterialButton(
                onPressed: _loading ? null : _sendPost,
                color: Colors.deepPurple,
                textColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Text(_loading ? 'Sending...' : '▶ POST $_postMethod', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (_response != null && _response!.url.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFF2D2D2D),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _response!.url,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                    onPressed: () => _copy(_response!.url),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (_response != null)
            Expanded(
              child: Container(
                color: const Color(0xFF1E1E1E),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: const Color(0xFF333333),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _statusColor(_response!.statusCode).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HTTP ${_response!.statusCode}',
                              style: TextStyle(fontSize: 12, color: _statusColor(_response!.statusCode)),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.copy, color: Colors.white54, size: 16),
                            onPressed: () => _copy(_response!.body),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy response body',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _response!.body,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Color(0xFFD4D4D4),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
