import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat_flutter_ai/src/util/lru_cache.dart';

void main() {
  group('LruCache', () {
    test('returns what was cached, and null for a key never seen', () {
      final cache = LruCache<String, int>(2)..set('a', 1);

      expect(cache.get('a'), 1);
      expect(cache.get('b'), isNull);
      expect(cache.containsKey('b'), isFalse);
    });

    test('holds a cached null, distinguishably from a miss', () {
      final cache = LruCache<String, int?>(2)..set('a', null);

      expect(cache.get('a'), isNull);
      expect(cache.containsKey('a'), isTrue);
    });

    test('evicts the least recently used entry, not the oldest insertion', () {
      final cache = LruCache<String, int>(2)
        ..set('a', 1)
        ..set('b', 2);

      // Reading 'a' makes 'b' the eviction candidate even though 'a' went in
      // first — the whole point of the cache.
      expect(cache.get('a'), 1);
      cache.set('c', 3);

      expect(cache.containsKey('a'), isTrue);
      expect(cache.containsKey('b'), isFalse);
      expect(cache.containsKey('c'), isTrue);
    });

    test('a stream of one-shot keys leaves a repeatedly read entry alone', () {
      // A fence still arriving keys a new entry per typewriter tick while the
      // finished fence above it is read on every one of them.
      final cache = LruCache<String, int>(4)..set('kept', 0);

      for (var i = 0; i < 50; i++) {
        expect(cache.get('kept'), 0);
        cache.set('partial-$i', i);
      }

      expect(cache.containsKey('kept'), isTrue);
      expect(cache.debugKeys.length, 4);
    });

    test('overwriting a key refreshes its recency', () {
      final cache = LruCache<String, int>(2)
        ..set('a', 1)
        ..set('b', 2)
        ..set('a', 3)
        ..set('c', 4);

      expect(cache.get('a'), 3);
      expect(cache.containsKey('b'), isFalse);
    });

    test('never grows past its capacity', () {
      final cache = LruCache<int, int>(3);
      for (var i = 0; i < 20; i++) {
        cache.set(i, i);
      }

      expect(cache.debugKeys, [17, 18, 19]);
    });

    test('clear drops everything', () {
      final cache = LruCache<String, int>(2)
        ..set('a', 1)
        ..clear();

      expect(cache.containsKey('a'), isFalse);
      expect(cache.debugKeys, isEmpty);
    });

    test('peek returns the value without touching recency', () {
      final cache = LruCache<String, int>(2)
        ..set('a', 1)
        ..set('b', 2);

      // `get` would promote 'a' and evict 'b' instead. Readers that aren't
      // really uses — a `build` deriving something from the cache — must not
      // reorder it, or recency ends up tracking paint order.
      expect(cache.peek('a'), 1);
      cache.set('c', 3);

      expect(cache.debugKeys, ['b', 'c']);
      expect(cache.peek('missing'), isNull);
    });
  });
}
