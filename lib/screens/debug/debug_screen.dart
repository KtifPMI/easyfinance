import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/api_client.dart';
import '../../store/finance_store.dart';
import '../../theme/theme.dart';

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

  static const methods = [
    'accounts.get',
    'operations.get',
    'categories.get',
    'tags.get',
    'budget.get',
    'users.get',
  ];

  static const _defaultPostBody = '''{
  "request": {
    "request_data": {
      "operations": [
        {
          "user_id": "USER_ID",
          "account_id": "ACCOUNT_ID",
          "category_id": "CATEGORY_ID",
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
}''';

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

  Future<void> _sendPost() async {
    setState(() {
      _selectedMethod = 'POST';
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
          .replaceAll('CATEGORY_ID', store.categories.isNotEmpty ? store.categories.first.id : '1')
          .replaceAll('DATE', isoStr)
          .replaceAll('TIME', timeStr)
          .replaceAll('CLIENT_ID', '${now.millisecondsSinceEpoch % 100000}');

      final uri = api.buildPostUri('operations.post');
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
    _postBodyCtrl.text = _defaultPostBody;
  }

  @override
  void dispose() {
    _paramsCtrl.dispose();
    _postBodyCtrl.dispose();
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
            onPressed: _selectedMethod != null ? () => _callMethod(_selectedMethod!) : null,
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
                return MaterialButton(
                  onPressed: _loading ? null : () => _callMethod(m),
                  color: _selectedMethod == m ? Theme.of(context).colorScheme.primaryContainer : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.api,
                        size: 20,
                        color: _selectedMethod == m ? Theme.of(context).colorScheme.primary : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(m, style: const TextStyle(fontSize: 15))),
                      if (_loading && _selectedMethod == m) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                      if (!_loading && _selectedMethod == m && _response != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _statusColor(_response!.statusCode).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_response!.statusCode}',
                            style: TextStyle(fontSize: 12, color: _statusColor(_response!.statusCode), fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_selectedMethod == 'accounts.get')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(context.tr('debug.fields_added'), style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
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
              onSubmitted: _selectedMethod != null ? (_) => _callMethod(_selectedMethod!) : null,
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
                child: Text(_loading ? 'Sending...' : '▶ POST Test Operation', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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