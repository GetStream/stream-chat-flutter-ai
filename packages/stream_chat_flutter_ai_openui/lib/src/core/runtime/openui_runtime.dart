/// The runtime one reply's program runs in.
///
/// Internal to the package.
@internal
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_library_schema.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/ast.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/openui_stream_parser.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parse_result.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/parser/parser_errors.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_event.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/action_plan.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/evaluator.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/form_validation.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/query_manager.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/store.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/js.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/values/openui_value.dart';
import 'package:stream_chat_flutter_ai_openui/src/openui_error.dart';

/// A form field a component shows: bound to a `$variable`, or held in its
/// form's state.
@immutable
final class StateField {
  /// Creates the field [name] showing [value].
  const StateField({required this.name, required this.value, required this.isBound, required this.set});

  /// The field's name.
  final String name;

  /// What it shows; absent when it has nothing.
  final OpenUIValue? value;

  /// Whether it reads and writes a `$variable`.
  final bool isBound;

  /// Writes what the person entered.
  final void Function(OpenUIValue? value) set;
}

/// The state of one reply's program, as OpenUI's `useOpenUIState` keeps it:
/// reading its text as it streams, its `$variables` and form fields, its
/// queries and mutations, its evaluated tree and its errors, and running its
/// actions.
///
/// Keep one per reply, so its state outlives the widgets that show it.
final class OpenUIRuntime {
  /// Creates the runtime of a reply read against `schema`.
  ///
  /// `isBindable` names the props that take a `$variable` both ways; `tools`
  /// runs its queries and mutations, which never run without it;
  /// `functions` are the library's functions the app runs; `initialState`
  /// is state kept from before, as [state] gave it; `timer` starts the
  /// debounce and refresh timers.
  OpenUIRuntime({
    required OpenUILibrarySchema schema,
    this._isBindable,
    OpenUIToolProvider? tools,
    this._functions = const {},
    Map<String, Object?>? initialState,
    OpenUITimerFactory? timer,
  }) : _schema = schema,
       _parser = OpenUIStreamParser(schema),
       _queries = QueryManager(tools: tools, timer: timer),
       _initialState = _toValues(initialState) {
    // Saved state is applied once, here, and again only by [restore]: later
    // declarations only change defaults, so they never revert what was typed.
    if (_initialState != null) _initializeStore(applyPersisted: true);
    _store.onChange = _storeChanged;
    _queries.onChange = _queriesChanged;
  }

  final OpenUILibrarySchema _schema;
  final BindablePropTest? _isBindable;
  final Map<String, OpenUIFunction> _functions;
  final OpenUIStreamParser _parser;
  final QueryManager _queries;
  final _store = OpenUIStore();
  final _root = ValueNotifier<ElementNode?>(null);
  final _isQueryLoading = ValueNotifier(false);
  final _errors = ValueNotifier<List<OpenUIError>>(const []);
  final _state = ValueNotifier<Map<String, OpenUIValue>>(const {});
  final _actions = StreamController<OpenUIActionEvent>.broadcast(sync: true);

  Map<String, OpenUIValue>? _initialState;
  String? _text;
  final _streaming = ValueNotifier<bool>(false);
  ParseResult? _result;
  String? _storeKey;
  bool _recomputing = false;
  bool _recomputeAgain = false;
  bool _initializing = false;
  List<OpenUIError> _runtimeErrors = const [];
  bool _disposed = false;

  /// The most passes one update evaluates the tree in, when evaluating it
  /// changes what it reads: an app's function can write the state.
  static const maxPasses = 8;

  /// The evaluated tree; `null` before there is one.
  ValueListenable<ElementNode?> get root => _root;

  /// Whether any query is fetching.
  ValueListenable<bool> get isQueryLoading => _isQueryLoading;

  /// The errors to send back to the model: none while the reply streams.
  ValueListenable<List<OpenUIError>> get errors => _errors;

  /// The `$variables` and form fields, without the secret ones, to keep and
  /// give back as `initialState` or to [restore].
  ValueListenable<Map<String, OpenUIValue>> get state => _state;

  /// The actions for the host: messages to the model, links to open, and
  /// the library's own actions.
  Stream<OpenUIActionEvent> get actions => _actions.stream;

  /// Whether the reply is still streaming.
  bool get isStreaming => _streaming.value;

  /// [isStreaming], notifying when it changes, which a reply that ends with
  /// the text it already had does without changing [root].
  ValueListenable<bool> get streaming => _streaming;

