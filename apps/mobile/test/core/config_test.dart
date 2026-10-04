// F-13-01 (V2 TASK-13 AC-10): API base URL policy per build mode, and the
// fatal config screen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saarthee/core/config/api_url_policy.dart';
import 'package:saarthee/core/config/config_error_app.dart';

void main() {
  group('apiBaseUrlIsAllowed', () {
    const https = [
      'https://api.saarthee.example/api/v1',
      'https://api-staging.saarthee.example/api/v1',
      'https://10.0.2.2/api/v1',
    ];
    const devHttp = [
      'http://10.0.2.2:4000/api/v1',
      'http://localhost:4000/api/v1',
      'http://LOCALHOST:4000/api/v1',
    ];
    const neverAllowed = [
      '',
      '   ',
      'api.saarthee.example/api/v1',
      '/api/v1',
      'ftp://10.0.2.2/api',
      'ws://10.0.2.2:4000',
      'http://192.168.1.20:4000/api/v1',
      'http://api.saarthee.example/api/v1',
      'https://user:pass@api.saarthee.example/api/v1',
      'https:///api/v1',
    ];

    test('https is allowed in every build mode', () {
      for (final mode in BuildMode.values) {
        for (final url in https) {
          expect(apiBaseUrlIsAllowed(url, mode), isTrue, reason: '$mode $url');
        }
      }
    });

    test('http to 10.0.2.2/localhost is allowed in debug only', () {
      for (final url in devHttp) {
        expect(apiBaseUrlIsAllowed(url, BuildMode.debug), isTrue, reason: url);
        expect(
          apiBaseUrlIsAllowed(url, BuildMode.profile),
          isFalse,
          reason: url,
        );
        expect(
          apiBaseUrlIsAllowed(url, BuildMode.release),
          isFalse,
          reason: url,
        );
      }
    });

    test(
      'other hosts, schemes and malformed URLs are refused in every mode',
      () {
        for (final mode in BuildMode.values) {
          for (final url in neverAllowed) {
            expect(
              apiBaseUrlIsAllowed(url, mode),
              isFalse,
              reason: '$mode "$url"',
            );
          }
        }
      },
    );

    test('an extra debug host (LAN phone) is allowed in debug only', () {
      const url = 'http://192.168.1.20:4000/api/v1';
      const extra = {'192.168.1.20'};
      expect(
        apiBaseUrlIsAllowed(url, BuildMode.debug, extraDebugHosts: extra),
        isTrue,
      );
      expect(
        apiBaseUrlIsAllowed(url, BuildMode.profile, extraDebugHosts: extra),
        isFalse,
      );
      expect(
        apiBaseUrlIsAllowed(url, BuildMode.release, extraDebugHosts: extra),
        isFalse,
      );
    });

    test('tests run in debug mode', () {
      expect(currentBuildMode, BuildMode.debug);
    });
  });

  testWidgets('ConfigErrorApp shows the misconfigured-build message', (
    tester,
  ) async {
    await tester.pumpWidget(const ConfigErrorApp());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('configError.body')), findsOneWidget);
    expect(
      find.text(
        'This build is misconfigured. Please install the latest version from Play.',
      ),
      findsOneWidget,
    );
  });
}
