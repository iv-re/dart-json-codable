part of 'json.dart';

/// Where the values of a [JsonObject] come from.
enum JsonSource {
  /// Decoded JSON. Values must already have the requested type.
  json,

  /// Text values such as query parameters, form fields or headers.
  ///
  /// Strings are converted to the requested type on read, an empty string
  /// counts as absent for every type except string, and a single value is
  /// accepted where a list is expected.
  text,
}

/// Decoding state passed to [JsonType.decode].
abstract interface class JsonReader {
  /// Where the value being decoded comes from.
  JsonSource get source;

  /// Rejects the value being decoded with [error].
  ///
  /// The field gets [error] and its read returns [JsonType.placeholder].
  Never fail(ValidationError error);

  /// Records [errors] for the value being decoded without rejecting it.
  void report(List<ValidationError> errors);

  /// Decodes [value] with [type] as the child [segment] of the field being
  /// decoded, such as a list index or a map key.
  T child<T>(String segment, Object? value, JsonType<T> type);

  /// Runs [mapper] over [map] as the object of the field being decoded.
  T object<T>(Map<String, Object?> map, T Function(JsonObject json) mapper);
}

/// Describes how a field is decoded, validated and described in a schema.
///
/// [JsonObject] getters are built on these types. [where] and [convert]
/// derive new types, so a custom type gets validation errors, schema
/// generation and [JsonObject.field] support like the built-in ones:
///
/// ```dart
/// final userId = JsonType.string.convert(
///   (value, reader) =>
///       UserId.tryParse(value) ?? reader.fail(const .new(code: 'user_id')),
///   placeholder: UserId.empty,
///   schema: Schema.string(format: 'uuid'),
/// );
///
/// final id = json.read('id', userId);
/// ```
abstract class JsonType<T> {
  const JsonType();

  /// Any non-null value, unchanged.
  static const JsonType<Object> any = _AnyType();

  /// A string.
  static const JsonType<String> string = _StringType();

  /// An integer.
  static const JsonType<core.int> int = _IntType();

  /// A number, converted to [double].
  static const JsonType<core.double> double = _DoubleType();

  /// A number, kept as [int] or [double].
  static const JsonType<core.num> num = _NumType();

  /// A boolean.
  static const JsonType<core.bool> bool = _BoolType();

  /// An ISO 8601 date-time string.
  static const JsonType<DateTime> dateTime = _DateTimeType();

  /// An absolute URI string.
  static const JsonType<Uri> uri = _UriType();

  /// A Unix timestamp in milliseconds, or in seconds if [isSeconds] is `true`.
  static JsonType<DateTime> timestamp({core.bool isSeconds = false}) =>
      _TimestampType(isSeconds: isSeconds);

  /// One of [values], matched by their name or by [by].
  static JsonType<E> enumeration<E extends Enum>(
    Iterable<E> values, {
    String Function(E value)? by,
  }) => _EnumType(values, by);

  /// A nested object parsed with [mapper].
  static JsonType<E> object<E>(E Function(JsonObject json) mapper) =>
      _ObjectType(mapper);

  /// An object parsed with the mapper that the string at [key] selects from
  /// [mappers]. See [JsonObject.discriminated].
  static JsonType<E> discriminated<E>(
    String key,
    Map<String, E Function(JsonObject json)> mappers,
  ) => _ObjectType((json) => json.discriminated(key, mappers));

  /// A list whose items are [items].
  static JsonType<List<E>> list<E>(JsonType<E> items) => _ListType(items);

  /// An object whose values are [values].
  static JsonType<Map<String, E>> map<E>(JsonType<E> values) =>
      _MapType(values);

  /// Converts a non-null [value] to [T].
  ///
  /// Calls [JsonReader.fail] to reject [value].
  T decode(Object value, JsonReader reader);

  /// The value a failed read returns, so that the mapper can go on and collect
  /// the errors of the remaining fields.
  ///
  /// May throw when there is no such value. The failure then moves up to the
  /// enclosing field.
  T placeholder();

  /// JSON Schema of the values this type accepts.
  Schema schema();

  /// Whether an empty string from a [JsonSource.text] source counts as absent.
  core.bool get emptyIsAbsent => true;

  /// This type, also accepting `null`.
  JsonType<T?> get orNull => _NullableType(this);

