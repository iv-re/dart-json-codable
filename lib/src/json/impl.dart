part of 'json.dart';

const ValidationError _requiredError = ValidationError.required();
const ValidationError _dateTimeError = ValidationError(code: 'date_time');
const ValidationError _urlError = ValidationError(code: 'url');

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
  const _JsonObjectImpl(this._reader, [this._ctx]);

  factory _JsonObjectImpl.fromString(String src) {
    return _JsonObjectImpl(
      JsonReader(Uint8List.fromList(utf8.encode(src))),
    );
  }

  factory _JsonObjectImpl.fromMap(Map<String, Object?> map) {
    return _JsonObjectImpl(JsonReader.fromMap(map));
  }

  final JsonReader _reader;
  final _ValidationContext? _ctx;

  @override
  @pragma('vm:prefer-inline')
  bool has(String key) => _reader.hasKey(key);

  @override
  JsonFieldExtractor get field => JsonFieldExtractor(this);

  @override
  @pragma('vm:prefer-inline')
  T parse<T>(T Function(JsonObject json) mapper) {
    final ctx = _ValidationContext();
    final json = _JsonObjectImpl(_reader, ctx);
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
    if (!_reader.hasKey(key) || _reader.isNull(key)) {
      return _handleError(
        key,
        _requiredError,
        fallback: mappers.values.first(const _DummyJsonObject()),
      );
    }
    late final String value;
    try {
      final r = _reader.readString(key);
      if (r == null) {
        return _handleError(
          key,
          _requiredError,
          fallback: mappers.values.first(const _DummyJsonObject()),
        );
      }
      value = r;
    } on JsonTypeMismatchException catch (e) {
      return _handleError(
        key,
        ValidationError.type(expected: 'string', actual: e.actual),
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
      final childJson = _JsonObjectImpl(_reader, childCtx);
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

    return mapper(_JsonObjectImpl(_reader));
  }

  @pragma('vm:prefer-inline')
  bool _isMissingOrNull(String key) {
    return !_reader.hasKey(key) || _reader.isNull(key);
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

  @pragma('vm:prefer-inline')
  V _readPrimitive<V, R>(
    String key, {
    required V? Function() read,
    required String expected,
    required V fallback,
    List<ValidationRule<R>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) {
      return _handleError(key, _requiredError, fallback: fallback);
    }
    late final V value;
    try {
      final res = read();
      if (res == null) {
        return _handleError(key, _requiredError, fallback: fallback);
      }
      value = res;
    } on JsonTypeMismatchException catch (e) {
      return _handleError(
        key,
        ValidationError.type(expected: expected, actual: e.actual),
        fallback: fallback,
      );
    }
    if (rules.isNotEmpty) {
      final failedRules = rules.evaluate(value as R);
      if (failedRules.isNotEmpty) {
        _handleErrors(key, failedRules);
      }
    }
    return value;
  }

  @override
  @pragma('vm:prefer-inline')
  Object any(String key) {
    if (_isMissingOrNull(key)) {
      return _handleError(key, _requiredError, fallback: const Object());
    }
    return _reader.readAny(key)!;
  }

  @override
  @pragma('vm:prefer-inline')
  Object? anyOrNull(String key) {
    if (_isMissingOrNull(key)) return null;
    return _reader.readAny(key);
  }

  @override
  @pragma('vm:prefer-inline')
  String string(String key, {List<ValidationRule<String>> rules = const []}) {
    return _readPrimitive<String, String>(
      key,
      read: () => _reader.readString(key),
      expected: 'string',
      fallback: '',
      rules: rules,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return string(key, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  int integer(String key, {List<ValidationRule<num>> rules = const []}) {
    return _readPrimitive<int, num>(
      key,
      read: () => _reader.readInt(key),
      expected: 'integer',
      fallback: 0,
      rules: rules,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  int? integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return integer(key, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  double float(String key, {List<ValidationRule<num>> rules = const []}) {
    return _readPrimitive<double, num>(
      key,
      read: () => _reader.readFloat(key),
      expected: 'float',
      fallback: 0,
      rules: rules,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  double? floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return float(key, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  bool boolean(String key) {
    return _readPrimitive<bool, bool>(
      key,
      read: () => _reader.readBool(key),
      expected: 'boolean',
      fallback: false,
    );
  }

  @override
  @pragma('vm:prefer-inline')
  bool? booleanOrNull(String key) {
    if (_isMissingOrNull(key)) return null;
    return boolean(key);
  }

  @override
  @pragma('vm:prefer-inline')
  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    final value = string(key);
    if (value.isEmpty && _ctx != null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
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

  @override
  @pragma('vm:prefer-inline')
  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return dateTime(key, rules: rules);
  }

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

  @override
  @pragma('vm:prefer-inline')
  DateTime? timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return timestamp(key, isSeconds: isSeconds, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  Uri uri(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    final value = string(key, rules: rules);
    if (value.isEmpty && _ctx != null) return Uri();
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

  @override
  @pragma('vm:prefer-inline')
  Uri? uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (_isMissingOrNull(key)) return null;
    return uri(key, rules: rules);
  }

  @override
  @pragma('vm:prefer-inline')
  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    final value = string(key);
    if (value.isEmpty && _ctx != null) return values.first;

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
    if (_isMissingOrNull(key)) return null;
    return enumeration<T>(key, values, by: by);
  }

  @override
  @pragma('vm:prefer-inline')
  T object<T>(String key, T Function(JsonObject json) mapper) {
    if (_isMissingOrNull(key)) {
      return _handleError(
        key,
        _requiredError,
        fallback: mapper(const _DummyJsonObject()),
      );
    }
    late final JsonReader childReader;
    try {
      final r = _reader.readObject(key);
      if (r == null) {
        return _handleError(
          key,
          _requiredError,
          fallback: mapper(const _DummyJsonObject()),
        );
      }
      childReader = r;
    } on JsonTypeMismatchException catch (e) {
      return _handleError(
        key,
        ValidationError.type(expected: 'object', actual: e.actual),
        fallback: mapper(const _DummyJsonObject()),
      );
    }

    final ctx = _ctx;
    if (ctx != null) {
      final childCtx = _ValidationContext();
      final childJson = _JsonObjectImpl(childReader, childCtx);
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
      return mapper(_JsonObjectImpl(childReader));
    } on ValidationErrors catch (e) {
      throw ValidationErrors()..addNested(key, ValidationErrorsObject(e));
    }
  }

  @override
  @pragma('vm:prefer-inline')
  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper) {
    if (_isMissingOrNull(key)) return null;
    return object<T>(key, mapper);
  }

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

    if (!_reader.hasKey(key) || _reader.isNull(key)) {
      return _handleError(key, _requiredError, fallback: <T>[]);
    }

    late final List<T> items;
    if (mapper != null) {
      late final List<JsonReader> rawList;
      try {
        final r = _reader.readList<JsonReader>(key);
        if (r == null) {
          return _handleError(key, _requiredError, fallback: <T>[]);
        }
        rawList = r;
      } on JsonTypeMismatchException catch (e) {
        return _handleError(
          key,
          ValidationError.type(expected: 'list', actual: e.actual),
          fallback: <T>[],
        );
      }

      final result = <T>[];
      final ctx = _ctx;
      for (var i = 0; i < rawList.length; i++) {
        final itemReader = rawList[i];
        final itemCtx = _ValidationContext();
        T? parsedItem;
        try {
          parsedItem = mapper(
            _JsonObjectImpl(itemReader, ctx != null ? itemCtx : null),
          );
        } on ValidationErrors catch (e) {
          if (ctx == null) {
            throw ValidationErrors()
              ..addNested(key, ValidationErrorsList({i: e}));
          }
        }
        if (itemCtx.errors.isNotEmpty) {
          ctx!.addNested(key, ValidationErrorsList({i: itemCtx.errors}));
        } else if (parsedItem != null) {
          result.add(parsedItem);
        }
      }
      items = result;
    } else {
      try {
        final r = _reader.readList<T>(key);
        if (r == null) {
          return _handleError(key, _requiredError, fallback: <T>[]);
        }
        items = r;
      } on JsonTypeMismatchException catch (e) {
        return _handleError(
          key,
          ValidationError.type(expected: 'list', actual: e.actual),
          fallback: <T>[],
        );
      }
    }

    if (rules.isNotEmpty) {
      for (final item in items) {
        final failedRules = rules.evaluate(item);
        if (failedRules.isNotEmpty) {
          _handleErrors(key, failedRules);
        }
      }
    }

    return items;
  }

  @override
  @pragma('vm:prefer-inline')
  List<T>? listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_reader.hasKey(key) || _reader.isNull(key)) return null;
    return list<T>(key, mapper: mapper, rules: rules);
  }

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

    if (!_reader.hasKey(key) || _reader.isNull(key)) {
      return _handleError(key, _requiredError, fallback: <String, T>{});
    }

    late final Map<String, T> rawMap;
    try {
      if (mapper != null) {
        final r = _reader.readMap<JsonReader>(key);
        if (r == null) {
          return _handleError(key, _requiredError, fallback: <String, T>{});
        }

        final result = <String, T>{};
        final mapCtx = _ValidationContext();
        for (final entry in r.entries) {
          final childKey = entry.key;
          final itemCtx = _ValidationContext();
          T? parsedItem;
          try {
            parsedItem = mapper(
              _JsonObjectImpl(entry.value, _ctx != null ? itemCtx : null),
            );
          } on ValidationErrors catch (e) {
            if (_ctx == null) {
              final errs = ValidationErrors()
                ..addNested(childKey, ValidationErrorsObject(e));
              throw ValidationErrors()
                ..addNested(key, ValidationErrorsObject(errs));
            }
          }
          if (itemCtx.errors.isNotEmpty) {
            mapCtx.addNested(childKey, ValidationErrorsObject(itemCtx.errors));
          } else if (parsedItem != null) {
            result[childKey] = parsedItem;
          }
        }
        if (mapCtx.errors.isNotEmpty) {
          final ctx = _ctx;
          if (ctx != null) {
            ctx.addNested(key, ValidationErrorsObject(mapCtx.errors));
          } else {
            throw ValidationErrors()
              ..addNested(key, ValidationErrorsObject(mapCtx.errors));
          }
        }
        rawMap = result;
      } else {
        final r = _reader.readMap<T>(key);
        if (r == null) {
          return _handleError(key, _requiredError, fallback: <String, T>{});
        }
        rawMap = r;
      }
    } on JsonTypeMismatchException catch (e) {
      if (e.key == key) {
        return _handleError(
          key,
          ValidationError.type(expected: 'map', actual: e.actual),
          fallback: <String, T>{},
        );
      }
      final mapCtx = _ValidationContext();
      mapCtx.addError(
        e.key,
        ValidationError.type(expected: e.expected, actual: e.actual),
      );
      final ctx = _ctx;
      if (ctx != null) {
        ctx.addNested(key, ValidationErrorsObject(mapCtx.errors));
      } else {
        throw ValidationErrors()
          ..addNested(key, ValidationErrorsObject(mapCtx.errors));
      }
      return <String, T>{};
    }

    if (rules.isNotEmpty) {
      final result = <String, T>{};
      final mapCtx = _ValidationContext();
      for (final entry in rawMap.entries) {
        final failedRules = rules.evaluate(entry.value);
        if (failedRules.isNotEmpty) {
          mapCtx.addErrors(entry.key, failedRules);
        } else {
          result[entry.key] = entry.value;
        }
      }
      if (mapCtx.errors.isNotEmpty) {
        final ctx = _ctx;
        if (ctx != null) {
          ctx.addNested(key, ValidationErrorsObject(mapCtx.errors));
        } else {
          throw ValidationErrors()
            ..addNested(key, ValidationErrorsObject(mapCtx.errors));
        }
      }
      return result;
    }

    return rawMap;
  }

  @override
  @pragma('vm:prefer-inline')
  Map<String, T>? mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    if (!_reader.hasKey(key) || _reader.isNull(key)) return null;
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
