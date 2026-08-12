import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS push capability supports development and production builds', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(infoPlist, contains('<string>remote-notification</string>'));
    expect(entitlements, contains('<key>aps-environment</key>'));
    expect(entitlements, contains(r'$(APS_ENVIRONMENT)'));
    expect(project, contains('APS_ENVIRONMENT = development;'));
    expect(project, contains('APS_ENVIRONMENT = production;'));
    expect(project, contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'));
  });

  test('iOS native runner registers the application badge channel', () {
    final appDelegate = File(
      'ios/Runner/AppDelegate.swift',
    ).readAsStringSync();

    expect(appDelegate, contains('ApplicationBadgePlugin.register'));
    expect(appDelegate, contains('comiverse/application_badge'));
    expect(appDelegate, contains('setBadgeCount(normalizedCount)'));
  });
}
