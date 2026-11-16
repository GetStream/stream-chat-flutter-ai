import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_openui/src/library/support/openui_support.dart';

void main() {
  group('openUIDecodeWidth', () {
    Future<int> decode(WidgetTester tester, {double? extent, BoxFit fit = BoxFit.cover, double ratio = 2}) async {
      late int width;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(size: const Size(400, 800), devicePixelRatio: ratio),
          child: Builder(
            builder: (context) {
              width = openUIDecodeWidth(context, extent: extent, fit: fit);
              return const SizedBox();
            },
          ),
        ),
      );
      return width;
    }

    testWidgets('decodes at the box width in device pixels when the box is fit whole', (tester) async {
      expect(await decode(tester, extent: 100, fit: BoxFit.contain), 200);
    });

    testWidgets('doubles it when the image covers, fills or fits the height', (tester) async {
      expect(await decode(tester, extent: 100, fit: BoxFit.cover), 400);
      expect(await decode(tester, extent: 100, fit: BoxFit.fill), 400);
      expect(await decode(tester, extent: 100, fit: BoxFit.fitHeight), 400);
    });

    testWidgets('uses the screen width without an extent', (tester) async {
      expect(await decode(tester, fit: BoxFit.contain), 800);
    });

    testWidgets('caps at 2048 pixels', (tester) async {
      expect(await decode(tester, extent: 900, fit: BoxFit.cover), 2048);
    });
  });

  group('openUIJsonText', () {
    test('prints a whole number in full without a decimal point', () {
      expect(openUIJsonText(42.0), '42');
      expect(openUIJsonText(1e20), '100000000000000000000');
    });

    test('does not clamp a number beyond the integer range', () {
      expect(openUIJsonText(1e300), isNot('9223372036854775807'));
    });
  });
}
