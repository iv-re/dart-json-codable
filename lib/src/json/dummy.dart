part of 'json.dart';

class _DummyJsonObject implements JsonObject {
  const _DummyJsonObject();

  @override
  Iterable<String> get keys => const [];

  @override
  bool has(String key) => false;

  @override
  JsonFieldExtractor get field => JsonFieldExtractor(this);

  @override
  T parse<T>(T Function(JsonObject json) mapper) => mapper(this);

  @override
  Object any(String key) => const Object();

  @override
  Object? anyOrNull(String key) => null;

  @override
  String string(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) => '';

  @override
  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) => null;

  @override
  int integer(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) => 0;

  @override
  int? integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) => null;

  @override
  double float(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) => 0;

  @override
  double? floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) => null;

  @override
  bool boolean(String key) => false;

  @override
  bool? booleanOrNull(String key) => null;

  @override
  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) => null;

  @override
  DateTime timestamp(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  DateTime? timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) => null;

  @override
  Uri uri(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) => Uri();

  @override
  Uri? uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) => null;

  @override
  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) => values.first;

  @override
  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) => null;

  @override
  T object<T>(String key, T Function(JsonObject json) mapper) {
    try {
      return mapper(const _DummyJsonObject());
    } catch (_) {
      return null as T;
    }
  }

  @override
  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper) => null;

  @override
  List<T> list<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) => <T>[];

  @override
  List<T>? listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) => null;

  @override
  Map<String, T> map<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) => <String, T>{};

  @override
  Map<String, T>? mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) => null;

  @override
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    assert(mappers.isNotEmpty, 'mappers must not be empty');
    return mappers.values.first(const _DummyJsonObject());
  }
}
