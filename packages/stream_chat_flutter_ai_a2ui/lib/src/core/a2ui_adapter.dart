/// The package's own view of an A2UI core: one reply's surfaces, their
/// components resolved against their data models, and the catalogs they are
/// drawn from.
///
/// This library is the only place that uses the A2UI core library the package
/// is built on, and the schema library that core takes its catalogs in.
/// Everything it exposes is the package's own types, so the core can be
/// replaced without changing the rest of the package.
///
/// Internal to the package.
@internal
library;

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart' show Schema;
import 'package:stream_chat_flutter_ai_a2ui/src/a2ui_error.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_action_event.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_stream.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/core/a2ui_versions.dart';

part 'a2ui_agent_function.dart';
part 'a2ui_catalogs.dart';
part 'a2ui_checks.dart';
part 'a2ui_test_interface.dart';
part 'a2ui_core_errors.dart';
part 'a2ui_expansion.dart';
part 'a2ui_node.dart';
part 'a2ui_processor.dart';
part 'a2ui_surface.dart';
part 'a2ui_topology.dart';
