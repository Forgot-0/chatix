import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateCheckResult {
  upToDate,

  updateAvailable,

  criticalUpdateRequired,

  checkFailed,
}

class UpdateInfo {
  final String latestVersion;

  final String minimumRequiredVersion;

  final bool isCritical;

  final String? releaseNotes;

  final String? updateUrl;

  const UpdateInfo({
    required this.latestVersion,
    required this.minimumRequiredVersion,
    required this.isCritical,
    this.releaseNotes,
    this.updateUrl,
  });

  UpdateInfo copyWith({
    String? latestVersion,
    String? minimumRequiredVersion,
    bool? isCritical,
    String? releaseNotes,
    String? updateUrl,
  }) {
    return UpdateInfo(
      latestVersion: latestVersion ?? this.latestVersion,
      minimumRequiredVersion:
          minimumRequiredVersion ?? this.minimumRequiredVersion,
      isCritical: isCritical ?? this.isCritical,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      updateUrl: updateUrl ?? this.updateUrl,
    );
  }
}

abstract class UpdateService {
  Future<UpdateCheckResult> checkForUpdates();

  Future<UpdateInfo?> getUpdateInfo();

  Future<bool> promptUpdate({bool force = false});

  Future<bool> openUpdateUrl();

  Future<void> init();

  bool isUpdateNeeded(String currentVersion, String latestVersion);

  bool isCriticalUpdate(String currentVersion, String minimumRequired);
}

class BasicUpdateService implements UpdateService {
  final String _androidPackageName;
  final String _iOSAppId;

  PackageInfo? _packageInfo;
  UpdateInfo? _updateInfo;

  BasicUpdateService({
    required String androidPackageName,
    required String iOSAppId,
  }) : _androidPackageName = androidPackageName,
       _iOSAppId = iOSAppId;

  @override
  Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
    debugPrint(
      '⬆️ Update service initialized: v${_packageInfo?.version}+${_packageInfo?.buildNumber}',
    );
  }

  @override
  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      if (_packageInfo == null) {
        await init();
      }

      await Future.delayed(const Duration(seconds: 1));

      _updateInfo = await _fetchUpdateInfo();

      if (_updateInfo == null) {
        return UpdateCheckResult.checkFailed;
      }

      if (isCriticalUpdate(
        _packageInfo!.version,
        _updateInfo!.minimumRequiredVersion,
      )) {
        return UpdateCheckResult.criticalUpdateRequired;
      }

      if (isUpdateNeeded(_packageInfo!.version, _updateInfo!.latestVersion)) {
        return UpdateCheckResult.updateAvailable;
      }

      return UpdateCheckResult.upToDate;
    } catch (e) {
      debugPrint('⬆️ Update check failed: $e');
      return UpdateCheckResult.checkFailed;
    }
  }

  @override
  Future<UpdateInfo?> getUpdateInfo() async {
    if (_updateInfo == null) {
      await checkForUpdates();
    }
    return _updateInfo;
  }

  @override
  Future<bool> promptUpdate({bool force = false}) async {
    final updateInfo = await getUpdateInfo();
    if (updateInfo == null) {
      return false;
    }

    debugPrint(
      '⬆️ Prompting for update to version ${updateInfo.latestVersion} '
      '(current: ${_packageInfo?.version})',
    );

    return true;
  }

  @override
  Future<bool> openUpdateUrl() async {
    try {
      final updateInfo = await getUpdateInfo();
      if (updateInfo?.updateUrl != null) {
        return await _launchUrl(updateInfo!.updateUrl!);
      }

      String url;
      if (Platform.isAndroid) {
        url =
            'https://play.google.com/store/apps/details?id=$_androidPackageName';
      } else if (Platform.isIOS) {
        url = 'https://apps.apple.com/app/id$_iOSAppId';
      } else {
        return false;
      }

      return await _launchUrl(url);
    } catch (e) {
      debugPrint('⬆️ Failed to open update URL: $e');
      return false;
    }
  }

  @override
  bool isUpdateNeeded(String currentVersion, String latestVersion) {
    try {
      final current = _parseVersion(currentVersion);
      final latest = _parseVersion(latestVersion);

      if (latest[0] > current[0]) return true;
      if (latest[0] < current[0]) return false;

      if (latest[1] > current[1]) return true;
      if (latest[1] < current[1]) return false;

      return latest[2] > current[2];
    } catch (e) {
      debugPrint('⬆️ Version comparison error: $e');
      return false;
    }
  }

  @override
  bool isCriticalUpdate(String currentVersion, String minimumRequired) {
    try {
      final current = _parseVersion(currentVersion);
      final minimum = _parseVersion(minimumRequired);

      if (current[0] < minimum[0]) return true;
      if (current[0] > minimum[0]) return false;

      if (current[1] < minimum[1]) return true;
      if (current[1] > minimum[1]) return false;

      return current[2] < minimum[2];
    } catch (e) {
      debugPrint('⬆️ Critical update check error: $e');
      return false;
    }
  }

  List<int> _parseVersion(String version) {
    final parts = version.split('.');

    if (parts.length < 3) {
      parts.addAll(List.filled(3 - parts.length, '0'));
    }

    return parts.take(3).map((part) {
      final match = RegExp(r'^\d+').firstMatch(part);
      final digitPart = match != null ? match.group(0) : '0';
      return int.tryParse(digitPart ?? '0') ?? 0;
    }).toList();
  }

  Future<bool> _launchUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      return await launchUrl(Uri.parse(url));
    }
    return false;
  }

  Future<UpdateInfo> _fetchUpdateInfo() async {
    final currentVersion = _packageInfo?.version ?? '1.0.0';

    final current = _parseVersion(currentVersion);
    final nextVersion = '${current[0]}.${current[1]}.${current[2] + 1}';
    final minRequired = '${current[0]}.${current[1]}.0';

    return UpdateInfo(
      latestVersion: nextVersion,
      minimumRequiredVersion: minRequired,
      isCritical: false,
      releaseNotes: 'Bug fixes and performance improvements.',
      updateUrl: Platform.isAndroid
          ? 'https://play.google.com/store/apps/details?id=$_androidPackageName'
          : 'https://apps.apple.com/app/id$_iOSAppId',
    );
  }
}
