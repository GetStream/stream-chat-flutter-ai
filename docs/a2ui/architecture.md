# How the A2UI package works

`packages/stream_chat_flutter_ai_a2ui` is a renderer plugin for the generative UI of `stream_chat_flutter_ai`. It
turns the A2UI 1.0 messages an agent writes in a reply into widgets, and turns what the person does with them into
`AIUIAction`s for the host. This page is for people changing the package; the customer-facing documents are the
package's [README](../../packages/stream_chat_flutter_ai_a2ui/README.md) and
[component reference](../../packages/stream_chat_flutter_ai_a2ui/doc/components.md).

## Layers

Roughly, each layer builds on the ones below it.

| Folder (`lib/src/`) | What it is |
| --- | --- |
| `a2ui_renderer.dart`, `a2ui_error.dart` | The public entry point (`A2UIRenderer`) and error type. The renderer is an `AIUIRenderer`: the host calls its `createEngine`, and asks it for `capabilities` (the instructions the agent is told). |
| `surface/` | Widgets of a reply: `A2UIReplyView` (one reply's surfaces, one below the other), `A2UISurfaceView` (one surface), `A2UISurfaceScope` (what the components below read: catalog, theme, media function, link opener) and `A2UIStreamTheme`, which makes the design system's components draw with the A2UI theme. |
| `catalog/` | `A2UICatalog` (a builder for each type), `A2UIComponentScope` (what a builder reads and writes), `A2UIThemeData` and its resolved form, `A2UINodeView` (the widget of one component) and the builders in `basic/`. |
| `engine/` | `A2UIEngine`, the `AIUIEngine` that owns a conversation's replies and links the processor to the host: action labels, the host's components placed as A2UI components, instructions for the agent. |
| `core/` | The adapter over `a2ui_core`: processor, stream splitting, surfaces, nodes, checks, versions, catalogs, error mapping. |

### What is ours and what is `a2ui_core`'s

`a2ui_core` is the A2UI project's own Dart library: it parses messages, keeps data models, resolves bindings and
function calls and holds the basic catalog. `lib/src/core/a2ui_adapter.dart` is the only library that imports it (and
`json_schema_builder`, the schema library its catalogs are written in); a test, `a2ui_core_import_guard_test.dart`,
keeps it so. No type of either appears in the package's API, so the protocol library can be replaced without touching
the other layers. What the adapter adds, and so what this package is responsible for:

- version handling: only A2UI 1.0, with the spellings agents write (`v1.0`, `1`, ...) rewritten as `1.0`
  (`a2ui_versions.dart`);
- the error mapping: every problem becomes an `A2UIError` with an A2UI 1.0 code, reported as a value, never thrown
  (`a2ui_core_errors.dart`);
- the catalogs: the basic catalog under its own id and under the app's catalog id, loosened for style properties, plus
  the host's components (`a2ui_catalogs.dart`);
- checks: which of a component's `checks` fail, and with what message and severity (`a2ui_checks.dart`);
- action events, and the routing of a function no catalog has to the host's tools (`a2ui_action_event.dart`,
  `a2ui_agent_function.dart`);
- the limits a surface must stay within: 5,000 expanded components and 50 levels of nesting (`a2ui_expansion.dart`),
  which a surface past takes its root away until it fits;
- keeping a secret out of what the agent hears (below).

## Data flow

```
reply text ──► A2UIStream.messages ──► A2UIProcessor.apply ──► A2UISurface ──► A2UINode ──► builder ──► widget
 (AIUIDocument)   (complete JSON objects)   (a2ui_core core)    (tree + data)   (component)  (catalog)
                                                                                    ▲             │
person taps ──► A2UIComponentScope.performAction ──► A2UINode.act ──► A2UIActionEvent ──► AIUIHost.send
```

1. **Reply to messages.** The host hands the engine an `AIUIDocument` for each reply, again and again while the agent
   writes. `A2UIStream.messages` finds the complete top-level JSON objects in the text, ignoring prose between them
   and an object still being written. `A2UIStream.added` says whether the new messages only extend those already
   applied: if so the processor applies just the added ones, otherwise it is reset and applies all.
2. **Messages to surfaces.** Each reply has an `A2UIProcessor`, which checks each message's version and shape, applies it
   to the core, and keeps one `A2UISurface` per `surfaceId`. A message that can't be applied is skipped and reported;
   the ones after it still apply. The processor notifies when a surface comes or goes.