  /// This type, converting decoded values with [convert].
  ///
  /// [convert] calls [JsonReader.fail] to reject a value. [schema] defaults to
  /// the schema of this type.
  JsonType<R> convert<R>(
    R Function(T value, JsonReader reader) convert, {
    required R placeholder,
    Schema? schema,
  }) => _ConvertedType(this, convert, placeholder, schema);
}

/// Adds validation rules to a [JsonType].
extension JsonTypeRules<T> on JsonType<T> {
  /// This type, validating decoded values with [rules].
  JsonType<T> where(List<ValidationRule<T>> rules) =>
      rules.isEmpty ? this : _RuledType(this, rules);
}

final _integerPattern = RegExp(r'^-?\d+$');
final _numberPattern = RegExp(r'^-?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?$');

final class _AnyType extends JsonType<Object> {
  const _AnyType();

  @override
  Object decode(Object value, JsonReader reader) => value;

  @override
  Object placeholder() => const Object();

  @override
  Schema schema() => Schema.any();

  @override
  bool get emptyIsAbsent => false;
}

final class _StringType extends JsonType<String> {
  const _StringType();

  @override
  String decode(Object value, JsonReader reader) {
    if (value is String) return value;
    reader.fail(.type(expected: 'string', actual: value));
  }

  @override
  String placeholder() => '';

  @override
  Schema schema() => Schema.string();

  @override
  bool get emptyIsAbsent => false;
}

final class _IntType extends JsonType<int> {
  const _IntType();

  @override
  int decode(Object value, JsonReader reader) {
    if (value is int) return value;
    if (reader.source == .text &&
        value is String &&
        _integerPattern.hasMatch(value)) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    reader.fail(.type(expected: 'integer', actual: value));
  }

  @override
  int placeholder() => 0;

  @override
  Schema schema() => Schema.integer();
}

final class _DoubleType extends JsonType<double> {
  const _DoubleType();

  @override
  double decode(Object value, JsonReader reader) =>
      _decodeNumber(value, reader).toDouble();

  @override
  double placeholder() => 0;

  @override
  Schema schema() => Schema.number();
}

final class _NumType extends JsonType<num> {
  const _NumType();

  @override
  num decode(Object value, JsonReader reader) => _decodeNumber(value, reader);

  @override
  num placeholder() => 0;

  @override
  Schema schema() => Schema.number();
}

num _decodeNumber(Object value, JsonReader reader) {
  if (value is num) return value;
  if (reader.source == .text &&
      value is String &&
      _numberPattern.hasMatch(value)) {
    return num.parse(value);
  }
  reader.fail(.type(expected: 'number', actual: value));
}

final class _BoolType extends JsonType<bool> {
  const _BoolType();

  @override
  bool decode(Object value, JsonReader reader) {
    if (value is bool) return value;
    if (reader.source == .text) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    reader.fail(.type(expected: 'boolean', actual: value));
  }

  @override
  bool placeholder() => false;

  @override
  Schema schema() => Schema.boolean();
}

final class _DateTimeType extends JsonType<DateTime> {
  const _DateTimeType();

  @override
  DateTime decode(Object value, JsonReader reader) {
    final string = JsonType.string.decode(value, reader);
    return DateTime.tryParse(string) ?? reader.fail(_dateTimeError);
  }

  @override
  DateTime placeholder() => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Schema schema() => Schema.string(format: 'date-time');
}

final class _TimestampType extends JsonType<DateTime> {
  const _TimestampType({required this.isSeconds});

  final bool isSeconds;

  @override
  DateTime decode(Object value, JsonReader reader) {
    final timestamp = JsonType.int.decode(value, reader);
    return DateTime.fromMillisecondsSinceEpoch(
      isSeconds ? timestamp * 1000 : timestamp,
      isUtc: true,
    );
  }

  @override
  DateTime placeholder() => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Schema schema() => Schema.integer();
}

final class _UriType extends JsonType<Uri> {
  const _UriType([this.rules = const []]);

  /// Rules for the URI string, checked before it is parsed.
  final List<ValidationRule<String>> rules;

  @override
  Uri decode(Object value, JsonReader reader) {
    final string = JsonType.string.decode(value, reader);
    if (rules.isNotEmpty) reader.report(rules.evaluate(string));
    final parsed = Uri.tryParse(string);
    if (parsed == null || !parsed.hasScheme || parsed.scheme.isEmpty) {
      reader.fail(_urlError);
    }
    return parsed;
  }

  @override
  Uri placeholder() => Uri();

  @override
  Schema schema() => Schema.string(format: 'uri');
}

