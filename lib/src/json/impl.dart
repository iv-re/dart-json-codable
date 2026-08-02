part of 'json.dart';

const _requiredError = ValidationError(code: 'required');
const _dateTimeError = ValidationError(code: 'date_time');
const _urlError = ValidationError(code: 'url');

class _ValidationContext {
  final ValidationErrors errors = ValidationErrors();

  @pragma('vm:prefer-inline')
  void addError(String field, ValidationError error) {
    errors.add(field, error);
  }

  @pragma('vm:prefer-inline')
  void addErrors(String field, List<ValidationError> errorList) {
    for (final err in errorList) {
      errors.add(field, err);
    }
  }

  @pragma('vm:prefer-inline')
  void addNested(String field, ValidationErrorsKind kind) {
    errors.addNested(field, kind);
  }
}

class _JsonObjectImpl implements JsonObject {
  /// Creates a [JsonObject] wrapping the provided [_map].
  const _JsonObjectImpl(this._map) : _ctx = null;
  const _JsonObjectImpl._(this._map, this._ctx);

  final Map<String, Object?> _map;
  final _ValidationContext? _ctx;

  /// Checks if the JSON object contains the specified [key].
  ///
  /// This is useful for distinguishing between a field being entirely absent
  /// and a field being explicitly set to `null` (e.g., in PATCH requests).
  @override
  @pragma('vm:prefer-inline')
  bool has(String key) => _map.containsKey(key);

  /// Returns an extractor for parsing fields into [JsonField] wrappers.
  ///
  /// This is particularly useful for PATCH requests where you need to
  /// differentiate between an absent field and one explicitly set to `null`.
  @override
  JsonFieldExtractor get field => JsonFieldExtractor(this);

  /// Parses an instance of [JsonObject] using [mapper] while accumulating
  /// ALL field errors. Throws a unified [ValidationErrors] if any errors
  /// were collected.
  @override
  @pragma('vm:prefer-inline')
  T parse<T>(T Function(JsonObject json) mapper) {
    final ctx = _ValidationContext();
    final json = _JsonObjectImpl._(_map, ctx);
    final result = mapper(json);
    if (ctx.errors.isNotEmpty) {
      throw ctx.errors;
    }
    return result;
  }

