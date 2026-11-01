import 'dart:core';
import 'dart:core' as core;

import 'package:json_codable/src/validation.dart';
import 'package:json_schema_builder/json_schema_builder.dart'
    hide ValidationError;

part 'dummy.dart';
part 'getters.dart';
part 'impl.dart';
part 'schema.dart';
part 'types.dart';

/// Interface for objects that can be serialized to JSON.
abstract interface class ToJson {
  /// Converts this object to a JSON-encodable map.
  Map<String, Object?> toJson();
}

/// A strongly-typed wrapper around a `Map<String, Object?>` for extracting
/// and validating JSON fields.
abstract interface class JsonObject {
  /// Wraps [map], whose values come from [source].
  const factory JsonObject(Map<String, Object?> map, {JsonSource source}) =
      _JsonObjectImpl;

  static Schema schema<T>(
    T Function(JsonObject json) mapper, {
    String? title,
    String? description,
  }) => _traceSchema(mapper, title: title, description: description);

  JsonFieldExtractor get field;

  /// Returns the top-level keys present in the JSON object.
  Iterable<String> get keys;

  core.bool has(String key);

  T parse<T>(T Function(JsonObject json) mapper);

  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  );

  /// Extracts a required field by [key] and decodes it with [type].
  T read<T>(String key, JsonType<T> type);

  /// Extracts an optional field by [key] and decodes it with [type].
  T? readOrNull<T>(String key, JsonType<T> type);

  Object any(String key);

  Object? anyOrNull(String key);

  String string(String key, {List<ValidationRule<String>> rules = const []});

  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  });

  core.int int(String key, {List<ValidationRule<core.int>> rules = const []});

  core.int? intOrNull(
    String key, {
    List<ValidationRule<core.int>> rules = const [],
  });

  core.double double(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  });

  core.double? doubleOrNull(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  });

  core.num num(String key, {List<ValidationRule<core.num>> rules = const []});

  core.num? numOrNull(
    String key, {
    List<ValidationRule<core.num>> rules = const [],
  });

  core.bool bool(String key);

  core.bool? boolOrNull(String key);

  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime timestamp(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  });

  DateTime? timestampOrNull(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  });

  Uri uri(String key, {List<ValidationRule<String>> rules = const []});

  Uri? uriOrNull(String key, {List<ValidationRule<String>> rules = const []});

  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  });

  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  });

  T object<T>(String key, T Function(JsonObject json) mapper);

  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper);

  /// Extracts a required list by [key] whose items are [items].
  List<T> list<T>(String key, JsonType<T> items);

  /// Extracts an optional list by [key] whose items are [items].
  List<T>? listOrNull<T>(String key, JsonType<T> items);

  /// Extracts a required object by [key] whose values are [values].
  Map<String, T> map<T>(String key, JsonType<T> values);

  /// Extracts an optional object by [key] whose values are [values].
  Map<String, T>? mapOrNull<T>(String key, JsonType<T> values);
}

/// Represents a field in a JSON object that can be either absent or present
/// (with a value or explicitly `null`).
sealed class JsonField<T> {
  const JsonField();

  const factory JsonField.absent() = JsonFieldAbsent;
  const factory JsonField.present(T value) = JsonFieldPresent<T>;

  /// Whether the field was present in the JSON object.
  bool get isPresent => this is JsonFieldPresent;

  /// Returns the value if present, or throws a [StateError] if absent.
  T get value => switch (this) {
    JsonFieldAbsent() => throw StateError('Field is absent'),
    JsonFieldPresent<T>(:final value) => value,
  };

  /// Returns the value if present, or `null` if absent.
  T? get valueOrNull => switch (this) {
    JsonFieldAbsent() => null,
    JsonFieldPresent<T>(:final value) => value,
  };
}

/// Represents an absent field in a JSON object.
final class JsonFieldAbsent extends JsonField<Never> {
  const JsonFieldAbsent();
}

/// Represents a present field in a JSON object.
final class JsonFieldPresent<T> extends JsonField<T> {
  const JsonFieldPresent(this.value);

  @override
  final T value;
}

/// Helper class for extracting fields as [JsonField] wrappers.
extension type const JsonFieldExtractor(JsonObject _json) {
  @pragma('vm:prefer-inline')
  JsonField<T> read<T>(String key, JsonType<T> type) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.read(key, type));
  }

  @pragma('vm:prefer-inline')
  JsonField<T?> readOrNull<T>(String key, JsonType<T> type) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.readOrNull(key, type));
  }

  @pragma('vm:prefer-inline')
  JsonField<String> string(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.string(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<String?> stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.stringOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.int> int(
    String key, {
    List<ValidationRule<core.int>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.int(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.int?> intOrNull(
    String key, {
    List<ValidationRule<core.int>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.intOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.double> double(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.double(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.double?> doubleOrNull(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.doubleOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.num> num(
    String key, {
    List<ValidationRule<core.num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.num(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.num?> numOrNull(
    String key, {
    List<ValidationRule<core.num>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.numOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.bool> bool(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.bool(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<core.bool?> boolOrNull(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.boolOrNull(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime> dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.dateTime(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime?> dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.dateTimeOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime> timestamp(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(
      _json.timestamp(key, isSeconds: isSeconds, rules: rules),
    );
  }

  @pragma('vm:prefer-inline')
  JsonField<DateTime?> timestampOrNull(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(
      _json.timestampOrNull(key, isSeconds: isSeconds, rules: rules),
    );
  }

  @pragma('vm:prefer-inline')
  JsonField<Uri> uri(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.uri(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<Uri?> uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.uriOrNull(key, rules: rules));
  }

  @pragma('vm:prefer-inline')
  JsonField<T> enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.enumeration<T>(key, values, by: by));
  }

  @pragma('vm:prefer-inline')
  JsonField<T?> enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.enumerationOrNull<T>(key, values, by: by));
  }

  @pragma('vm:prefer-inline')
  JsonField<T> object<T>(String key, T Function(JsonObject json) mapper) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.object(key, mapper));
  }

  @pragma('vm:prefer-inline')
  JsonField<T?> objectOrNull<T>(
    String key,
    T Function(JsonObject json) mapper,
  ) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.objectOrNull<T>(key, mapper));
  }

  @pragma('vm:prefer-inline')
  JsonField<List<T>> list<T>(String key, JsonType<T> items) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.list(key, items));
  }

  @pragma('vm:prefer-inline')
  JsonField<List<T>?> listOrNull<T>(String key, JsonType<T> items) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.listOrNull(key, items));
  }

  @pragma('vm:prefer-inline')
  JsonField<Map<String, T>> map<T>(String key, JsonType<T> values) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.map(key, values));
  }

  @pragma('vm:prefer-inline')
  JsonField<Map<String, T>?> mapOrNull<T>(String key, JsonType<T> values) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.mapOrNull(key, values));
  }

  @pragma('vm:prefer-inline')
  JsonField<Object> any(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.any(key));
  }

  @pragma('vm:prefer-inline')
  JsonField<Object?> anyOrNull(String key) {
    if (!_json.has(key)) return const .absent();
    return .present(_json.anyOrNull(key));
  }
}
