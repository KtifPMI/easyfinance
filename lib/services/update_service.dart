import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? changelog;

  UpdateInfo({required this.version, required this.downloadUrl, this.changelog});
}

class UpdateService {
  static const _repo = 'KtifPMI/easyfinance';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  static Future<UpdateInfo?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version.split('+').first;

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.replaceFirst('v', '').split('+').first ?? '';
      if (tag.isEmpty) return null;

      if (!_isNewer(tag, current)) return null;

      final assets = data['assets'] as List? ?? [];
      Map<String, dynamic>? apkAsset;
      for (final a in assets) {
        if ((a['name'] as String?)?.endsWith('.apk') == true) {
          apkAsset = a as Map<String, dynamic>;
          break;
        }
      }
      if (apkAsset == null) return null;

      return UpdateInfo(
        version: tag,
        downloadUrl: apkAsset['browser_download_url'] as String,
        changelog: data['body'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s.split('+').first)).whereType<int>().toList();
    final c = current.split('.').map((s) => int.tryParse(s.split('+').first)).whereType<int>().toList();
    for (int i = 0; i < l.length && i < c.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  static Future<void> downloadAndInstall(String url, BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/easyfinance.apk');

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(minutes: 5));
      final contentLength = response.contentLength ?? 0;

      final sink = file.openWrite();
      int downloaded = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && context.mounted) {
          final progress = (downloaded / contentLength * 100).round();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Загрузка... $progress%'),
              duration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
      await sink.close();
    } finally {
      client.close();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('APK загружен, открываю установщик...')),
      );
    }

    await OpenFilex.open(file.path);
  }

  static Future<void> checkAndShow(BuildContext context) async {
    final update = await check();
    if (update == null || !context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Доступно обновление'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Новая версия: ${update.version}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (update.changelog != null) ...[
              const SizedBox(height: 8),
              Text(update.changelog!, style: const TextStyle(fontSize: 13), maxLines: 5, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Позже')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadWithProgress(context, update.downloadUrl);
            },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  static void _downloadWithProgress(BuildContext context, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await downloadAndInstall(url, context);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка загрузки обновления'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
