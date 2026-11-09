import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai_a2ui/src/surface/a2ui_surface_scope.dart';

// What a component's media loads from, given the URL the agent wrote.
void main() {
  test('a missing URL loads nothing, without asking the media function', () {
    final asked = <Uri>[];

    final source = a2uiMediaSourceOf(null, _recording(asked));

    expect((source: source, asked: asked.length), (source: null, asked: 0));
  });

  test('an empty URL loads nothing, without asking the media function', () {
    final asked = <Uri>[];

    final source = a2uiMediaSourceOf('', _recording(asked));

    expect((source: source, asked: asked.length), (source: null, asked: 0));
  });

  test('a URL without a scheme loads nothing, without asking the media function', () {
    final asked = <Uri>[];

    final source = a2uiMediaSourceOf('clip.mp4', _recording(asked));

    expect((source: source, asked: asked.length), (source: null, asked: 0));
  });

  test('a URL that does not parse loads nothing, without asking the media function', () {
    final asked = <Uri>[];

    final source = a2uiMediaSourceOf('http://[', _recording(asked));

    expect((source: source, asked: asked.length), (source: null, asked: 0));
  });

  test('a URL with a scheme loads from what the media function gives', () {
    final source = a2uiMediaSourceOf('https://example.com/clip.mp4', (url) => url.replace(host: 'proxy.example.com'));

    expect(source, Uri.parse('https://proxy.example.com/clip.mp4'));
  });

  test('a URL the media function refuses loads nothing', () {
    final source = a2uiMediaSourceOf('https://example.com/clip.mp4', (url) => null);

    expect(source, isNull);
  });
}

// A media function that lets every URL through and records it in [asked].
A2UIMediaUrl _recording(List<Uri> asked) {
  return (url) {
    asked.add(url);
    return url;
  };
}
