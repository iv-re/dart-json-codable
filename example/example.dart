import 'dart:convert';

import 'package:json_codable/json_codable.dart';

class CreateUserDto {
  CreateUserDto.fromJson(JsonObject json)
    : name = json.string('name', rules: [.length(min: 2)]),
      email = json.string('email', rules: [.email()]),
      age = json.integerOrNull('age', rules: [.range(min: 18)]);

  static final Schema schema = JsonObject.schema(
    CreateUserDto.fromJson,
    title: 'CreateUserDto',
  );

  final String name;
  final String email;
  final int? age;
}

class UserDto implements ToJson {
  UserDto({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;

  @override
  void toJson(JsonWriter writer) {
    writer
      ..string('id', id)
      ..string('name', name)
      ..string('email', email);
  }
}

void main() {
  print('--- Schema Generation ---');
  print(CreateUserDto.schema);

  print('\n--- Parsing Valid JSON ---');
  final validJson = JsonObject.fromString(
    '{"name": "Ivan", "email": "ivan@example.com", "age": 25}',
  ).parse(CreateUserDto.fromJson);
  print('Parsed user: ${validJson.name} (${validJson.email})');

  print('\n--- Serialization ---');
  final userDto = UserDto(
    id: '1',
    name: validJson.name,
    email: validJson.email,
  );
  final jsonBytes = JsonWriter.encode(userDto.toJson);
  print('JSON String: ${utf8.decode(jsonBytes)}');

  print('\n--- Validation Errors ---');
  try {
    JsonObject.fromString(
      '{"name": "A", "email": "not-an-email"}',
    ).parse(CreateUserDto.fromJson);
  } on ValidationErrors catch (errors) {
    print('Validation failed:');
    print(errors.toMap());
  }
}
