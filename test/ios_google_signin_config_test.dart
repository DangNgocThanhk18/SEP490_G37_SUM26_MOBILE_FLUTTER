import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Google Sign-In has client, server, and callback configuration', () {
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    final googlePlist = File(
      'ios/Runner/GoogleService-Info.plist',
    ).readAsStringSync();

    const iosClientId =
        '1096631184302-4ssppik6b5pc953inm12hcq02sv66sgc.apps.googleusercontent.com';
    const serverClientId =
        '1096631184302-q94c82aqbd76n04utd2a6gto7e2lod00.apps.googleusercontent.com';
    const callbackScheme =
        'com.googleusercontent.apps.1096631184302-4ssppik6b5pc953inm12hcq02sv66sgc';

    expect(infoPlist, contains('<key>GIDClientID</key>'));
    expect(infoPlist, contains(iosClientId));
    expect(infoPlist, contains('<key>GIDServerClientID</key>'));
    expect(infoPlist, contains(serverClientId));
    expect(infoPlist, contains('<key>CFBundleURLTypes</key>'));
    expect(infoPlist, contains(callbackScheme));

    expect(googlePlist, contains('<key>CLIENT_ID</key>'));
    expect(googlePlist, contains(iosClientId));
    expect(googlePlist, contains('<key>REVERSED_CLIENT_ID</key>'));
    expect(googlePlist, contains(callbackScheme));
  });
}