  @override
  @pragma('vm:prefer-inline')
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    final value = _map[key];
    if (value == null) {
      return _handleError(
        key,
        _requiredError,
        fallback: mappers.values.first(const _DummyJsonObject()),
      );
    }
    if (value is! String) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: value),
        fallback: mappers.values.first(const _DummyJsonObject()),
      );
    }

    final mapper = mappers[value];
    if (mapper == null) {
      return _handleError(
        key,
        ValidationError(
          code: 'invalid_discriminator',
          params: {'expected': mappers.keys.toList()},
        ),
        fallback: mappers.values.first(const _DummyJsonObject()),
      );
    }

    final ctx = _ctx;
    if (ctx != null) {
      final childCtx = _ValidationContext();
      final childJson = _JsonObjectImpl._(_map, childCtx);
      late final T res;
      try {
        res = mapper(childJson);
      } on ValidationErrors {
        res = mapper(const _DummyJsonObject());
      }
      if (childCtx.errors.isNotEmpty) {
        ctx.errors.errors.addAll(childCtx.errors.errors);
      }
      return res;
    }

    return mapper(_JsonObjectImpl(_map));
  }

  @pragma('vm:prefer-inline')
  T _handleError<T>(String key, ValidationError error, {required T fallback}) {
    final ctx = _ctx;
    if (ctx != null) {
      ctx.addError(key, error);
      return fallback;
    }
    throw ValidationErrors()..add(key, error);
  }

  @pragma('vm:prefer-inline')
  void _handleErrors(String key, List<ValidationError> errors) {
    final ctx = _ctx;
    if (ctx != null) {
      ctx.addErrors(key, errors);
      return;
    }
    final container = ValidationErrors();
    for (final err in errors) {
      container.add(key, err);
    }
    throw container;
  }

  /// Extracts a required raw/untyped field by [key].
  @override
  @pragma('vm:prefer-inline')
  Object any(String key) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: const Object());
    }
    return value;
  }

  /// Extracts an optional raw/untyped field by [key].
  @override
  @pragma('vm:prefer-inline')
  Object? anyOrNull(String key) {
    return _map[key];
  }

  /// Extracts a required [String] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  String string(String key, {List<ValidationRule<String>> rules = const []}) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: '');
    }
    if (value is! String) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: value),
        fallback: '',
      );
    }
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(value);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return value;
  }

  /// Extracts an optional [String] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return string(key, rules: rules);
  }

  /// Extracts a required [int] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  int integer(String key, {List<ValidationRule<num>> rules = const []}) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: 0);
    }
    if (value is! int) {
      return _handleError(
        key,
        ValidationError.type(expected: 'integer', actual: value),
        fallback: 0,
      );
    }
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(value);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return value;
  }

  /// Extracts an optional [int] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  int? integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return integer(key, rules: rules);
  }

  /// Extracts a required [double] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  double float(String key, {List<ValidationRule<num>> rules = const []}) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: 0);
    }
    if (value is! num) {
      return _handleError(
        key,
        ValidationError.type(expected: 'float', actual: value),
        fallback: 0,
      );
    }
    final doubleVal = value.toDouble();
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(doubleVal);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return doubleVal;
  }

  /// Extracts an optional [double] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  double? floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return float(key, rules: rules);
  }

  /// Extracts a required [bool] field by [key].
  @override
  @pragma('vm:prefer-inline')
  bool boolean(String key) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: false);
    }
    if (value is! bool) {
      return _handleError(
        key,
        ValidationError.type(expected: 'boolean', actual: value),
        fallback: false,
      );
    }
    return value;
  }

  /// Extracts an optional [bool] field by [key].
  @override
  @pragma('vm:prefer-inline')
  bool? booleanOrNull(String key) {
    if (_map[key] == null) return null;
    return boolean(key);
  }

  /// Extracts a required ISO 8601 formatted [DateTime] field by [key] and
  /// optionally validates it with [rules].
  @override
  @pragma('vm:prefer-inline')
  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    final value = _map[key];
    if (value == null) {
      return _handleError(
        key,
        _requiredError,
        fallback: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    if (value is! String) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: value),
        fallback: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    final dt = DateTime.tryParse(value);
    if (dt == null) {
      return _handleError(
        key,
        _dateTimeError,
        fallback: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(dt);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return dt;
  }

  /// Extracts an optional ISO 8601 formatted [DateTime] field by [key] and
  /// optionally validates it with [rules].
  @override
  @pragma('vm:prefer-inline')
  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return dateTime(key, rules: rules);
  }

  /// Extracts a required Unix timestamp field by [key] and converts it to
  /// [DateTime].
  ///
  /// Set [isSeconds] to `true` for epoch seconds (default is epoch ms).
  @override
  @pragma('vm:prefer-inline')
  DateTime timestamp(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    final val = integer(key);
    final dt = isSeconds
        ? DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(val, isUtc: true);
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(dt);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return dt;
  }

  /// Extracts an optional Unix timestamp field by [key] and converts it to
  /// [DateTime].
  ///
  /// Set [isSeconds] to `true` for epoch seconds (default is epoch ms).
  @override
  @pragma('vm:prefer-inline')
  DateTime? timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return timestamp(key, isSeconds: isSeconds, rules: rules);
  }

  /// Extracts a required [Uri] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  Uri uri(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    final value = _map[key];
    if (value == null) {
      return _handleError(
        key,
        _requiredError,
        fallback: Uri(),
      );
    }
    if (value is! String) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: value),
        fallback: Uri(),
      );
    }
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(value);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    final parsed = Uri.tryParse(value);
    if (parsed == null || !parsed.hasScheme || parsed.scheme.isEmpty) {
      return _handleError(
        key,
        _urlError,
        fallback: Uri(),
      );
    }
    return parsed;
  }

  /// Extracts an optional [Uri] field by [key] and optionally validates it
  /// with [rules].
  @override
  @pragma('vm:prefer-inline')
  Uri? uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return uri(key, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: values.first);
    }
    if (value is! String) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: value),
        fallback: values.first,
      );
    }

    for (final e in values) {
      if ((by?.call(e) ?? e.name) == value) {
        return e;
      }
    }

    return _handleError(
      key,
      ValidationError(
        code: 'invalid_enum',
        params: {'expected': values.map((e) => by?.call(e) ?? e.name).toList()},
      ),
      fallback: values.first,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    if (_map[key] == null) return null;
    return enumeration<T>(key, values, by: by);
  }

  /// Extracts a required nested object field by [key] and parses it using
  /// [mapper].
  @override
  @pragma('vm:prefer-inline')
  T object<T>(String key, T Function(JsonObject json) mapper) {
    final value = _map[key];
    if (value == null) {
      return _handleError(
        key,
        _requiredError,
        fallback: mapper(const _DummyJsonObject()),
      );
    }
    if (value is! Map<String, Object?>) {
      return _handleError(
        key,
        ValidationError.type(expected: 'object', actual: value),
        fallback: mapper(const _DummyJsonObject()),
      );
    }
    final ctx = _ctx;
    if (ctx != null) {
      final childCtx = _ValidationContext();
      final childJson = _JsonObjectImpl._(value, childCtx);
      late final T res;
      try {
        res = mapper(childJson);
      } on ValidationErrors {
        res = mapper(const _DummyJsonObject());
      }
      if (childCtx.errors.isNotEmpty) {
        ctx.addNested(key, ValidationErrorsObject(childCtx.errors));
      }
      return res;
    }

    try {
      return mapper(_JsonObjectImpl(value));
    } on ValidationErrors catch (e) {
      throw ValidationErrors()..addNested(key, ValidationErrorsObject(e));
    }
  }

  /// Extracts an optional nested object field by [key] and parses it using
  /// [mapper].
  @override
  @pragma('vm:prefer-inline')
  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper) {
    if (_map[key] == null) return null;
    return object<T>(key, mapper);
  }

  /// Extracts a required [List] field by [key], mapping elements with [mapper]
  /// if non-primitive, and validating elements against [rules].
  @override
  @pragma('vm:prefer-inline')
  List<T> list<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    assert(
      mapper != null || _isPrimitiveType<T>(),
      'a mapper function T Function(JsonObject json) must be provided '
      'for non-primitive list type $T',
    );
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: <T>[]);
    }
    if (value is! List) {
      return _handleError(
        key,
        .type(expected: 'list', actual: value),
        fallback: <T>[],
      );
    }

    final result = <T>[];
    final ctx = _ctx;
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      T? parsedItem;
      if (mapper != null) {
        if (item is! Map<String, Object?>) {
          _handleError(
            key,
            ValidationError.type(expected: 'object', actual: item),
            fallback: null,
          );
          continue;
        }
        if (ctx != null) {
          final itemCtx = _ValidationContext();
          final itemJson = _JsonObjectImpl._(item, itemCtx);
          try {
            parsedItem = mapper(itemJson);
          } on ValidationErrors {
            parsedItem = null;
          }
          if (itemCtx.errors.isNotEmpty) {
            ctx.addNested(key, ValidationErrorsList({i: itemCtx.errors}));
            parsedItem = null;
          }
        } else {
          try {
            parsedItem = mapper(_JsonObjectImpl(item));
          } on ValidationErrors catch (e) {
            throw ValidationErrors()
              ..addNested(key, ValidationErrorsList({i: e}));
          }
        }
      } else {
        if (item is! T) {
          _handleError(
            key,
            ValidationError.type(
              expected: T.toString().toLowerCase(),
              actual: item,
            ),
            fallback: null,
          );
          continue;
        }
        parsedItem = item;
      }

      if (parsedItem != null) {
        if (rules.isNotEmpty) {
          final failedRules = rules.evaluate(parsedItem);
          if (failedRules.isNotEmpty) {
            _handleErrors(key, failedRules);
          }
        }
        result.add(parsedItem);
      }
    }
    return result;
  }

  /// Extracts an optional [List] field by [key], mapping elements with [mapper]
  /// if non-primitive, and validating elements against [rules].
  @override
  @pragma('vm:prefer-inline')
  List<T>? listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return list<T>(key, mapper: mapper, rules: rules);
  }

  /// Extracts a required [Map] field by [key] with string keys and values of
  /// type [T].
  ///
  /// If [T] is non-primitive, a [mapper] must be provided.
  @override
  @pragma('vm:prefer-inline')
  Map<String, T> map<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    assert(
      mapper != null || _isPrimitiveType<T>(),
      'a mapper function T Function(JsonObject json) must be provided '
      'for non-primitive map type $T',
    );
    final value = _map[key];
    if (value == null) {
      return _handleError(key, _requiredError, fallback: <String, T>{});
    }
    if (value is! Map<String, Object?>) {
      return _handleError(
        key,
        ValidationError.type(expected: 'map', actual: value),
        fallback: <String, T>{},
      );
    }

    final result = <String, T>{};
    final ctx = _ctx;
    final mapCtx = _ValidationContext();

    for (final entry in value.entries) {
      final childKey = entry.key;
      final childValue = entry.value;
      T? parsedItem;

      if (mapper != null) {
        if (childValue is! Map<String, Object?>) {
          mapCtx.addError(
            childKey,
            ValidationError.type(expected: 'object', actual: childValue),
          );
          continue;
        }

        final itemCtx = _ValidationContext();
        final itemJson = _JsonObjectImpl._(childValue, itemCtx);
        try {
          parsedItem = mapper(itemJson);
        } on ValidationErrors {
          parsedItem = null;
        }
        if (itemCtx.errors.isNotEmpty) {
          mapCtx.addNested(childKey, ValidationErrorsObject(itemCtx.errors));
          parsedItem = null;
        }
      } else {
        if (childValue is! T) {
          mapCtx.addError(
            childKey,
            ValidationError.type(
              expected: T.toString().toLowerCase(),
              actual: childValue,
            ),
          );
          continue;
        }
        parsedItem = childValue;
      }

      if (parsedItem != null) {
        if (rules.isNotEmpty) {
          final failedRules = rules.evaluate(parsedItem);
          if (failedRules.isNotEmpty) {
            mapCtx.addErrors(childKey, failedRules);
          } else {
            result[childKey] = parsedItem;
          }
        } else {
          result[childKey] = parsedItem;
        }
      }
    }

    if (mapCtx.errors.isNotEmpty) {
      if (ctx != null) {
        ctx.addNested(key, ValidationErrorsObject(mapCtx.errors));
      } else {
        throw ValidationErrors()
          ..addNested(key, ValidationErrorsObject(mapCtx.errors));
      }
    }

    return result;
  }

  /// Extracts an optional [Map] field by [key] with string keys and values of
  /// type [T].
  ///
  /// If [T] is non-primitive, a [mapper] must be provided.
  @override
  @pragma('vm:prefer-inline')
  Map<String, T>? mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (_map[key] == null) return null;
    return map<T>(key, mapper: mapper, rules: rules);
  }
}

bool _isPrimitiveType<T>() =>
    T == String ||
    T == int ||
    T == double ||
    T == num ||
    T == bool ||
    T == Object ||
    T == dynamic;
