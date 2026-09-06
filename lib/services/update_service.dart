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
  static const _pendingKey = 'update_pending_download';
  static const _pendingVersionKey = 'update_pending_version';
  static const _ttl = Duration(minutes: 15);

  static bool _downloading = false;

  static Future<UpdateInfo?> check({bool force = false}) async {
    if (!force) {
      final cached = await _readCache();
      if (cached != null) {
        final info = await PackageInfo.fromPlatform();
        final currentBuild = int.tryParse(info.buildNumber) ?? 0;
        final tagParts = cached.version.split('+');
        final latestBuild = tagParts.length > 1 ? (int.tryParse(tagParts.last) ?? 0) : 0;
        bool newer;
        if (latestBuild > 0 && currentBuild > 0) {
          newer = latestBuild > currentBuild;
        } else {
          newer = _isNewer(tagParts.first, info.version.split('+').first);
        }
        if (newer) return cached;
        await _writeCache(null);
        await _cleanupApk();
        return null;
      }
    }
    try {
      final result = await _fetch();
      await _writeCache(result);
      if (result == null) await _cleanupApk();
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

  static Future<void> _cleanupApk() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/easyfinance.apk');
      if (await file.exists()) await file.delete();
      await _savePendingUrl(null);
    } catch (_) {}
  }

  static Future<void> _savePendingUrl(String? url, {String? version}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (url == null) {
        await prefs.remove(_pendingKey);
        await prefs.remove(_pendingVersionKey);
      } else {
        await prefs.setString(_pendingKey, url);
        if (version != null) await prefs.setString(_pendingVersionKey, version);
      }
    } catch (_) {}
  }

  static Future<String?> _getPendingUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_pendingKey);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _isApkNewerThanCurrent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingVersion = prefs.getString(_pendingVersionKey);
      if (pendingVersion == null) return false;
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final tagParts = pendingVersion.split('+');
      final pendingBuild = tagParts.length > 1 ? (int.tryParse(tagParts.last) ?? 0) : 0;
      if (pendingBuild > 0 && currentBuild > 0) return pendingBuild > currentBuild;
      return _isNewer(tagParts.first, info.version.split('+').first);
    } catch (_) {
      return false;
    }
  }

  static Future<void> resumeIfNeeded(BuildContext context) async {
    if (_downloading) return;
    final url = await _getPendingUrl();
    if (url != null) {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getString(_pendingVersionKey);
      _downloadWithProgress(context, url, version: version);
      return;
    }
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/easyfinance.apk');
    if (await file.exists()) {
      if (!await _isApkNewerThanCurrent()) {
        await _cleanupApk();
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('update.apk_ready')),
            action: SnackBarAction(label: context.tr('update.install'), onPressed: () => OpenFilex.open(file.path)),
          ),
        );
      }
    }
  }

  static Future<void> downloadAndInstall(String url, BuildContext context, {void Function(double)? onProgress}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/easyfinance.apk');

    final client = http.Client();
    try {
      int existingBytes = 0;
      if (await file.exists()) {
        existingBytes = await file.length();
      }

      final request = http.Request('GET', Uri.parse(url));
      if (existingBytes > 0) {
        request.headers['Range'] = 'bytes=$existingBytes-';
      }
      final response = await client.send(request).timeout(const Duration(minutes: 5));

      final isPartial = response.statusCode == 206;
      final total = isPartial
          ? existingBytes + (response.contentLength ?? 0)
          : (response.contentLength ?? 0).toDouble();

      if (!isPartial && existingBytes > 0) {
        await file.delete();
      }

      final sink = file.openWrite(mode: isPartial ? FileMode.append : FileMode.write);
      int received = existingBytes;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) onProgress(received / total);
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
              _downloadWithProgress(context, info.downloadUrl, version: info.version);
            },
            child: Text(context.tr('update.update_now')),
          ),
        ],
      ),
    );
  }

  static void _downloadWithProgress(BuildContext context, String url, {String? version}) async {
    if (_downloading) return;
    _downloading = true;
    await _savePendingUrl(url, version: version);
    double progress = 0;
    StateSetter? setDialogState;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          setDialogState = setState;
          return AlertDialog(
            title: Text(context.tr('update.downloading')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 8,
                  backgroundColor: AppColors.borderFor(context),
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).round()}%', style: TextStyle(fontSize: 14, color: AppColors.textFor(context))),
              ],
            ),
          );
        },
      ),
    );
    try {
      await downloadAndInstall(url, context, onProgress: (p) {
        progress = p;
        setDialogState?.call(() {});
      });
      await _savePendingUrl(null);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('update.error')), backgroundColor: Colors.red),
        );
      }
    } finally {
      _downloading = false;
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
