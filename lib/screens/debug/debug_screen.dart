import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';
import '../../store/finance_store.dart';

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

  static const methods = [
    'accounts.get',
    'operations.get',
    'categories.get',
    'tags.get',
    'budget.get',
    'users.get',
  ];

  Future<void> _callMethod(String method) async {
    setState(() {
      _selectedMethod = method;
      _loading = true;
      _response = null;
    });

    try {
      final api = context.read<FinanceStore>().apiClient;
      final resp = await api.getRaw(method);
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
                            color: _statusColor(_response!.statusCode).withOpacity(0.15),
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
                              color: _statusColor(_response!.statusCode).withOpacity(0.2),
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
                          _formatBody(_response!.body),
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