final class _EnumType<E extends Enum> extends JsonType<E> {
  const _EnumType(this.values, this.by);

  final Iterable<E> values;
  final String Function(E value)? by;

  String _nameOf(E value) => by?.call(value) ?? value.name;

  @override
  E decode(Object value, JsonReader reader) {
    final string = JsonType.string.decode(value, reader);
    for (final e in values) {
      if (_nameOf(e) == string) return e;
    }
    reader.fail(
      ValidationError(
        code: 'enum',
        params: {'expected': values.map(_nameOf).toList()},
      ),
    );
  }

  @override
  E placeholder() => values.first;

  @override
  Schema schema() => Schema.string(enumValues: values.map(_nameOf).toList());
}

/// The discriminator of [JsonObject.discriminated], one of [tags].
final class _DiscriminatorType extends JsonType<String> {
  const _DiscriminatorType(this.tags);

  final Iterable<String> tags;

  @override
  String decode(Object value, JsonReader reader) {
    final tag = JsonType.string.decode(value, reader);
    if (tags.contains(tag)) return tag;
    reader.fail(
      ValidationError(
        code: 'discriminator',
        params: {'expected': tags.toList()},
      ),
    );
  }

  @override
  String placeholder() => tags.first;

  @override
  Schema schema() => Schema.string(enumValues: tags.toList());
}

final class _ObjectType<T> extends JsonType<T> {
  const _ObjectType(this.mapper);

  final T Function(JsonObject json) mapper;

  @override
  T decode(Object value, JsonReader reader) {
    if (value is! Map<String, Object?>) {
      reader.fail(.type(expected: 'object', actual: value));
    }
    return reader.object(value, mapper);
  }

  @override
  T placeholder() => mapper(const _DummyJsonObject());

  @override
  Schema schema() => _traceSchema(mapper);
}

final class _ListType<T> extends JsonType<List<T>> {
  const _ListType(this.items);

  final JsonType<T> items;

  @override
  List<T> decode(Object value, JsonReader reader) {
    final List<Object?> list;
    if (value is List) {
      list = value;
    } else if (reader.source == .text) {
      list = [value];
    } else {
      reader.fail(.type(expected: 'array', actual: value));
    }
    return [
      for (var i = 0; i < list.length; i++) reader.child('$i', list[i], items),
    ];
  }

  @override
  List<T> placeholder() => <T>[];

  @override
  Schema schema() => Schema.list(items: items.schema());
}

final class _MapType<T> extends JsonType<Map<String, T>> {
  const _MapType(this.values);

  final JsonType<T> values;

  @override
  Map<String, T> decode(Object value, JsonReader reader) {
    if (value is! Map<String, Object?>) {
      reader.fail(.type(expected: 'object', actual: value));
    }
    return {
      for (final MapEntry(:key, :value) in value.entries)
        key: reader.child(key, value, values),
    };
  }

  @override
  Map<String, T> placeholder() => <String, T>{};

  @override
  Schema schema() => Schema.object(additionalProperties: values.schema());
}

final class _NullableType<T> extends JsonType<T?> {
  const _NullableType(this.inner);

  final JsonType<T> inner;

  @override
  T decode(Object value, JsonReader reader) => inner.decode(value, reader);

  @override
  T? placeholder() => null;

  @override
  Schema schema() => inner.schema();

  @override
  bool get emptyIsAbsent => inner.emptyIsAbsent;
}

final class _RuledType<T> extends JsonType<T> {
  const _RuledType(this.inner, this.rules);

  final JsonType<T> inner;
  final List<ValidationRule<T>> rules;

  @override
  T decode(Object value, JsonReader reader) {
    final decoded = inner.decode(value, reader);
    reader.report(rules.evaluate(decoded));
    return decoded;
  }

  @override
  T placeholder() => inner.placeholder();

  @override
  Schema schema() => _constrainSchema(inner.schema(), rules);

  @override
  bool get emptyIsAbsent => inner.emptyIsAbsent;
}

final class _ConvertedType<B, T> extends JsonType<T> {
  const _ConvertedType(
    this.base,
    this.converter,
    this._placeholder,
    this._schema,
  );

  final JsonType<B> base;
  final T Function(B value, JsonReader reader) converter;
  final T _placeholder;
  final Schema? _schema;

  @override
  T decode(Object value, JsonReader reader) =>
      converter(base.decode(value, reader), reader);

  @override
  T placeholder() => _placeholder;

  @override
  Schema schema() => _schema ?? base.schema();
}
