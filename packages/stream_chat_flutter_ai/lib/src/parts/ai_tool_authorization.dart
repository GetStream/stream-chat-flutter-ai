import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai/src/parts/json_fields.dart';

/// How a person signs in — an [AIToolAuthorization]'s `type`.
///
/// An open set: compare against the kinds you know ([oauth]). A kind this
/// package doesn't know keeps its raw [value] and reports `false` from
/// [isKnown]; no sign-in is offered for it.
@immutable
class AIToolAuthorizationKind {
  /// Wraps a raw kind string.
  const AIToolAuthorizationKind(this.value);

  /// A consent at the provider, in a browser (OAuth).
  static const oauth = AIToolAuthorizationKind('oauth');

  /// The kinds this package knows.
  static const values = [oauth];

  /// The kind as the agent wrote it, such as `oauth`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  @override
  bool operator ==(Object other) => identical(this, other) || other is AIToolAuthorizationKind && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIToolAuthorizationKind($value)';
}

/// How a sign-in ended — an [AIToolAuthorization]'s `status`, absent while it
/// waits.
///
/// An open set: compare against the statuses you know ([connected],
/// [declined], [expired], [failed]). A status this package doesn't know keeps
/// its raw [value] and reports `false` from [isKnown].
@immutable
class AIToolAuthorizationStatus {
  /// Wraps a raw status string.
  const AIToolAuthorizationStatus(this.value);

  /// The person connected their account, so the call goes on.
  static const connected = AIToolAuthorizationStatus('connected');

  /// The person declined to sign in, so the call never ran.
  static const declined = AIToolAuthorizationStatus('declined');

  /// The sign-in expired before the person finished it.
  static const expired = AIToolAuthorizationStatus('expired');

  /// The provider or the agent's backend ended it without connecting, such as
  /// when the person came back as another account.
  static const failed = AIToolAuthorizationStatus('failed');

  /// The statuses this package knows.
  static const values = [connected, declined, expired, failed];

  /// The status as the agent's backend wrote it, such as `connected`.
  final String value;

  /// Whether this is one of [values].
  bool get isKnown => values.contains(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AIToolAuthorizationStatus && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AIToolAuthorizationStatus($value)';
}

/// A sign-in a tool call waits for, such as "Connect Linear", and how it
/// ended.
///
/// The agent's backend writes it as the `authorization` of an `ai_tool_call`
/// step whose status is `awaiting_authorization`, and holds the call until the
/// person signs in at the provider in a browser:
///
/// ```json
/// {"type": "oauth", "provider": "linear", "provider_name": "Linear", "title": "Connect Linear",
///  "message": "You sign in at Linear, and the agent never sees your password.",
///  "url": "https://agent.example/v1/agents/connectors/oauth/launch/…", "handoff_token": "…",
///  "expires_at": "2026-10-26T21:42:19.834Z"}
/// ```
///
/// Once they connect, the call goes on. When the sign-in is declined, expires
/// or fails, the call is cancelled and never runs. The step holds no
/// credential: [url] is the agent's own sign-in page, and the provider hands
/// what it grants to the agent's backend, never to the app.
@immutable
class AIToolAuthorization {
  /// Creates an [AIToolAuthorization].
  const AIToolAuthorization({
    this.kind = AIToolAuthorizationKind.oauth,
    this.provider = '',
    this.providerName,
    required this.title,
    this.message,
    required this.url,
    this.handoffToken,
    this.expiresAt,
    this.status,
  });

  /// Reads an `authorization` object leniently, or returns `null` when it asks
  /// nothing: it has no `title`, or its `url` isn't an `http` or `https` page
  /// with a host. Any other missing or wrong-typed field reads as its default,
  /// and nothing throws.
  ///
  /// [context] names the step in debug reports, such as
  /// `ai_tool_call "call_1"`.
  static AIToolAuthorization? fromJson(Map<String, Object?> json, {String? context}) {
    final where = context == null ? 'authorization' : '$context authorization';
    final fields = PartFields(json, where);
    final title = fields.string('title');
    final url = switch (fields.string('url')) {
      final url? => Uri.tryParse(url),
      null => null,
    };
    if (title == null || url == null || !isWebPage(url)) {
      reportPartIssue(() => '$where asks nothing: it needs a `title` and an http(s) `url` with a host.');
      return null;
    }
    return AIToolAuthorization(
      kind: switch (fields.string('type')) {
        final kind? => reportUnknown<AIToolAuthorizationKind>(
          AIToolAuthorizationKind(kind),
          (k) => k.isKnown,
          where,
          'type',
        ),
        null => AIToolAuthorizationKind.oauth,
      },
      provider: fields.string('provider') ?? '',
      providerName: fields.string('provider_name'),
      title: title,
      message: fields.string('message'),
      url: url,
      handoffToken: fields.string('handoff_token'),
      expiresAt: fields.date('expires_at'),
      status: switch (fields.string('status')) {
        final status? => reportUnknown<AIToolAuthorizationStatus>(
          AIToolAuthorizationStatus(status),
          (s) => s.isKnown,
          where,
          'status',
        ),
        null => null,
      },
    );
  }

