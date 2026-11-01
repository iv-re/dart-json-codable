part of 'json.dart';

/// A stand-in object that mappers run on to build placeholder values.
class _DummyJsonObject with _JsonGetters implements JsonObject {
  const _DummyJsonObject();

  @override
  Iterable<String> get keys => const [];

  @override
  bool has(String key) => false;

  @override
  T parse<T>(T Function(JsonObject json) mapper) => mapper(this);

  @override
  T read<T>(String key, JsonType<T> type) => type.placeholder();

  @override
  T? readOrNull<T>(String key, JsonType<T> type) => null;

  @override
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    assert(mappers.isNotEmpty, 'mappers must not be empty');
    return mappers.values.first(const _DummyJsonObject());
  }
}
