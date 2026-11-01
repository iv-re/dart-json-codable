# json_codable

JSON parsing, validation, and schema generation.

## Usage

### Parsing & Validation (`JsonObject`)

`JsonObject` supports two parsing modes: **Accumulated Validation** (`json.parse`) and **Fail-Fast** (direct constructor).

```dart
import 'dart:convert';
import 'package:json_codable/json_codable.dart';

class CreateUserDto {
  CreateUserDto.fromJson(JsonObject json)
      : name = json.string('name', rules: [.length(min: 2)]),
        email = json.string('email', rules: [.email()]),
        age = json.intOrNull('age', rules: [.range(min: 18)]);

  final String name;
  final String email;
  final int? age;
}

final jsonString = '{"name": "A", "email": "invalid"}';
final jsonMap = jsonDecode(jsonString) as Map<String, Object?>;
final json = JsonObject(jsonMap);

// Accumulated Validation: collects ALL field errors before throwing
try {
  final user = json.parse(CreateUserDto.fromJson);
} on ValidationErrors catch (error) {
  print(error.toJson()); // Contains errors for both 'name' and 'email'
}

// Fail-Fast: throws immediately on the first encountered error
try {
  final user = CreateUserDto.fromJson(json);
} on ValidationErrors catch (error) {
  print(error.toJson()); // Contains only the first error ('name')
}
```

### Collections

Lists and maps take the type of their items as a `JsonType`:

```dart
final ids = json.list('ids', .int);
final tags = json.list('tags', .string.where([.length(min: 2)]));
final users = json.list('users', .object(UserDto.fromJson));
final files = json.list('files', .discriminated('type', {
  'doc': DocDto.fromJson,
  'video': VideoDto.fromJson,
}));
final labels = json.mapOrNull('labels', .string);
```

Item errors are reported at the item path, such as `users.1.email`.

### Custom Types

`JsonType.convert` turns a type into your own. Custom types get validation
errors, schema generation and `json.field` support like the built-in ones:

```dart
final userId = JsonType.string.convert(
  (value, reader) =>
      UserId.tryParse(value) ?? reader.fail(const .new(code: 'user_id')),
  placeholder: UserId.empty,
  schema: Schema.string(format: 'uuid'),
);

final id = json.read('id', userId);
final ids = json.list('ids', userId);
```

`placeholder` is what a failed read returns, so that `parse` can go on and
collect the errors of the remaining fields.

### Text Sources

Query parameters, form fields and headers arrive as strings. Wrap them with
`JsonSource.text` and each getter converts the string to the type it reads:

```dart
final query = JsonObject(
  {'page': '2', 'q': '007', 'ids': '5'},
  source: .text,
);

query.int('page'); // 2
query.string('q'); // '007'
query.list('ids', .int); // [5]
```

Numbers must be decimal, booleans are `true` or `false`, an empty value counts
as absent for every type except string, and a single value is accepted where a
list is expected.

### Serialization (`ToJson`)

Implement `ToJson` for DTOs and models that export to JSON maps:

```dart
class UserDto implements ToJson {
  UserDto({required this.id, required this.name});

  final String id;
  final String name;

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
  };
}
```

### Schema Generation

Generate JSON Schema documents directly from `fromJson` mappers or builder callbacks:

```dart
class CreateUserDto {
  // ...
  static final Schema schema = JsonObject.schema(
    CreateUserDto.fromJson,
    title: 'CreateUserDto',
  );
}
```
