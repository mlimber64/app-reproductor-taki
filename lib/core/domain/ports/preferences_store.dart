/// Small key/value store for the app's own settings (equalizer, ...).
///
/// Values are opaque text: whoever owns a key decides its format. Keys are
/// namespaced by their owner (`equalizer`, ...).
///
/// Contract:
/// - [read] returns `null` when the key was never written.
/// - [write] replaces the value.
/// - Both may fail (e.g. the database could not be opened); callers treat the
///   store as best effort and keep working with their defaults.
abstract interface class PreferencesStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);
}