3. **Surface to nodes.** A surface resolves its components against its data model into a tree of `A2UINode`s, each
   notifying when its own properties or children change. Resolution checks the structure: a missing `root`, a
   component that names itself or a child that doesn't exist, circles.
4. **Node to widget.** `A2UINodeView` listens to a node, picks the builder for its type from the surface's
   `A2UICatalog`, and wraps what it returns in an `AIUIEntrance` (so components animate in as the reply streams) and the
   component's accessibility attributes. A node that isn't resolved yet, or whose type has no builder, draws nothing.
   A builder that throws draws nothing; the error goes to `FlutterError` and to `onError` as `EXECUTION_ERROR`.
5. **Widget to action.** A builder reads and writes through its `A2UIComponentScope`: `value`, `string`, `child`, ...
   to read; `write` to put what the person entered in the data model; `performAction` to run the component's action.
   `A2UINode.act` runs the action as the person's own act, in a zone that marks it so, which is what lets a function
   with side effects run. An `event` becomes an `A2UIActionEvent` for the engine, which sends the host an `AIUIAction`:
   the label is the text of the button's child (else the event's name in words), the payload holds `surfaceId`,
   `sourceComponentId`, `context`, `userMessage` and, when the surface asked for it, `dataModel`.
6. **Links and tools.** `openUrl` goes to the host's `open`. A function no catalog has is run as one of the host's tools
   (`AIUIHost.runTool`), a read-only one whenever the surface calls it, any other only as a person's act.

## Lifecycle

- The engine makes a reply's processor the first time `view` is asked for it and keeps it until the host removes the
  reply or disposes the engine, so what the person typed survives scrolling. Work the host triggers while the tree
  builds (`receive`, errors, tools) waits for the end of the frame.
- A surface is disposed when the agent deletes it and when its processor is reset or disposed; it first tells its
  listeners the root is gone.
- A `Modal` builds its sheet in a separate route; it receives the surface's scope, the app's component builders and
  the content again, so the sheet follows the surface.
- Players (`Video`, `AudioPlayer`) are let go when their component leaves the tree, their URL changes, or an opaque
  route covers them.

## Theme and the design system

`A2UIThemeData` (the app's overrides) is layered over the nearest `A2UITheme`, and the values neither sets come from
`StreamTheme`, into an `A2UIResolvedTheme` read each time a reply builds. `A2UIStreamTheme` then re-themes the design
system's components below the surface (buttons, fields, check boxes, sheets) with those values, under Material 3 even
in a Material 2 app. Components drawn by the design system's own widgets take the app's `StreamComponentFactory`
builders; each section of the component reference names the hook.

## Secrets

An `obscured` `TextField`:

- is never given to the app's `textInput` builder, which could show the text; the field is drawn by the package, in the
  same style;
- is never suggested or auto-corrected;
- never becomes a button's label: `A2UISurface.buttonTextOf` returns nothing for a path that holds, is in or is what an
  `obscured` field writes.

Its text is in the data model like any other value, so a surface created with `sendDataModel`, or an action `context`
that binds it, sends it to the host. That is the agent's own request.

## Errors

Problems are values. `A2UIProcessor` collects them (from the core, from the adapter's own checks, from builders through
`reportOnce` / `reportBuildError`) as `A2UIError`s with a code (`VALIDATION_FAILED`, `INTEGRITY_ERROR`,
`UNKNOWN_COMPONENT_TYPE`, `EXECUTION_ERROR`, `RECURSION_LIMIT_EXCEEDED`, ...); the engine delivers them to the
renderer's `onError` with the reply's message id, after the frame, since the app may rebuild in its handler. Without an
`onError`, they are logged in debug builds. A problem is reported once for as long as it lasts. Some problems are
never reported to `onError`: a message that isn't a JSON object, and a reply that ends without a whole tree, are
debug-build logs only (see the `A2UIRenderer` constructor's dartdoc).

## The app's components

The host's `components` (`AIUIComponent`) join the catalogs as A2UI types in PascalCase: `place_card` becomes
`PlaceCard`, its parameters become properties. `a2uiPlaceableComponents` leaves out the ones that can't be placed
(a basic type's name, a parameter named `id`, `weight` or `accessibility`, a duplicate) and reports why in debug
builds. The engine builds them in `_buildAppComponent`: arguments are read from the scope, a value that doesn't fit
draws nothing and is reported once the reply is written, and the events the component emits go to the host as
`AIUIAction`s with the component's name, the surface id and the source component id added.
