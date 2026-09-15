part of 'json.dart';

typedef _SchemaConstraints = ({
  int? minLength,
  int? maxLength,
  String? pattern,
  String? format,
  num? minimum,
  num? maximum,
  num? exclusiveMinimum,
  num? exclusiveMaximum,
});

_SchemaConstraints _aggregateRules(List<ValidationRule<Object>> rules) {
  int? minLength;
  int? maxLength;
  String? pattern;
  String? format;
  num? minimum;
  num? maximum;
  num? exclusiveMinimum;
  num? exclusiveMaximum;

  for (final rule in rules) {
    switch (rule) {
      case LengthValidationRule():
        if (rule.min != null) minLength = rule.min;
        if (rule.max != null) maxLength = rule.max;
        if (rule.equal != null) {
          minLength = rule.equal;
          maxLength = rule.equal;
        }
      case RangeValidationRule():
        if (rule.min != null) minimum = rule.min;
        if (rule.max != null) maximum = rule.max;
        if (rule.exclusiveMin != null) {
          exclusiveMinimum = rule.exclusiveMin;
        }
        if (rule.exclusiveMax != null) {
          exclusiveMaximum = rule.exclusiveMax;
        }
      case EmailValidationRule():
        format = 'email';
      case UrlValidationRule():
        format = 'uri';
      case Ipv4ValidationRule():
        format = 'ipv4';
      case Ipv6ValidationRule():
        format = 'ipv6';
      case RegexValidationRule():
        pattern = rule.pattern.pattern;
    }
  }

  return (
    minLength: minLength,
    maxLength: maxLength,
    pattern: pattern,
    format: format,
    minimum: minimum,
    maximum: maximum,
    exclusiveMinimum: exclusiveMinimum,
    exclusiveMaximum: exclusiveMaximum,
  );
}

Schema _primitiveSchema<T>() {
  if (T == String) return .string();
  if (T == int) return .integer();
  if (T == double || T == num) return .number();
  if (T == bool) return .boolean();
  return .any();
}

class _SchemaContext {
  final Map<String, Schema> properties = {};
  final List<String> requiredFields = [];
  final List<Schema> oneOf = [];
  String? discriminator;

  void add(String key, Schema schema, {required bool isRequired}) {
    properties[key] = schema;
    if (isRequired) requiredFields.add(key);
  }

  Schema toSchema({String? title, String? description}) {
    if (properties.containsKey(r'$')) {
      return properties[r'$']!;
    }

    Schema? objectSchema;
    if (properties.isNotEmpty || oneOf.isEmpty) {
      objectSchema = Schema.object(
        title: oneOf.isEmpty ? title : null,
        description: oneOf.isEmpty ? description : null,
        properties: properties.isNotEmpty ? properties : null,
        required: requiredFields.isNotEmpty ? requiredFields : null,
      );
    }

    if (oneOf.isNotEmpty) {
      final combined = Schema.fromMap({
        if (objectSchema == null && title != null) 'title': title,
        if (objectSchema == null && description != null)
          'description': description,
        if (discriminator != null)
          'discriminator': {'propertyName': discriminator},
        'oneOf': oneOf.map((s) => s.value).toList(),
      });
      if (objectSchema != null) {
        return Schema.combined(
          title: title,
          description: description,
          allOf: [objectSchema, combined],
        );
      }
      return combined;
    }

    return objectSchema!;
  }
}

class _SchemaJsonObject extends _DummyJsonObject {
  const _SchemaJsonObject(this._schemaCtx);

  final _SchemaContext _schemaCtx;

  @override
  bool has(String key) => true;

  @override
  Object any(String key) {
    _schemaCtx.add(key, Schema.any(), isRequired: true);
    return super.any(key);
  }

  @override
  Object? anyOrNull(String key) {
    _schemaCtx.add(key, Schema.any(), isRequired: false);
    return super.anyOrNull(key);
  }

  @override
  String string(String key, {List<ValidationRule<String>> rules = const []}) {
    final c = _aggregateRules(rules);
    _schemaCtx.add(
      key,
      Schema.string(
        minLength: c.minLength,
        maxLength: c.maxLength,
        pattern: c.pattern,
        format: c.format,
      ),
      isRequired: true,
    );
    return super.string(key, rules: rules);
  }

