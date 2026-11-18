import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/core/runtime/tool_provider.dart';

void main() {
  test('a tool that is not found is reported with the tools the provider has', () {
    const error = ToolNotFoundException('list', availableTools: ['search', 'save']);

    expect(error.toString(), '[openui] No handler for tool "list". Available: search, save');
  });

  test('a tool that is not found is reported with none available when the provider has no tools', () {
    const error = ToolNotFoundException('list');

    expect(error.toString(), '[openui] No handler for tool "list". Available: (none)');
  });

  test('an MCP tool error reports what the tool said', () {
    const error = McpToolException('quota exceeded');

    expect(error.toString(), 'MCP tool error: quota exceeded');
  });

  test('an MCP tool error reports an unknown error when the tool said nothing', () {
    const error = McpToolException('');

    expect(error.toString(), 'MCP tool error: Unknown error');
  });
}
