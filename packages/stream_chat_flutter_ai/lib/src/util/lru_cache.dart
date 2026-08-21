/// A fixed-capacity cache that evicts the *least recently used* entry.
///
/// Internal to this package, and deliberately minimal: [get], [set] and
/// [clear] are all anything here needs.
///
/// Recency rather than insertion order is the whole point. A plain
/// `Map` evicting `keys.first` — its oldest *insertion* — is the wrong policy
/// for anything keyed on streamed content, because a value that is still
/// arriving produces a brand-new key on every tick: within a few hundred
/// milliseconds those throwaway snapshots fill the cache and the entries being
/// evicted to make room for them are the finished ones still on screen, which
/// are exactly the entries the cache exists to keep. Touching an entry on
/// every hit inverts that — a snapshot is never looked up twice, so it ages out
/// on its own while anything still being read stays resident.
class LruCache<K, V> {
  /// Creates a cache holding at most [capacity] entries.
  LruCache(this.capacity) : assert(capacity > 0, 'capacity must be at least 1');

  /// The most entries held at once. Adding past this evicts the least
  /// recently used.
  final int capacity;

  /// Iteration order is insertion order, which — because [get] re-inserts what
  /// it finds — makes `keys.first` the least recently used entry.
  final _entries = <K, V>{};

  /// Whether [key] has a cached value, including a cached `null`.
  bool containsKey(K key) => _entries.containsKey(key);

  /// The value cached for [key], marking it as most recently used, or `null`
  /// if there is none.
  ///
  /// A cached `null` is indistinguishable from a miss here; use [containsKey]
  /// where that matters.
  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  /// Caches [value] under [key] as the most recently used entry, and returns
  /// it for convenient use in an expression.
  V set(K key, V value) {
    // Removed first so that overwriting an existing key re-inserts it at the
    // most-recent end rather than leaving it where it was.
    _entries.remove(key);
    if (_entries.length >= capacity) _entries.remove(_entries.keys.first);
    _entries[key] = value;
    return value;
  }

  /// Drops every entry.
  void clear() => _entries.clear();

  /// The keys held, least recently used first. Exposed for tests.
  Iterable<K> get debugKeys => _entries.keys;
}