  /// Whether [url] is a web page a browser can open: `http` or `https`, with a
  /// host.
  @visibleForTesting
  static bool isWebPage(Uri url) => (url.scheme == 'http' || url.scheme == 'https') && url.host.isNotEmpty;

  /// How the person signs in. Defaults to [AIToolAuthorizationKind.oauth] when
  /// the agent sends none.
  final AIToolAuthorizationKind kind;

  /// The provider, such as `linear`. Empty when the agent sent none.
  final String provider;

  /// What people call the provider, such as "Linear".
  final String? providerName;

  /// The question, such as "Connect Linear".
  final String title;

  /// What signing in means for the person.
  final String? message;

  /// The sign-in page. Open [launchUrl], which carries the [handoffToken].
  final Uri url;

  /// What binds the sign-in to the first browser that opens it. It goes in
  /// the page's fragment, which no server sees ([launchUrl]). Gone once the
  /// sign-in is over.
  final String? handoffToken;

  /// When the sign-in expires, in UTC.
  final DateTime? expiresAt;

  /// How the sign-in ended, once it did; `null` while it waits.
  final AIToolAuthorizationStatus? status;

  /// Whether the sign-in is over, one way or another.
  bool get hasEnded => status != null;

  /// The page to open in a browser: [url] with its fragment replaced by
  /// `handoff_token=<handoffToken>`, or [url] itself without a token.
  ///
  /// The page reads its fragment as form parameters, where `+` is a space and
  /// `&` and `=` separate them, so the token is percent-encoded, keeping only
  /// ASCII letters, digits and `!$'()*,-./:;?@_~`.
  Uri get launchUrl {
    final token = handoffToken;
    if (token == null) return url;
    return Uri.parse('${url.removeFragment()}#handoff_token=${_encodeFragmentValue(token)}');
  }

  static String _encodeFragmentValue(String value) {
    final encoded = StringBuffer();
    for (final byte in utf8.encode(value)) {
      if (_isFragmentSafe(byte)) {
        encoded.writeCharCode(byte);
      } else {
        encoded.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
      }
    }
    return encoded.toString();
  }

  static bool _isFragmentSafe(int byte) =>
      (byte >= 0x30 && byte <= 0x39) || // 0-9
      (byte >= 0x41 && byte <= 0x5A) || // A-Z
      (byte >= 0x61 && byte <= 0x7A) || // a-z
      r"!$'()*,-./:;?@_~".codeUnits.contains(byte);

  /// A copy with the given fields replaced. A `null` argument keeps the
  /// current value.
  AIToolAuthorization copyWith({
    AIToolAuthorizationKind? kind,
    String? provider,
    String? providerName,
    String? title,
    String? message,
    Uri? url,
    String? handoffToken,
    DateTime? expiresAt,
    AIToolAuthorizationStatus? status,
  }) {
    return AIToolAuthorization(
      kind: kind ?? this.kind,
      provider: provider ?? this.provider,
      providerName: providerName ?? this.providerName,
      title: title ?? this.title,
      message: message ?? this.message,
      url: url ?? this.url,
      handoffToken: handoffToken ?? this.handoffToken,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  /// The sign-in as an `authorization` object, which
  /// [AIToolAuthorization.fromJson] reads back to an equal sign-in. Absent
  /// fields are left out.
  Map<String, Object?> toJson() => {
    'type': kind.value,
    if (provider.isNotEmpty) 'provider': provider,
    'provider_name': ?providerName,
    'title': title,
    'message': ?message,
    'url': url.toString(),
    'handoff_token': ?handoffToken,
    'expires_at': ?expiresAt?.toUtc().toIso8601String(),
    'status': ?status?.value,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AIToolAuthorization &&
          other.kind == kind &&
          other.provider == provider &&
          other.providerName == providerName &&
          other.title == title &&
          other.message == message &&
          other.url == url &&
          other.handoffToken == handoffToken &&
          other.expiresAt == expiresAt &&
          other.status == status;

  @override
  int get hashCode => Object.hash(kind, provider, providerName, title, message, url, handoffToken, expiresAt, status);

  @override
  String toString() => 'AIToolAuthorization(provider: $provider, title: $title, status: ${status?.value})';
}
