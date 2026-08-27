import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String? changelog;

  UpdateInfo({required this.version, required this.downloadUrl, this.changelog});
}

class UpdateService {
  static const _repo = 'KtifPMI/easyfinance';
  static const _apiUrl = 'https://api.github.com/repos/$_repo/releases/latest';

  static const _cacheKey = 'update_cache_v1';
  static const _ttl = Duration(minutes: 15);

  static Future<UpdateInfo?> check({bool force = false}) async {
    if (!force) {
      final cached = await _readCache();
      if (cached != null) return cached;
    }
    try {
      final result = await _fetch();
      await _writeCache(result);
      return result;
    } catch (_) {
      rethrow;
    }
  }

  static Future<UpdateInfo?> _fetch() async {
    final info = await PackageInfo.fromPlatform();
    final current = info.version.split('+').first;
    final currentBuild = int.tryParse(info.buildNumber) ?? 0;

    final response = await http.get(
      Uri.parse(_apiUrl),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('http ${response.statusCode}');

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagRaw = (data['tag_name'] as String?)?.replaceFirst('v', '') ?? '';
    final tagParts = tagRaw.split('+');
    final tag = tagParts.first;
    if (tag.isEmpty) return null;

    // Prefer comparing build numbers (monotonic, immune to versionName resets).
    // Fall back to semantic versionName compare when build info is unavailable.
    final latestBuild = tagParts.length > 1 ? (int.tryParse(tagParts.last) ?? 0) : 0;
    final bool newer;
    if (latestBuild > 0 && currentBuild > 0) {
      newer = latestBuild > currentBuild;
    } else {
      newer = _isNewer(tag, current);
    }
    if (!newer) return null;

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
  }

  static Future<UpdateInfo?> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ts = map['ts'] as int?;
      if (ts == null) return null;
      if (DateTime.now().millisecondsSinceEpoch - ts > _ttl.inMilliseconds) return null;
      if ((map['hasUpdate'] as bool? ?? false) != true) return null;
      return UpdateInfo(
        version: map['version'] as String,
        downloadUrl: map['url'] as String,
        changelog: map['changelog'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeCache(UpdateInfo? info) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        'ts': DateTime.now().millisecondsSinceEpoch,
        'hasUpdate': info != null,
      };
      if (info != null) {
        map['version'] = info.version;
        map['url'] = info.downloadUrl;
        map['changelog'] = info.changelog;
      }
      await prefs.setString(_cacheKey, jsonEncode(map));
    } catch (_) {}
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

      final sink = file.openWrite();
      await for (final chunk in response.stream) {
        sink.add(chunk);
      }
      await sink.close();
    } finally {
      client.close();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('update.apk_ready'))),
      );
    }

    await OpenFilex.open(file.path);
  }

  static Future<void> checkAndShow(BuildContext context, {bool showLatest = false, bool force = false}) async {
    UpdateInfo? update;
    bool errored = false;
    try {
      update = await check(force: force);
    } catch (_) {
      errored = true;
    }
    if (update == null) {
      if (errored && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('update.check_failed')), backgroundColor: Colors.orange, duration: const Duration(seconds: 2)),
        );
      } else if (showLatest && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('update.latest_version')), backgroundColor: AppColors.success, duration: const Duration(seconds: 2)),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final info = update;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('update.available')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('update.new_version', namedArgs: {'version': info.version}), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(context.tr('update.whats_new'), style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('update.later'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadWithProgress(context, info.downloadUrl);
            },
            child: Text(context.tr('update.update_now')),
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
          SnackBar(content: Text(context.tr('update.error')), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
