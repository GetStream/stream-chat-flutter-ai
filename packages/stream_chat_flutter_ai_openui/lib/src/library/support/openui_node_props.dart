import 'package:meta/meta.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/openui_node.dart';

/// [node] with each of [props] set, the others as they were.
///
/// Internal to the package.
@internal
ElementNode withOpenUIProps(ElementNode node, Map<String, OpenUIValue> props) {
  return ElementNode(
    typeName: node.typeName,
    props: {...node.props, ...props},
    partial: node.partial,
    hasDynamicProps: node.hasDynamicProps,
    statementId: node.statementId,
  );
}
