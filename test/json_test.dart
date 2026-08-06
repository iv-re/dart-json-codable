import 'dart:convert';
import 'package:json_codable/json_codable.dart';
import 'package:test/test.dart';

JsonObject makeJson(Map<String, dynamic> map) {
  return JsonObject.fromString(jsonEncode(map));
}

void main() {
  group('JsonObject.fromMap', () {
    test(
      'extracts primitive fields and nested objects from Map via MapJsonReader',
      () {
        final json = JsonObject.fromMap({
          'name': 'Bob',
          'age': 30,
          'rating': 4.95,
          'active': true,
          'sub': {'code': 'X1'},
          'tags': ['a', 'b'],
        });

        expect(json.string('name'), equals('Bob'));
        expect(json.integer('age'), equals(30));
        expect(json.float('rating'), equals(4.95));
        expect(json.boolean('active'), isTrue);
        expect(json.object('sub', (s) => s.string('code')), equals('X1'));
        expect(json.list<String>('tags'), equals(['a', 'b']));
      },
    );

    test('validates rules and accumulates errors on JsonObject.fromMap', () {
      final json = JsonObject.fromMap({'name': 'A', 'age': 15});
      try {
        json.parse((j) {
          j.string('name', rules: [.length(min: 3)]);
          j.integer('age', rules: [.range(min: 18)]);
        });
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        expect(e.toMap().containsKey('name'), isTrue);
        expect(e.toMap().containsKey('age'), isTrue);
      }
    });
  });

  group('JsonObject Primitives', () {
    test('validates string field with rules', () {
      final json = makeJson({
        'name': 'Alice',
        'email': 'alice@example.com',
      });

      final name = json.string('name', rules: [.length(min: 2, max: 10)]);
      expect(name, equals('Alice'));

      expect(
        () => json.string('email', rules: [.length(max: 5)]),
        throwsA(isA<ValidationErrors>()),
      );
    });

    test('validates integer, float, boolean, dateTime, timestamp, uri', () {
      final json = makeJson({
        'age': 25,
        'score': 98.5,
        'active': true,
        'date': '2026-01-01T00:00:00.000Z',
        'ts': 1600000000,
        'link': 'https://dart.dev',
      });

      expect(json.integer('age', rules: [.range(min: 18)]), equals(25));
      expect(json.integerOrNull('missing'), isNull);

      expect(json.float('score', rules: [.range(min: 50.0)]), equals(98.5));
      expect(json.floatOrNull('missing'), isNull);

      expect(json.boolean('active'), isTrue);
      expect(json.booleanOrNull('missing'), isNull);

      expect(json.dateTime('date').year, equals(2026));
      expect(json.dateTimeOrNull('missing'), isNull);

      expect(json.timestamp('ts', isSeconds: true).year, equals(2020));
      expect(json.timestampOrNull('missing'), isNull);

      expect(json.uri('link').host, equals('dart.dev'));
      expect(json.uriOrNull('missing'), isNull);

      expect(json.any('age'), equals(25));
      expect(json.any('active'), isTrue);
      expect(json.anyOrNull('missing'), isNull);
    });

    test('parses enumeration', () {
      final json = makeJson({
        'status': 'active',
        'mapped_status': 'PENDING',
      });

      expect(
        json.enumeration('status', _Status.values),
        equals(_Status.active),
      );
      expect(
        json.enumeration(
          'mapped_status',
          _Status.values,
          by: (e) => e.name.toUpperCase(),
        ),
        equals(_Status.pending),
      );

      expect(json.enumerationOrNull('missing', _Status.values), isNull);
    });

    test('throws error on invalid enumeration', () {
      final json = makeJson({'status': 'unknown'});
      expect(
        () => json.enumeration('status', _Status.values),
        throwsA(
          predicate<ValidationErrors>((e) {
            final fieldErr = e.errors['status'] as ValidationErrorsField?;
            return fieldErr != null &&
                fieldErr.errors.first.code == 'invalid_enum';
          }),
        ),
      );
    });

    test('throws error on missing required field', () {
      final json = makeJson({});
      expect(
        () => json.string('missing'),
        throwsA(predicate<ValidationErrors>((e) => e.hasError('missing'))),
      );
    });

    test('accumulates all failed rules for a single field', () {
      final json = makeJson({'pass': 'abc'});

      try {
        json.string('pass', rules: [.length(min: 8), .contains('!')]);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final fieldErr = e.errors['pass'];
        expect(fieldErr, isA<ValidationErrorsField>());
        final fieldList = (fieldErr! as ValidationErrorsField).errors;
        expect(fieldList.length, equals(2));
        expect(fieldList[0].code, equals('length'));
        expect(fieldList[1].code, equals('contains'));
      }
    });

    test('primitive type errors', () {
      final json = makeJson({
        'str': 123,
        'int': 'abc',
        'float': 'abc',
        'bool': 1,
        'date': 123,
        'uri': 123,
      });

      expect(
        () => json.string('str'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['str'] != null)),
      );
      expect(
        () => json.integer('int'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['int'] != null)),
      );
      expect(
        () => json.float('float'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['float'] != null)),
      );
      expect(
        () => json.boolean('bool'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['bool'] != null)),
      );
      expect(
        () => json.dateTime('date'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['date'] != null)),
      );
      expect(
        () => json.uri('uri'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['uri'] != null)),
      );
    });

    test('primitive parse and validation errors', () {
      final json = makeJson({
        'date': 'invalid-date',
        'uri': 'invalid-uri',
      });

      expect(
        () => json.dateTime('date'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['date'] != null)),
      );
      expect(
        () => json.uri('uri'),
        throwsA(predicate<ValidationErrors>((e) => e.errors['uri'] != null)),
      );
    });

    test('OrNull branches return valid data', () {
      final json = makeJson({
        'str': 'hello',
        'int': 42,
        'float': 42.5,
        'bool': true,
        'date': '2026-01-01T00:00:00.000Z',
        'ts': 1600000000,
        'uri': 'https://dart.dev',
      });

      expect(json.stringOrNull('str'), equals('hello'));
      expect(json.integerOrNull('int'), equals(42));
      expect(json.floatOrNull('float'), equals(42.5));
      expect(json.booleanOrNull('bool'), isTrue);
      expect(json.dateTimeOrNull('date')?.year, equals(2026));
      expect(json.timestampOrNull('ts', isSeconds: true)?.year, equals(2020));
      expect(json.uriOrNull('uri')?.host, equals('dart.dev'));
    });
  });

  group('JsonObject Nested Structures (object, list, map)', () {
    test('validates primitive lists', () {
      final json = makeJson({
        'tags': ['dart', 'flutter'],
      });

      final tags = json.list<String>('tags', rules: [.length(min: 3)]);
      expect(tags, equals(['dart', 'flutter']));
      expect(json.listOrNull<String>('missing'), isNull);
    });

    test('validates list of nested objects', () {
      final json = makeJson({
        'users': [
          {'name': 'Bob'},
        ],
      });

      final users = json.list<String>('users', mapper: (j) => j.string('name'));
      expect(users, equals(['Bob']));
    });

    test('asserts when non-primitive list has no mapper', () {
      final json = makeJson({
        'items': [1, 2],
      });

      expect(
        () => json.list<_CustomDto>('items'),
        throwsA(isA<AssertionError>()),
      );
    });

    test('validates primitive map with rules', () {
      final json = makeJson({
        'tags': {
          'color': 'red',
          'size': 'lg',
        },
      });

      final tags = json.map<String>('tags', rules: [.length(min: 2)]);
      expect(tags, equals({'color': 'red', 'size': 'lg'}));

      final badJson = makeJson({
        'tags': {
          'color': 'red',
          'size': 's',
        },
      });

      try {
        badJson.map<String>('tags', rules: [.length(min: 2)]);
        fail('Should have thrown ValidationErrors');
      } on ValidationErrors catch (e) {
        final errJson = e.toMap();
        expect(errJson['tags'], isA<Map<String, dynamic>>());
        final tagsErr = errJson['tags']! as Map<String, dynamic>;
        expect(tagsErr.containsKey('size'), isTrue);
      }
    });

    test('validates object map', () {
      final json = makeJson({
        'items': {
          'first': {'title': 'A'},
          'second': {'title': 'B'},
        },
      });

      final items = json.map<_ItemDto>('items', mapper: _ItemDto.fromJson);
      expect(items.keys, equals(['first', 'second']));
      expect(items['first']!.title, equals('A'));
      expect(items['second']!.title, equals('B'));

      final badJson = makeJson({
        'items': {
          'first': {'title': 'A'},
          'second': {'wrong': 'B'},
        },
      });

      try {
        badJson.map<_ItemDto>('items', mapper: _ItemDto.fromJson);
        fail('Should have thrown ValidationErrors');
      } on ValidationErrors catch (e) {
        final errJson = e.toMap();
        expect(errJson['items'], isA<Map<String, dynamic>>());
        final itemsErr = errJson['items']! as Map<String, dynamic>;
        expect(itemsErr.containsKey('second'), isTrue);
      }
    });

    test('accumulates errors across multiple fields via json.parse', () {
      final rawMap = {
        'username': 'usr',
        'email': 'invalid-email',
        'age': 15,
      };

      final jsonInst = makeJson(rawMap);
      try {
        jsonInst.parse(
          (j) => _UserDto(
            username: j.string('username', rules: [.length(min: 5)]),
            email: j.string('email', rules: [.email()]),
            age: j.integer('age', rules: [.range(min: 18)]),
          ),
        );
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final jsonResult = e.toMap();
        expect(jsonResult.containsKey('username'), isTrue);
        expect(jsonResult.containsKey('email'), isTrue);
        expect(jsonResult.containsKey('age'), isTrue);
      }
    });

    test(
      'accumulates errors across nested objects and lists via json.parse',
      () {
        final rawMap = {
          'address': {
            'zip': '12',
          },
          'items': [
            {'title': ''},
          ],
        };

        try {
          makeJson(rawMap).parse(
            (j) => _ComplexDto(
              address: j.object(
                'address',
                (sub) {
                  return _AddressDto(
                    zip: sub.string('zip', rules: [.length(min: 5)]),
                  );
                },
              ),
              items: j.list<_ItemDto>(
                'items',
                mapper: (sub) {
                  return _ItemDto(
                    title: sub.string('title', rules: [.length(min: 1)]),
                  );
                },
              ),
            ),
          );
          fail('Should throw ValidationErrors');
        } on ValidationErrors catch (e) {
          final serialized = e.toMap();
          expect(serialized.containsKey('address'), isTrue);
          expect(serialized.containsKey('items'), isTrue);
        }
      },
    );

    test(
      'nested object validation errors return dummy object to avoid TypeError',
      () {
        final rawMap1 = {
          'items': <Map<String, Object?>>[],
        };
        try {
          makeJson(rawMap1).parse(
            (j) => _ComplexDto(
              address: j.object(
                'address',
                (sub) => _AddressDto(zip: sub.string('zip')),
              ),
              items: j.list<_ItemDto>('items', mapper: _ItemDto.fromJson),
            ),
          );
          fail('Should throw ValidationErrors');
          // ignore: avoid_catching_errors
        } on TypeError catch (e) {
          fail('Should not throw TypeError: $e');
        } on ValidationErrors catch (e) {
          final serialized = e.toMap();
          expect(serialized.containsKey('address'), isTrue);
        }

        final rawMap2 = {
          'address': 'not-a-map',
          'items': <Map<String, Object?>>[],
        };
        try {
          makeJson(rawMap2).parse(
            (j) => _ComplexDto(
              address: j.object(
                'address',
                (sub) => _AddressDto(zip: sub.string('zip')),
              ),
              items: j.list<_ItemDto>('items', mapper: _ItemDto.fromJson),
            ),
          );
          fail('Should throw ValidationErrors');
          // ignore: avoid_catching_errors
        } on TypeError catch (e) {
          fail('Should not throw TypeError: $e');
        } on ValidationErrors catch (e) {
          final serialized = e.toMap();
          expect(serialized.containsKey('address'), isTrue);
        }

        final json = makeJson({});
        expect(
          () => json.object(
            'address',
            (sub) => _AddressDto(zip: sub.string('zip')),
          ),
          throwsA(isA<ValidationErrors>()),
        );
      },
    );

    test('type errors in list elements', () {
      final json = makeJson({
        'items': ['a', 2, 'c'],
        'objs': [
          {'title': 'A'},
          'not-an-obj',
        ],
      });

      try {
        json.list<String>('items');
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final errField = e.errors['items']! as ValidationErrorsField;
        expect(errField.errors.any((err) => err.code == 'type'), isTrue);
      }

      try {
        json.list<_ItemDto>('objs', mapper: _ItemDto.fromJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final errField = e.errors['objs']! as ValidationErrorsField;
        expect(errField.errors.any((err) => err.code == 'type'), isTrue);
      }
    });

    test('type errors in map elements', () {
      final json = makeJson({
        'items': {
          'first': 'a',
          'second': 2,
        },
        'objs': {
          'first': {'title': 'A'},
          'second': 'not-an-obj',
        },
      });

      try {
        json.map<String>('items');
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final errObj = e.errors['items']! as ValidationErrorsObject;
        expect(errObj.errors.errors.containsKey('second'), isTrue);
      }

      try {
        json.map<_ItemDto>('objs', mapper: _ItemDto.fromJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final errObj = e.errors['objs']! as ValidationErrorsObject;
        expect(errObj.errors.errors.containsKey('second'), isTrue);
      }
    });

    test('map primitive without mapper handles type errors', () {
      final json = makeJson({
        'map': {'a': 1},
      });
      try {
        json.map<String>('map');
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final err = e.errors['map']! as ValidationErrorsObject;
        expect(err.errors.errors.containsKey('a'), isTrue);
      }
    });

    test('deep object dummy fallback handling', () {
      final json = makeJson({
        'obj': {'nested': 1},
      });
      try {
        json.parse((j) {
          return j.object('obj', (sub1) {
            return sub1.object('nested', (sub2) {
              return sub2.string('foo');
            });
          });
        });
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final jsonResult = e.toMap();
        final obj = jsonResult['obj']! as Map<String, dynamic>;
        final nested = obj['nested']! as List<dynamic>;
        final firstErr = nested[0] as Map<String, dynamic>;
        expect(firstErr['code'], equals('type'));
      }
    });

    test('mapOrNull returns correctly', () {
      final json = makeJson({
        'map': {'a': 'b'},
      });
      expect(json.mapOrNull<String>('map'), equals({'a': 'b'}));
      expect(json.mapOrNull<String>('missing'), isNull);
    });
  });

  group('JsonObject Polymorphism', () {
    test('discriminated parses correctly for valid inputs', () {
      final docJson = makeJson({
        'type': 'doc',
        'doc_id': 'doc-1',
      });
      final doc = _FileDto.fromJson(docJson);
      expect(doc, isA<_DocDto>());
      expect((doc as _DocDto).docId, equals('doc-1'));

      final videoJson = makeJson({
        'type': 'video',
        'duration': 120,
      });
      final video = _FileDto.fromJson(videoJson);
      expect(video, isA<_VideoDto>());
      expect((video as _VideoDto).duration, equals(120));
    });

    test('discriminated throws on missing type field', () {
      final invalidJson = makeJson({'doc_id': 'doc-1'});
      try {
        _FileDto.fromJson(invalidJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final fieldErr = e.errors['type']! as ValidationErrorsField;
        expect(fieldErr.errors.first.code, equals('required'));
      }
    });

    test('discriminated throws on invalid discriminator value', () {
      final invalidJson = makeJson({'type': 'audio', 'doc_id': 'doc-1'});
      try {
        _FileDto.fromJson(invalidJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final fieldErr = e.errors['type']! as ValidationErrorsField;
        expect(fieldErr.errors.first.code, equals('invalid_discriminator'));
        expect(
          fieldErr.errors.first.params['expected'],
          unorderedEquals(['doc', 'video']),
        );
      }
    });

    test('discriminated passes errors from child correctly', () {
      final invalidJson = makeJson({
        'type': 'doc',
      });
      try {
        _FileDto.fromJson(invalidJson);
        fail('Should throw ValidationErrors');
      } on ValidationErrors catch (e) {
        final fieldErr = e.errors['doc_id']! as ValidationErrorsField;
        expect(fieldErr.errors.first.code, equals('required'));
      }
    });
  });

  group('JsonFieldExtractor', () {
    test('absent fields return JsonAbsent', () {
      final json = makeJson({});

      expect(json.field.string('missing').isPresent, isFalse);
      expect(json.field.stringOrNull('missing').isPresent, isFalse);

      final absent = json.field.string('missing');
      expect(absent.valueOrNull, isNull);
      expect(() => absent.value, throwsStateError);
    });

    test('strict methods throw when value is explicitly null', () {
      final json = makeJson({'name': null});

      expect(
        () => json.field.string('name'),
        throwsA(predicate<ValidationErrors>((e) => e.hasError('name'))),
      );
    });

    test(
      'optional methods return JsonPresent(null) when value is explicitly null',
      () {
        final json = makeJson({'avatar': null});

        final field = json.field.stringOrNull('avatar');
        expect(field.isPresent, isTrue);
        expect(field.value, isNull);
        expect(field.valueOrNull, isNull);
      },
    );

    test(
      'strict and optional methods return JsonPresent(value) when valid',
      () {
        final json = makeJson({'name': 'Abob', 'avatar': 'url'});

        final nameField = json.field.string('name');
        expect(nameField.isPresent, isTrue);
        expect(nameField.value, equals('Abob'));

        final avatarField = json.field.stringOrNull('avatar');
        expect(avatarField.isPresent, isTrue);
        expect(avatarField.value, equals('url'));
      },
    );

    test('enumeration fields work with extractor', () {
      final json = makeJson({'status': 'active', 'missing_status': null});

      final statusField = json.field.enumeration('status', _Status.values);
      expect(statusField.isPresent, isTrue);
      expect(statusField.value, equals(_Status.active));

      final missingField = json.field.enumerationOrNull(
        'absent',
        _Status.values,
      );
      expect(missingField.isPresent, isFalse);

      final nullField = json.field.enumerationOrNull(
        'missing_status',
        _Status.values,
      );
      expect(nullField.isPresent, isTrue);
      expect(nullField.value, isNull);
    });
  });
}

class _UserDto {
  _UserDto({
    required this.username,
    required this.email,
    required this.age,
  });

  final String username;
  final String email;
  final int age;
}

class _CustomDto {
  _CustomDto(this.id);

  final int id;
}

class _AddressDto {
  _AddressDto({required this.zip});

  final String zip;
}

class _ItemDto implements ToJson {
  _ItemDto({required this.title});

  _ItemDto.fromJson(JsonObject json) : title = json.string('title');

  final String title;

  @override
  void toJson(JsonWriter writer) => writer.string('title', title);
}

class _ComplexDto {
  _ComplexDto({required this.address, required this.items});

  final _AddressDto address;
  final List<_ItemDto> items;
}

sealed class _FileDto {
  static _FileDto fromJson(JsonObject json) {
    return json.discriminated('type', {
      'doc': _DocDto.fromJson,
      'video': _VideoDto.fromJson,
    });
  }
}

class _DocDto implements _FileDto {
  _DocDto.fromJson(JsonObject json) : docId = json.string('doc_id');

  final String docId;
}

class _VideoDto implements _FileDto {
  _VideoDto.fromJson(JsonObject json) : duration = json.integer('duration');

  final int duration;
}

enum _Status { active, inactive, pending }
