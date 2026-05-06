import 'package:flutter/foundation.dart';
import 'package:upgrader/upgrader.dart';

Upgrader createAppUpgrader() {
  const minAppVersion =
      String.fromEnvironment('UPGRADER_MIN_APP_VERSION', defaultValue: '');
  const appcastUrl =
      String.fromEnvironment('UPGRADER_APPCAST_URL', defaultValue: '');

  final hasForcedMinimumVersion = minAppVersion.trim().isNotEmpty;
  final storeController = appcastUrl.trim().isEmpty
      ? null
      : UpgraderStoreController(
          onAndroid: () => UpgraderAppcastStore(appcastURL: appcastUrl),
          oniOS: () => UpgraderAppcastStore(appcastURL: appcastUrl),
        );

  return Upgrader(
    debugLogging: !kReleaseMode,
    debugDisplayAlways: !kReleaseMode && !hasForcedMinimumVersion,
    debugDisplayOnce: false,
    durationUntilAlertAgain: const Duration(hours: 1),
    minAppVersion:
        hasForcedMinimumVersion ? minAppVersion.trim() : null,
    storeController: storeController,
    willDisplayUpgrade: ({
      required bool display,
      String? installedVersion,
      UpgraderVersionInfo? versionInfo,
    }) {
      debugPrint(
        'upgrader: willDisplayUpgrade display=$display '
        'installedVersion=$installedVersion '
        'appStoreVersion=${versionInfo?.appStoreVersion}',
      );
    },
  );
}

bool hasForcedUpgradeVersion() {
  const minAppVersion =
      String.fromEnvironment('UPGRADER_MIN_APP_VERSION', defaultValue: '');
  return minAppVersion.trim().isNotEmpty;
}
