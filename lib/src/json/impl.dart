part of 'json.dart';

const _requiredError = ValidationError(code: 'required');
const _dateTimeError = ValidationError(code: 'date_time');
const _urlError = ValidationError(code: 'url');

/// Errors collected while parsing one value.
///
/// A fail-fast session throws its errors as soon as the first one is added.
final class _Session {
  _Session({required this.failFast});

  final bool failFast;
  final ValidationErrors errors = ValidationErrors();
  int _count = 0;

  /// Number of errors added so far.
  int get count => _count;

  void add(String path, List<ValidationError> list) {
    if (list.isEmpty) return;
    errors.addAll(path, list);
    _count += list.length;
    if (failFast) throw errors;
  }

  void merge(ValidationErrors other, String path) {
    for (final MapEntry(:key, :value) in other.errors.entries) {
      add(_join(path, key), value);
    }
  }
}

/// Thrown by [JsonReader.fail] and caught by the field being decoded.
final class _Rejected implements Exception {
  const _Rejected(this.error);

  final ValidationError error;
}

/// Thrown when a failed field has no placeholder. The enclosing field catches
/// it and returns its own placeholder instead.
final class _Aborted implements Exception {
  const _Aborted();
}

String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

/// Decodes [raw], the value at [path], with [type].
///
/// Records failures in [session] and returns the placeholder of [type] for
/// them.
T _decode<T>(
  _Session session,
  String path,
  JsonSource source,
  Object? raw,
  JsonType<T> type,
) {
  final value = source == .text && raw == '' && type.emptyIsAbsent ? null : raw;
  if (value == null) {
    if (type is _NullableType) return null as T;
    session.add(path, const [_requiredError]);
  } else {
    try {
      return type.decode(value, _Reader(session, path, source));
    } on _Rejected catch (e) {
      session.add(path, [e.error]);
    } on _Aborted {
      // The errors are already recorded at nested paths.
    }
  }
  try {
    return type.placeholder();
  } on Object {
    throw const _Aborted();
  }
}

/// Runs [mapper], a mapper over the object at [path].
///
/// Once fields inside the mapper have failed, anything the mapper throws comes
/// from the placeholders those fields returned, so it becomes [_Aborted].
T _guard<T>(_Session session, String path, T Function() mapper) {
  final before = session.count;
  try {
    return mapper();
  } on _Aborted {
    rethrow;
  } on ValidationErrors catch (e) {
    if (identical(e, session.errors)) rethrow;
    session.merge(e, path);
    throw const _Aborted();
  } on Object {
    if (session.count == before) rethrow;
    throw const _Aborted();
  }
}

final class _Reader implements JsonReader {
  _Reader(this._session, this._path, this.source);

  final _Session _session;
  final String _path;

  @override
  final JsonSource source;

  @override
  Never fail(ValidationError error) => throw _Rejected(error);

  @override
  void report(List<ValidationError> errors) => _session.add(_path, errors);

  @override
  T child<T>(String segment, Object? value, JsonType<T> type) =>
      _decode(_session, _join(_path, segment), source, value, type);

  @override
  T object<T>(Map<String, Object?> map, T Function(JsonObject json) mapper) {
    final json = _JsonObjectImpl._(map, _session, _path, source);
    return _guard(_session, _path, () => mapper(json));
  }
}

class _JsonObjectImpl with _JsonGetters implements JsonObject {
  /// Creates a [JsonObject] wrapping the provided [_map].
  const _JsonObjectImpl(this._map, {this._source = .json})
    : _session = null,
      _path = '';

  const _JsonObjectImpl._(this._map, this._session, this._path, this._source);

  final Map<String, Object?> _map;
  final JsonSource _source;

  /// The session this object is parsed in, or `null` for fail-fast reads.
  final _Session? _session;

  /// Path of this object in the parsed value, the prefix of its errors.
  final String _path;

  _Session get _activeSession => _session ?? _Session(failFast: true);

  /// Returns the top-level keys present in the JSON object.
  @override
  Iterable<String> get keys => _map.keys;

  /// Checks if the JSON object contains the specified [key].
  ///
  /// This is useful for distinguishing between a field being entirely absent
  /// and a field being explicitly set to `null` (e.g., in PATCH requests).
  @override
  bool has(String key) => _map.containsKey(key);

  /// Parses an instance of [JsonObject] using [mapper] while accumulating
  /// ALL field errors. Throws a unified [ValidationErrors] if any errors
  /// were collected.
  ///
  /// Inside another mapper, runs [mapper] as part of the enclosing parse.
  @override
  T parse<T>(T Function(JsonObject json) mapper) {
    if (_session != null) return mapper(this);

    final session = _Session(failFast: false);
    final json = _JsonObjectImpl._(_map, session, '', _source);
    final T result;
    try {
      result = _guard(session, '', () => mapper(json));
    } on _Aborted {
      throw session.errors;
    }
    if (session.errors.isNotEmpty) throw session.errors;
    return result;
  }

  @override
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    final session = _activeSession;
    final before = session.count;
    final tag = _decode(
      session,
      _join(_path, key),
      _source,
      _map[key],
      _DiscriminatorType(mappers.keys),
    );
    if (session.count > before) {
      try {
        return mappers.values.first(const _DummyJsonObject());
      } on Object {
        throw const _Aborted();
      }
    }
    final json = _JsonObjectImpl._(_map, session, _path, _source);
    return _guard(session, _path, () => mappers[tag]!(json));
  }

  @override
  T read<T>(String key, JsonType<T> type) =>
      _decode(_activeSession, _join(_path, key), _source, _map[key], type);

  @override
  T? readOrNull<T>(String key, JsonType<T> type) {
    final value = _map[key];
    if (value == null) return null;
    if (_source == .text && value == '' && type.emptyIsAbsent) return null;
    return read(key, type);
  }
}