  /// Reads the reply's whole text so far, `text`.
  ///
  /// While `isStreaming`, queries and mutations don't run and [errors] is
  /// empty; a statement cut short has its defaults replaced once it ends.
  /// Then it initializes the state, runs the queries, evaluates the tree, at
  /// most [maxPasses] times, and collects the errors.
  void update(String? text, {required bool isStreaming}) {
    if (_disposed) return;
    if (text == _text && isStreaming == _streaming.value && _result != null) return;
    _text = text;
    _streaming.value = isStreaming;
    _result = text == null || text.isEmpty ? null : _parser.set(text, complete: !isStreaming);
    _initializeStore();
    _runQueries();
    _recompute();
    _collectErrors();
  }

  /// Applies `state`, kept from before, over the declared defaults.
  void restore(Map<String, Object?> state) {
    if (_disposed) return;
    _initialState = _toValues(state);
    _initializeStore(applyPersisted: true);
    _runQueries();
    _recompute();
  }

  /// Stops the queries' refresh timers, such as while the app is in the
  /// background; their data stays.
  void pause() => _queries.pause();

  /// Starts the refresh timers [pause] stopped.
  void resume() => _queries.resume();

  /// Stops every timer and call, and closes [actions]; nothing changes
  /// afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _queries.dispose();
    unawaited(_actions.close());
    _root.dispose();
    _streaming.dispose();
    _isQueryLoading.dispose();
    _errors.dispose();
    _state.dispose();
  }

  static Map<String, OpenUIValue>? _toValues(Map<String, Object?>? state) {
    if (state == null) return null;
    return {for (final MapEntry(:key, :value) in state.entries) key: OpenUIValue.fromJson(value)};
  }

  // What expressions read: a field as its value, and a secret one as
  // nothing, so no expression, query or payload can read a password.
  OpenUIValue? _read(String name) {
    final value = _store.get(name);
    if (OpenUIStore.isSecret(value)) return null;
    if (value case OpenUIObject(:final fields) when fields.containsKey('value')) return fields['value'];
    return value == null ? null : OpenUIStore.withoutSecrets(value);
  }

  EvaluationContext _context({Map<String, OpenUIValue> extraScope = const {}}) {
    return EvaluationContext(
      getState: _read,
      resolveRef: _queries.result,
      schema: _schema,
      isBindable: _isBindable,
      functions: _functions,
      extraScope: extraScope,
    );
  }

  // Writes the saved state and the declared defaults as one change: the
  // store's callbacks wait until it is done, and the caller runs the queries
  // and evaluates the tree once for all of it.
  void _initializeStore({bool applyPersisted = false}) {
    final declarations = _result?.stateDeclarations ?? const {};
    final key = JS.jsonStringify(OpenUIObject(declarations));
    if (key == _storeKey && !applyPersisted) return;
    _storeKey = key;
    _initializing = true;
    try {
      _store.initialize(defaults: declarations, persisted: applyPersisted ? _persistedBindings() : const {});
    } finally {
      _initializing = false;
    }
    _publishState();
  }

  // The saved `$variables`, handed to the store; the saved form fields are
  // set in it directly.
  Map<String, OpenUIValue> _persistedBindings() {
    final bindings = <String, OpenUIValue>{};
    for (final MapEntry(:key, :value) in (_initialState ?? const <String, OpenUIValue>{}).entries) {
      if (key.startsWith(r'$')) {
        bindings[key] = value;
      } else {
        _store.set(key, value);
      }
    }
    return bindings;
  }

  void _publishState() {
    final next = {
      for (final MapEntry(:key, :value) in _store.snapshot.entries)
        if (!OpenUIStore.isSecret(value)) key: OpenUIStore.withoutSecrets(value),
    };
    // Only a change notifies: the host saves the state each time it does.
    if (!mapEquals(next, _state.value)) _state.value = next;
  }

  void _runQueries() {
    if (_streaming.value) return;
    final result = _result;
    final context = _context();
    OpenUIValue? evaluate(AstNode? node) => node == null ? null : Evaluator.evaluate(node, context);
    _queries
      ..updateQueries([
        for (final query in result?.queryStatements ?? const <QueryStatementInfo>[])
          QueryNode(
            statementId: query.statementId,
            toolName: JS.toStringOrEmpty(evaluate(query.tool)),
            args: evaluate(query.args) ?? OpenUINull.instance,
            defaults: evaluate(query.defaults) ?? OpenUINull.instance,
            deps: switch (query.deps) {
              final names? when names.isNotEmpty => OpenUIObject({
                for (final name in names) name: _read(name) ?? OpenUINull.instance,
              }),
              _ => null,
            },
            refreshSeconds: switch (evaluate(query.refresh)) {
              null => null,
              final value => JS.toNumber(value),
            },
          ),
      ])
      ..updateMutations({
        for (final mutation in result?.mutationStatements ?? const <MutationStatementInfo>[])
          mutation.statementId: JS.toStringOrEmpty(evaluate(mutation.tool)),
      });
  }

  void _recompute() {
    if (_disposed) return;
    if (_recomputing) {
      _recomputeAgain = true;
      return;
    }
    _recomputing = true;
    try {
      var passes = 0;
      do {
        _recomputeAgain = false;
        passes += 1;
        final (root, errors) = PropEvaluator.evaluateRoot(_result, _context());
        _runtimeErrors = errors;
        if (root != _root.value) _root.value = root;
        _isQueryLoading.value = _queries.snapshot.loading.isNotEmpty;
      } while (_recomputeAgain && passes < maxPasses);
    } finally {
      _recomputing = false;
    }
  }

  void _collectErrors() {
    if (_disposed) return;
    if (_streaming.value) {
      if (_errors.value.isNotEmpty) _errors.value = const [];
      return;
    }
    final result = _result;
    final collected = [
      if ((_text ?? '').isNotEmpty && (result?.meta.statementCount ?? 0) == 0)
        OpenUIError(
          source: OpenUIErrorSource.parser,
          code: OpenUIErrorCode.parseFailed,
          message: 'Response could not be parsed as valid openui-lang',
          hint:
              'The entire response must be valid openui-lang code starting with root = ${_schema.root ?? 'Root'}(...)',
        ),
      if (result != null) ...parserErrors(result, _schema),
      ..._runtimeErrors,
      ..._queries.snapshot.errors,
    ];
    if (!listEquals(collected, _errors.value)) _errors.value = collected;
  }

  void _storeChanged(String key) {
    if (_disposed || _initializing) return;
    if (key.startsWith(r'$')) {
      _runQueries();
      _recompute();
    }
    _publishState();
  }

  void _queriesChanged() {
    _recompute();
    _collectErrors();
  }

  /// What the field `name` of the form `formName` shows: a `$variable` at
  /// the top level, a field under its form, unwrapped from `{value, …}`.
  OpenUIValue? fieldValue(String? formName, String name) {
    if (formName == null) return _unwrap(_store.get(name));
    final form = _store.get(formName);
    return form is OpenUIObject ? _unwrap(form.fields[name]) : null;
  }

  static OpenUIValue? _unwrap(OpenUIValue? value) {
    if (value case OpenUIObject(:final fields) when fields.containsKey('value')) return fields['value'];
    return value;
  }

  /// Writes the field `name` of the form `formName` as `{value,
  /// componentType[, secret: true]}`.
  void setFieldValue(
    String? formName,
    String name,
    OpenUIValue? value, {
    String? componentType,
    bool isSecret = false,
  }) {
    final field = OpenUIObject({
      'value': value ?? OpenUINull.instance,
      if (componentType != null) 'componentType': OpenUIString(componentType),
      if (isSecret) 'secret': const OpenUIBool(true),
    });
    if (formName == null) {
      _store.set(name, field);
      return;
    }
    final form = _store.get(formName);
    _store.set(formName, OpenUIObject({if (form is OpenUIObject) ...form.fields, name: field}));
  }

  /// The field `name` a component shows, bound to the `$variable` its
  /// `binding` prop names, or held in the form `formName`.
  ///
  /// A bound field's setter writes what its binding's expression gives with
  /// `$value` as what was entered, or what was entered when it gives
  /// nothing. A secret field, such as a password, is never bound: a
  /// `$variable` would let any expression read it.
  StateField stateField(
    String name, {
    OpenUIValue? binding,
    String? formName,
    String? componentType,
    bool isSecret = false,
  }) {
    final target = ReactiveBinding.targetOf(binding);
    if (!isSecret && target != null) {
      final expression = ReactiveBinding.expressionOf(binding);
      return StateField(
        name: name,
        value: _read(target),
        isBound: true,
        set: (value) {
          if (_disposed) return;
          final entered = value ?? OpenUINull.instance;
          final next = expression == null
              ? entered
              : Evaluator.evaluate(expression, _context(extraScope: {r'$value': entered})) ?? entered;
          _store.set(target, next);
        },
      );
    }
    final current = fieldValue(formName, name);
    final fallback = target != null ? null : binding;
    return StateField(
      name: name,
      value: JS.isNullish(current) ? (fallback ?? current) : current,
      isBound: false,
      set: (value) {
        if (_disposed) return;
        setFieldValue(formName, name, value, componentType: componentType, isSecret: isSecret);
      },
    );
  }

  /// The errors of the fields of the form `formName` that fail their rules,
  /// by field name; `rules` holds each field's rules as the program wrote
  /// them, and `bindings` the value prop of each field bound to a
  /// `$variable`, which is checked instead of the form's state.
  Map<String, String> validate(
    String? formName,
    Map<String, OpenUIValue?> rules, {
    Map<String, OpenUIValue?> bindings = const {},
  }) {
    OpenUIValue? valueOf(String name) => switch (ReactiveBinding.targetOf(bindings[name])) {
      final target? => _read(target),
      null => fieldValue(formName, name),
    };
    return {
      for (final MapEntry(key: name, value: fieldRules) in rules.entries)
        if (FormValidation.validate(valueOf(name), FormValidation.parse(fieldRules)) case final error?) name: error,
    };
  }

  // The form state an event carries: `{formName: fields}`, or the whole
  // state outside a form, without the secret fields.
  Map<String, OpenUIValue> _formState(String? formName) {
    final form = formName == null ? null : _store.get(formName);
    if (form is OpenUIObject && !OpenUIStore.isSecret(form)) return {formName!: OpenUIStore.withoutSecrets(form)};
    return _state.value;
  }

  void _emit(
    String type,
    String? formName, {
    Map<String, OpenUIValue> params = const {},
    String message = '',
    String label = '',
  }) {
    if (_disposed) return;
    _actions.add(
      OpenUIActionEvent(
        type: type,
        params: params,
        message: message,
        label: label,
        formName: formName,
        formState: _formState(formName),
      ),
    );
  }

  /// Runs `action`, the action prop of the control labelled `label` in the
  /// form `formName`.
  ///
  /// A plan runs its steps in order: `@Set` and `@Reset` write the state,
  /// `@Run` runs a mutation, waiting for it and stopping the plan when it
  /// fails, or fetches a query again; the others go to [actions], each with
  /// the form state as it is when the step runs. A legacy `{type, params}`
  /// object, or no action, sends a message to the model labelled with the
  /// control.
  Future<void> trigger({required String label, String? formName, OpenUIValue? action}) async {
    if (_disposed) return;
    if (action case OpenUIObject(:final fields) when !ActionPlan.isPlan(action)) {
      final typeValue = fields['type'];
      final type = JS.isTruthy(typeValue) ? JS.stringOf(typeValue) : OpenUIActionEvent.continueConversation;
      // Only a real call sends one of the library's actions.
      if (_schema.callOf(type) case CallDef(kind: CallKind.action, isBuiltin: false)) return;
      _emit(
        type,
        formName,
        params: {
          if (fields['params'] case OpenUIObject(fields: final params)) ...params,
          if (fields['url'] case final url? when JS.isTruthy(url)) 'url': url,
          if (fields['context'] case final context? when JS.isTruthy(context)) 'context': context,
        },
        message: label,
        label: label,
      );
      return;
    }
    if (action is! OpenUIObject) {
      _emit(OpenUIActionEvent.continueConversation, formName, message: label, label: label);
      return;
    }
    for (final step in ActionPlan.stepsOf(ActionPlan.ownSteps(action))) {
      if (_disposed) return;
      if (step is! OpenUIObject) continue;
      final fields = step.fields;
      switch (fields['type']) {
        case OpenUIString(value: ActionStepType.run):
          final id = JS.toStringOrEmpty(fields['statementId']);
          if (fields['refType'] == const OpenUIString('mutation')) {
            final args = _result?.mutationStatements.where((mutation) => mutation.statementId == id).firstOrNull?.args;
            final evaluated = args == null ? null : Evaluator.evaluate(args, _context());
            final succeeded = await _queries.runMutation(id, evaluated is OpenUIObject ? evaluated.fields : const {});
            if (!succeeded) return;
          } else {
            _queries.invalidate([id]);
          }
        case OpenUIString(value: ActionStepType.continueConversation):
          _emit(
            OpenUIActionEvent.continueConversation,
            formName,
            params: {'context': ?fields['context']},
            message: JS.toStringOrEmpty(fields['message']),
            label: label,
          );
        case OpenUIString(value: ActionStepType.openUrl):
          _emit(OpenUIActionEvent.openUrl, formName, params: {'url': fields['url'] ?? const OpenUIString('')});
        case OpenUIString(value: ActionStepType.customAction):
          _emit(
            JS.toStringOrEmpty(fields['name']),
            formName,
            params: switch (fields['params']) {
              OpenUIObject(fields: final params) => params,
              _ => const {},
            },
            label: label,
          );
        case OpenUIString(value: ActionStepType.set):
          if ((fields['target'], fields['valueAST']) case (
            OpenUIString(value: final target),
            OpenUIExpression(node: final value),
          )) {
            _store.set(target, Evaluator.evaluate(value, _context()));
          }
        case OpenUIString(value: ActionStepType.reset):
          final declarations = _result?.stateDeclarations ?? const {};
          final targets = fields['targets'];
          for (final target in targets is OpenUIArray ? targets.items : const <OpenUIValue>[]) {
            if (target case OpenUIString(value: final name)) {
              _store.set(name, declarations[name] ?? OpenUINull.instance, pristine: true);
            }
          }
        default:
          break;
      }
    }
  }
}
