part of 'json.dart';

/// The typed getters of [JsonObject], each a [JsonObject.read] or
/// [JsonObject.readOrNull] with a [JsonType].
mixin _JsonGetters implements JsonObject {
  @override
  JsonFieldExtractor get field => JsonFieldExtractor(this);

  @override
  Object any(String key) => read(key, JsonType.any);

  @override
  Object? anyOrNull(String key) => readOrNull(key, JsonType.any);

  @override
  String string(String key, {List<ValidationRule<String>> rules = const []}) =>
      read(key, JsonType.string.where(rules));

  @override
  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) => readOrNull(key, JsonType.string.where(rules));

  @override
  core.int int(String key, {List<ValidationRule<core.int>> rules = const []}) =>
      read(key, JsonType.int.where(rules));

  @override
  core.int? intOrNull(
    String key, {
    List<ValidationRule<core.int>> rules = const [],
  }) => readOrNull(key, JsonType.int.where(rules));

  @override
  core.double double(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  }) => read(key, JsonType.double.where(rules));

  @override
  core.double? doubleOrNull(
    String key, {
    List<ValidationRule<core.double>> rules = const [],
  }) => readOrNull(key, JsonType.double.where(rules));

  @override
  core.num num(String key, {List<ValidationRule<core.num>> rules = const []}) =>
      read(key, JsonType.num.where(rules));

  @override
  core.num? numOrNull(
    String key, {
    List<ValidationRule<core.num>> rules = const [],
  }) => readOrNull(key, JsonType.num.where(rules));

  @override
  core.bool bool(String key) => read(key, JsonType.bool);

  @override
  core.bool? boolOrNull(String key) => readOrNull(key, JsonType.bool);

  @override
  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) => read(key, JsonType.dateTime.where(rules));

  @override
  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) => readOrNull(key, JsonType.dateTime.where(rules));

  @override
  DateTime timestamp(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) => read(key, JsonType.timestamp(isSeconds: isSeconds).where(rules));

  @override
  DateTime? timestampOrNull(
    String key, {
    core.bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) => readOrNull(key, JsonType.timestamp(isSeconds: isSeconds).where(rules));

  @override
  Uri uri(String key, {List<ValidationRule<String>> rules = const []}) =>
      read(key, _UriType(rules));

  @override
  Uri? uriOrNull(String key, {List<ValidationRule<String>> rules = const []}) =>
      readOrNull(key, _UriType(rules));

  @override
  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) => read(key, JsonType.enumeration(values, by: by));

  @override
  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) => readOrNull(key, JsonType.enumeration(values, by: by));

  @override
  T object<T>(String key, T Function(JsonObject json) mapper) =>
      read(key, JsonType.object(mapper));

  @override
  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper) =>
      readOrNull(key, JsonType.object(mapper));

  @override
  List<T> list<T>(String key, JsonType<T> items) =>
      read(key, JsonType.list(items));

  @override
  List<T>? listOrNull<T>(String key, JsonType<T> items) =>
      readOrNull(key, JsonType.list(items));

  @override
  Map<String, T> map<T>(String key, JsonType<T> values) =>
      read(key, JsonType.map(values));

  @override
  Map<String, T>? mapOrNull<T>(String key, JsonType<T> values) =>
      readOrNull(key, JsonType.map(values));
}
