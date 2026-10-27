import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';
import 'package:stream_chat_flutter_ai/stream_chat_flutter_ai.dart';

const _linear = {
  'type': 'oauth',
  'provider': 'linear',
  'provider_name': 'Linear',
  'title': 'Connect Linear',
  'message': 'You sign in at Linear, and the agent never sees your password.',
  'url': 'https://agent.example/v1/agents/connectors/oauth/launch/abc',
  'handoff_token': 'tok_123',
  'expires_at': '2026-10-21T21:42:19.834Z',
};

AIToolAuthorization? _read(Map<String, Object?> json) => AIToolAuthorization.fromJson(json);

AIToolAuthorization _withToken(String? token, {String url = 'https://agent.example/launch/abc'}) =>
    AIToolAuthorization(title: 'Connect Linear', url: Uri.parse(url), handoffToken: token);

void main() {
  final reports = <String>[];
  setUp(() {
    reports.clear();
    debugPartIssueReporter = reports.add;
  });
  tearDown(() => debugPartIssueReporter = null);

  group('AIToolAuthorization.fromJson', () {
    test('reads every field', () {
      final authorization = _read(_linear)!;

      expect(authorization.kind, AIToolAuthorizationKind.oauth);
      expect(authorization.provider, 'linear');
      expect(authorization.providerName, 'Linear');
      expect(authorization.title, 'Connect Linear');
      expect(authorization.message, startsWith('You sign in'));
      expect(authorization.url, Uri.parse('https://agent.example/v1/agents/connectors/oauth/launch/abc'));
      expect(authorization.handoffToken, 'tok_123');
      expect(authorization.expiresAt, DateTime.utc(2026, 10, 21, 21, 42, 19, 834));
      expect(authorization.status, isNull);
      expect(reports, isEmpty);
    });

    test('defaults the kind to oauth and the provider to empty', () {
      final authorization = _read({'title': 'Connect', 'url': 'https://a.example'})!;

      expect(authorization.kind, AIToolAuthorizationKind.oauth);
      expect(authorization.provider, '');
      expect(authorization.providerName, isNull);
    });

    for (final (description, json) in [
      ('no title', {'url': 'https://a.example'}),
      ('an empty title', {'title': '', 'url': 'https://a.example'}),
      ('a blank title', {'title': '  ', 'url': 'https://a.example'}),
      ('no url', {'title': 'Connect'}),
      ('a url that is not a web page', {'title': 'Connect', 'url': 'ftp://a.example/x'}),
      ('a mailto url', {'title': 'Connect', 'url': 'mailto:me@a.example'}),
      ('a url without a host', {'title': 'Connect', 'url': 'https:///path'}),
      ('a relative url', {'title': 'Connect', 'url': '/v1/launch'}),
      ('a javascript url', {'title': 'Connect', 'url': 'javascript:alert(1)'}),
      ('a cleartext page off the device', {'title': 'Connect', 'url': 'http://agent.example/launch'}),
      ('a cleartext page on the device', {'title': 'Connect', 'url': 'http://localhost:8080/launch'}),
      ('a url that does not parse', {'title': 'Connect', 'url': 'http://[::1'}),
    ]) {
      test('asks nothing with $description, and says so', () {
        expect(_read(json), isNull);
        expect(reports, contains(contains('asks nothing')));
      });
    }

    test('takes an https page with a host, whatever the case of its scheme', () {
      expect(_read({'title': 'Connect', 'url': 'HTTPS://a.example/x'})?.url.scheme, 'https');
    });

    test('keeps a kind and a status it does not know, and reports them', () {
      final authorization = _read({..._linear, 'type': 'device_code', 'status': 'paused'})!;

      expect(authorization.kind, const AIToolAuthorizationKind('device_code'));
      expect(authorization.kind.isKnown, isFalse);
      expect(authorization.status, const AIToolAuthorizationStatus('paused'));
      expect(authorization.status!.isKnown, isFalse);
      expect(reports, [contains('`type`'), contains('`status`')]);
    });

    test('reads every status it knows', () {
      for (final status in AIToolAuthorizationStatus.values) {
        final authorization = _read({..._linear, 'status': status})!;
        expect(authorization.status, status);
      }
      expect(reports, isEmpty);
    });

    test('reads a wrong-typed field as absent, and reports it', () {
      final authorization = _read({..._linear, 'message': 42, 'handoff_token': true})!;

      expect(authorization.message, isNull);
      expect(authorization.handoffToken, isNull);
      expect(reports, hasLength(2));
    });
  });

  group('expires_at', () {
    DateTime? expiry(String text) => _read({..._linear, 'expires_at': text})?.expiresAt;

    test('reads RFC 3339 times in UTC', () {
      expect(expiry('2026-10-21T21:42:19Z'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21t21:42:19z'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21 21:42:19Z'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21T21:42:19.8Z'), DateTime.utc(2026, 10, 21, 21, 42, 19, 800));
      expect(expiry('2026-10-21T21:42:19.834Z'), DateTime.utc(2026, 10, 21, 21, 42, 19, 834));
      // Go writes nanoseconds; microseconds are kept.
      expect(expiry('2026-10-21T21:42:19.834567891Z'), DateTime.utc(2026, 10, 21, 21, 42, 19, 834, 567));
      expect(expiry('2026-10-21T23:42:19+02:00'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21T16:12:19-05:30'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21T21:42:19-00:00'), DateTime.utc(2026, 10, 21, 21, 42, 19));
      expect(expiry('2026-10-21T21:42:19+23:59'), DateTime.utc(2026, 10, 20, 21, 43, 19));
      expect(expiry('2026-10-21T21:42:19Z')!.isUtc, isTrue);
      expect(reports, isEmpty);
    });

    for (final text in [
      '2026-10-21T21:42:19', // no offset: Dart would read it as local time
      '2026-10-21',
      '2026-10-21T21:42:19+0200',
      '20261021T214219Z',
      '2026-02-30T00:00:00Z', // Dart would roll it over into March
      '2026-13-01T00:00:00Z',
      '2026-10-21T24:00:00Z',
      '2026-10-21T23:59:60Z', // a leap second, which DateTime can't hold
      '2026-10-21T21:42:19+24:00', // offset hours run to 23
      '2026-10-21T21:42:19+99:99',
      '2026-10-21T21:42:19+02:60', // offset minutes run to 59
      '9999-12-31T23:59:59-23:59', // past year 9999 in UTC
      'tomorrow',
    ]) {
      test('reads "$text" as absent, and reports it', () {
        expect(expiry(text), isNull);
        expect(reports, [contains('RFC 3339')]);
      });
    }

    test('reads 29 February in a leap year', () {
      expect(expiry('2028-02-29T00:00:00Z'), DateTime.utc(2028, 2, 29));
    });
  });

  group('launchUrl', () {
    test('is the url itself without a handoff token', () {
      final authorization = _withToken(null, url: 'https://agent.example/launch/abc#keep');

      expect(authorization.launchUrl, authorization.url);
    });

    test('puts the handoff token in the fragment', () {
      expect(_withToken('tok_123').launchUrl.toString(), 'https://agent.example/launch/abc#handoff_token=tok_123');
    });

    test('replaces a fragment the url already has, and keeps its query', () {
      expect(
        _withToken('t', url: 'https://agent.example/launch?x=1#old').launchUrl.toString(),
        'https://agent.example/launch?x=1#handoff_token=t',
      );
    });

    test('percent-encodes what the page would read as form syntax', () {
      expect(_withToken('a+b&c=d').launchUrl.toString(), endsWith('#handoff_token=a%2Bb%26c%3Dd'));
    });

    test('percent-encodes spaces, hashes and non-ASCII text as UTF-8', () {
      expect(_withToken('a b#ü').launchUrl.toString(), endsWith('#handoff_token=a%20b%23%C3%BC'));
    });

    test('keeps the fragment-safe punctuation as is', () {
      const safe = r"!$'()*,-./:;?@_~";
      expect(_withToken('A1$safe').launchUrl.toString(), endsWith('#handoff_token=A1$safe'));
    });

    test('leaves a base64url token as is', () {
      const token = 'Zm9vYmFyLWJhel9xdXV4-_AbC123';
      expect(_withToken(token).launchUrl.fragment, 'handoff_token=$token');
    });
  });

  group('AIToolAuthorization', () {
    test('round-trips through toJson', () {
      final authorization = _read({..._linear, 'status': 'connected'})!;

      expect(_read(authorization.toJson()), authorization);
    });

    test('leaves absent fields out of toJson', () {
      final json = AIToolAuthorization(title: 'Connect', url: Uri.parse('https://a.example')).toJson();

      expect(json, {'type': 'oauth', 'title': 'Connect', 'url': 'https://a.example'});
    });

    test('has value equality', () {
      expect(_read(_linear), _read(_linear));
      expect(_read(_linear).hashCode, _read(_linear).hashCode);
      expect(_read(_linear), isNot(_read({..._linear, 'status': 'declined'})));
    });

    test('copyWith replaces the given fields and keeps the rest', () {
      final authorization = _read(_linear)!;
      final ended = authorization.copyWith(status: AIToolAuthorizationStatus.expired);

      expect(ended.status, AIToolAuthorizationStatus.expired);
      expect(ended, authorization.copyWith(status: AIToolAuthorizationStatus.expired));
      expect(ended.copyWith(status: AIToolAuthorizationStatus.expired), ended);
      expect(ended.copyWith().toJson(), {...authorization.toJson(), 'status': 'expired'});
    });

    test('reads a local expiry back in UTC, the same instant', () {
      final local = DateTime(2026, 10, 21, 23, 42, 19);
      final authorization = AIToolAuthorization(
        title: 'Connect',
        url: Uri.parse('https://a.example'),
        expiresAt: local,
      );

      final read = _read(authorization.toJson())!;
      expect(read.expiresAt, local.toUtc());
      expect(read.expiresAt!.isAtSameMomentAs(local), isTrue);
    });
  });

  group('AIToolCallPart with a sign-in', () {
    Map<String, Object?> payload({
      String status = 'awaiting_authorization',
      Object? authorization = _linear,
      String? id = 'call_1',
      String? targetUserId = 'alice',
    }) => {
      'id': ?id,
      'name': 'linear__list_issues',
      'display_title': 'Using Linear',
      'status': status,
      'target_user_id': ?targetUserId,
      'authorization': ?authorization,
    };

    AIToolCallPart call([Map<String, Object?>? json]) => AIToolCallPart.fromJson(json ?? payload(), id: 'call_1');

    test('reads the status and the sign-in', () {
      final part = call();

      expect(part.status, AIToolCallStatus.awaitingAuthorization);
      expect(part.status.isKnown, isTrue);
      expect(part.status.isFinished, isFalse);
      expect(part.authorization, _read(_linear));
      expect(reports, isEmpty);
    });

    test('reports a call awaiting authorization without a usable sign-in', () {
      final part = call(payload(authorization: {'title': 'Connect'}));

      expect(part.authorization, isNull);
      expect(reports, contains(contains('awaiting authorization but has no usable `authorization`')));
    });

    test('isAwaitingAuthorization holds for the targeted person, from any device', () {
      expect(call().isAwaitingAuthorization(userId: 'alice'), isTrue);
      expect(const AIClientIdentity(userId: 'alice').canAuthorize(call()), isTrue);
      expect(const AIClientIdentity(userId: 'alice', clientId: 'tablet').canAuthorize(call()), isTrue);
    });

    for (final (description, userId, json) in [
      ('for another person', 'bob', payload()),
      ('without a sign-in', 'alice', payload(authorization: null)),
      ('without an id from the agent', 'alice', payload(id: null)),
      ('once the sign-in ended', 'alice', payload(authorization: {..._linear, 'status': 'expired'})),
      ('once the call runs', 'alice', payload(status: 'running')),
    ]) {
      test('isAwaitingAuthorization does not hold $description', () {
        expect(call(json).isAwaitingAuthorization(userId: userId), isFalse);
      });
    }

    test('a declined sign-in makes the call declined', () {
      final declined = call(payload(status: 'cancelled', authorization: {..._linear, 'status': 'declined'}));
      final expired = call(payload(status: 'cancelled', authorization: {..._linear, 'status': 'expired'}));

      expect(declined.isDeclined, isTrue);
      expect(expired.isDeclined, isFalse);
    });

    test('round-trips through toJson, and takes part in equality and copyWith', () {
      final part = call();

      expect(AIToolCallPart.fromJson(part.toJson(), id: 'call_1'), part);
      expect(part.copyWith(authorization: part.authorization!.copyWith(title: 'Other')), isNot(part));
      expect(part.copyWith().authorization, part.authorization);
    });
  });
}
