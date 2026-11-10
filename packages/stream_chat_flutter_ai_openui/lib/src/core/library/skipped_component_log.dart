/// Where a component that can't join a library is reported.
///
/// Internal to the package.
@internal
library;

import 'dart:developer' as developer;

import 'package:meta/meta.dart';

/// Reports that a component was left out, with why.
///
/// It logs under the name `stream_chat_flutter_ai_openui`, where a debugger
/// shows it. Tests replace it to read what is reported.
@visibleForTesting
void Function(String message) skippedComponentLog = (message) {
  developer.log(message, name: 'stream_chat_flutter_ai_openui');
};

/// Reports that a component was left out, with why.
void logSkippedComponent(String message) => skippedComponentLog(message);
