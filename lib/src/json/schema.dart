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

_SchemaConstraints _aggregateRules(List<ValidationRule<Object?>> rules) {
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

/// Adds the constraints [rules] imply to [schema].
Schema _constrainSchema(Schema schema, List<ValidationRule<Object?>> rules) {
  final c = _aggregateRules(rules);
  num? bound(num? value) =>
      schema.value['type'] == 'integer' ? value?.toInt() : value;

  final constraints = switch (schema.value['type']) {
    'string' => {
      'minLength': ?c.minLength,
      'maxLength': ?c.maxLength,
      'pattern': ?c.pattern,
      'format': ?c.format,
    },
    'integer' || 'number' => {
      'minimum': ?bound(c.minimum),
      'maximum': ?bound(c.maximum),
      'exclusiveMinimum': ?bound(c.exclusiveMinimum),
      'exclusiveMaximum': ?bound(c.exclusiveMaximum),
    },
    _ => const <String, Object>{},
  };
  if (constraints.isEmpty) return schema;
  return Schema.fromMap({...schema.value, ...constraints});
}

/// Builds the schema of the objects [mapper] parses by running it on a
/// [_SchemaJsonObject].
Schema _traceSchema(
  Object? Function(JsonObject json) mapper, {
  String? title,
  String? description,
}) {
  final ctx = _SchemaContext();
  try {
    mapper(_SchemaJsonObject(ctx));
  } catch (e) {
    // The mapper rejected a placeholder value; keep the fields traced so far.
    if (e is AssertionError) rethrow;
  }
  return ctx.toSchema(title: title, description: description);
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

/// A [JsonObject] that records the schema of every field read from it.
class _SchemaJsonObject extends _DummyJsonObject {
  const _SchemaJsonObject(this._schemaCtx);

  final _SchemaContext _schemaCtx;

  @override
  bool has(String key) => true;

  @override
  T read<T>(String key, JsonType<T> type) {
    _schemaCtx.add(key, type.schema(), isRequired: true);
    return super.read(key, type);
  }

  @override
  T? readOrNull<T>(String key, JsonType<T> type) {
    _schemaCtx.add(key, type.schema(), isRequired: false);
    return super.readOrNull(key, type);
  }

  @override
  T discriminated<T>(
    String key,
    Map<String, T Function(JsonObject json)> mappers,
  ) {
    _schemaCtx.discriminator = key;
    for (final entry in mappers.entries) {
      final childCtx = _SchemaContext();
      try {
        entry.value(_SchemaJsonObject(childCtx));
      } catch (e) {
        // Same as in _traceSchema.
        if (e is AssertionError) rethrow;
      }

      childCtx.add(
        key,
        Schema.string(constValue: entry.key),
        isRequired: true,
      );

      _schemaCtx.oneOf.add(
        Schema.object(
          properties: childCtx.properties,
          required: childCtx.requiredFields,
        ),
      );
    }
    return super.discriminated(key, mappers);
  }
}
