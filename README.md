# json_codable

JSON parsing, validation, serialization, and schema generation.

## Usage

### Parsing & Validation (`JsonObject`)

`JsonObject` supports two parsing modes: **Accumulated Validation** (`json.parse`) and **Fail-Fast** (direct constructor).

```dart
import 'package:json_codable/json_codable.dart';

class CreateUserDto {
  CreateUserDto.fromJson(JsonObject json)
      : name = json.string('name', rules: [.length(min: 2)]),
        email = json.string('email', rules: [.email()]),
        age = json.integerOrNull('age', rules: [.range(min: 18)]);

  final String name;
  final String email;
  final int? age;
}

final jsonString = '{"name": "A", "email": "invalid"}';
final json = JsonObject.fromString(jsonString);

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

### Serialization (`ToJson` & `JsonWriter`)

Implement `ToJson` for DTOs and models to serialize directly to `JsonWriter` (UTF-8 bytes):

```dart
class UserDto implements ToJson {
  UserDto({required this.id, required this.name});

  final String id;
  final String name;

  @override
  void toJson(JsonWriter writer) {
    writer.string('id', id);
    writer.string('name', name);
  }
}

// Encode root object to Uint8List bytes
final bytes = JsonWriter.encode(user.toJson);

// Encode list of objects to Uint8List bytes
final listBytes = JsonWriter.encodeList(
  users,
  mapper: (w, item) => item.toJson(w),
);
```

### Schema Generation

Generate JSON Schema documents directly from `fromJson` mappers:

```dart
class CreateUserDto {
  // ...
  static final Schema schema = JsonObject.schema(
    CreateUserDto.fromJson,
    title: 'CreateUserDto',
  );
}
```