  @override
  String? stringOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    final c = _aggregateRules(rules);

    _schemaCtx.add(
      key,
      Schema.string(
        minLength: c.minLength,
        maxLength: c.maxLength,
        pattern: c.pattern,
        format: c.format,
      ),
      isRequired: false,
    );
    return super.stringOrNull(key, rules: rules);
  }

  @override
  int integer(String key, {List<ValidationRule<num>> rules = const []}) {
    final c = _aggregateRules(rules);
    _schemaCtx.add(
      key,
      Schema.integer(
        minimum: c.minimum?.toInt(),
        maximum: c.maximum?.toInt(),
        exclusiveMinimum: c.exclusiveMinimum?.toInt(),
        exclusiveMaximum: c.exclusiveMaximum?.toInt(),
      ),
      isRequired: true,
    );
    return super.integer(key, rules: rules);
  }

  @override
  int? integerOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    final c = _aggregateRules(rules);
    _schemaCtx.add(
      key,
      Schema.integer(
        minimum: c.minimum?.toInt(),
        maximum: c.maximum?.toInt(),
        exclusiveMinimum: c.exclusiveMinimum?.toInt(),
        exclusiveMaximum: c.exclusiveMaximum?.toInt(),
      ),
      isRequired: false,
    );
    return super.integerOrNull(key, rules: rules);
  }

  @override
  double float(String key, {List<ValidationRule<num>> rules = const []}) {
    final c = _aggregateRules(rules);
    _schemaCtx.add(
      key,
      Schema.number(
        minimum: c.minimum,
        maximum: c.maximum,
        exclusiveMinimum: c.exclusiveMinimum,
        exclusiveMaximum: c.exclusiveMaximum,
      ),
      isRequired: true,
    );
    return super.float(key, rules: rules);
  }

  @override
  double? floatOrNull(
    String key, {
    List<ValidationRule<num>> rules = const [],
  }) {
    final c = _aggregateRules(rules);
    _schemaCtx.add(
      key,
      Schema.number(
        minimum: c.minimum,
        maximum: c.maximum,
        exclusiveMinimum: c.exclusiveMinimum,
        exclusiveMaximum: c.exclusiveMaximum,
      ),
      isRequired: false,
    );
    return super.floatOrNull(key, rules: rules);
  }

  @override
  bool boolean(String key) {
    _schemaCtx.add(key, Schema.boolean(), isRequired: true);
    return super.boolean(key);
  }

  @override
  bool? booleanOrNull(String key) {
    _schemaCtx.add(key, Schema.boolean(), isRequired: false);
    return super.booleanOrNull(key);
  }

  @override
  DateTime dateTime(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    _schemaCtx.add(key, Schema.string(format: 'date-time'), isRequired: true);
    return super.dateTime(key, rules: rules);
  }

  @override
  DateTime? dateTimeOrNull(
    String key, {
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    _schemaCtx.add(key, Schema.string(format: 'date-time'), isRequired: false);
    return super.dateTimeOrNull(key, rules: rules);
  }

  @override
  DateTime timestamp(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    _schemaCtx.add(key, Schema.integer(), isRequired: true);
    return super.timestamp(key, isSeconds: isSeconds, rules: rules);
  }

  @override
  DateTime? timestampOrNull(
    String key, {
    bool isSeconds = false,
    List<ValidationRule<DateTime>> rules = const [],
  }) {
    _schemaCtx.add(key, Schema.integer(), isRequired: false);
    return super.timestampOrNull(key, isSeconds: isSeconds, rules: rules);
  }

  @override
  Uri uri(String key, {List<ValidationRule<String>> rules = const []}) {
    _schemaCtx.add(key, Schema.string(format: 'uri'), isRequired: true);
    return super.uri(key, rules: rules);
  }

  @override
  Uri? uriOrNull(
    String key, {
    List<ValidationRule<String>> rules = const [],
  }) {
    _schemaCtx.add(key, Schema.string(format: 'uri'), isRequired: false);
    return super.uriOrNull(key, rules: rules);
  }

  @override
  T enumeration<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    final stringValues = values.map((e) => by?.call(e) ?? e.name).toList();
    _schemaCtx.add(
      key,
      Schema.string(enumValues: stringValues),
      isRequired: true,
    );
    return super.enumeration(key, values, by: by);
  }

  @override
  T? enumerationOrNull<T extends Enum>(
    String key,
    Iterable<T> values, {
    String Function(T value)? by,
  }) {
    final stringValues = values.map((e) => by?.call(e) ?? e.name).toList();
    _schemaCtx.add(
      key,
      Schema.string(enumValues: stringValues),
      isRequired: false,
    );
    return super.enumerationOrNull(key, values, by: by);
  }

  @override
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    _schemaCtx.discriminator = key;
    for (final entry in mappers.entries) {
      final childCtx = _SchemaContext();
      final childJson = _SchemaJsonObject(childCtx);
      entry.value(childJson);

      childCtx.add(
        key,
        Schema.string(constValue: entry.key),
        isRequired: true,
      );

      final schema = Schema.object(
        properties: childCtx.properties,
        required: childCtx.requiredFields,
      );

      _schemaCtx.oneOf.add(schema);
    }
    return super.discriminated(key, mappers);
  }

  @override
  T object<T>(String key, T Function(JsonObject json) mapper) {
    final childCtx = _SchemaContext();
    final childJson = _SchemaJsonObject(childCtx);
    mapper(childJson);
    _schemaCtx.add(
      key,
      childCtx.toSchema(),
      isRequired: true,
    );
    return super.object(key, mapper);
  }

  @override
  T? objectOrNull<T>(String key, T Function(JsonObject json) mapper) {
    final childCtx = _SchemaContext();
    final childJson = _SchemaJsonObject(childCtx);
    mapper(childJson);
    _schemaCtx.add(
      key,
      childCtx.toSchema(),
      isRequired: false,
    );
    return super.objectOrNull(key, mapper);
  }

  @override
  List<T> list<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    Schema itemSchema;
    if (mapper != null) {
      final childCtx = _SchemaContext();
      final childJson = _SchemaJsonObject(childCtx);
      mapper(childJson);
      itemSchema = childCtx.toSchema();
    } else {
      itemSchema = _primitiveSchema<T>();
    }
    _schemaCtx.add(key, Schema.list(items: itemSchema), isRequired: true);
    return super.list(key, mapper: mapper, rules: rules);
  }

  @override
  List<T>? listOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    Schema itemSchema;
    if (mapper != null) {
      final childCtx = _SchemaContext();
      final childJson = _SchemaJsonObject(childCtx);
      mapper(childJson);
      itemSchema = childCtx.toSchema();
    } else {
      itemSchema = _primitiveSchema<T>();
    }
    _schemaCtx.add(key, Schema.list(items: itemSchema), isRequired: false);
    return super.listOrNull(key, mapper: mapper, rules: rules);
  }

  @override
  Map<String, T> map<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    Schema itemSchema;
    if (mapper != null) {
      final childCtx = _SchemaContext();
      final childJson = _SchemaJsonObject(childCtx);
      mapper(childJson);
      itemSchema = childCtx.toSchema();
    } else {
      itemSchema = _primitiveSchema<T>();
    }
    _schemaCtx.add(
      key,
      Schema.object(additionalProperties: itemSchema),
      isRequired: true,
    );
    return super.map(key, mapper: mapper, rules: rules);
  }

  @override
  Map<String, T>? mapOrNull<T>(
    String key, {
    T Function(JsonObject json)? mapper,
    List<ValidationRule<T>> rules = const [],
  }) {
    Schema itemSchema;
    if (mapper != null) {
      final childCtx = _SchemaContext();
      final childJson = _SchemaJsonObject(childCtx);
      mapper(childJson);
      itemSchema = childCtx.toSchema();
    } else {
      itemSchema = _primitiveSchema<T>();
    }
    _schemaCtx.add(
      key,
      Schema.object(additionalProperties: itemSchema),
      isRequired: false,
    );
    return super.mapOrNull(key, mapper: mapper, rules: rules);
  }
}
