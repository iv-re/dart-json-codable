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
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'email': email};
}

void main() {
  print('--- Schema Generation ---');
  print(CreateUserDto.schema);

  print('\n--- Parsing Valid JSON ---');
  const validJson = '{"name": "Ivan", "email": "ivan@example.com", "age": 25}';
  final validMap = jsonDecode(validJson) as Map<String, Object?>;
  final userPayload = JsonObject(validMap).parse(CreateUserDto.fromJson);
  print('Parsed user: ${userPayload.name} (${userPayload.email})');

  print('\n--- Serialization ---');
  final userDto = UserDto(
    id: '1',
    name: userPayload.name,
    email: userPayload.email,
  );
  print('JSON String: ${jsonEncode(userDto.toJson())}');

  print('\n--- Validation Errors ---');
  const invalidJson = '{"name": "A", "email": "not-an-email"}';
  final invalidMap = jsonDecode(invalidJson) as Map<String, Object?>;

  try {
    JsonObject(invalidMap).parse(CreateUserDto.fromJson);
  } on ValidationErrors catch (errors) {
    print('Validation failed:');
    print(errors.toJson());
  }
}
