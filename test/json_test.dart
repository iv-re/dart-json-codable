import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('JsonObject Primitives', () {
    test('validates string field with rules', () {
      const json = JsonObject({
        'name': 'Alice',
        'email': 'alice@example.com',
      });

      final name = json.string('name', rules: [.length(min: 2, max: 10)]);
      check(name).equals('Alice');

      check(
        () => json.string('email', rules: [.length(max: 5)]),
      ).throws<ValidationErrors>();
    });

    test('exposes keys of the json object', () {
      const json = JsonObject({
        'a': 1,
        'b': 'test',
        'c': true,
      });
      check(json.keys).deepEquals(['a', 'b', 'c']);

      const emptyJson = JsonObject({});
      check(emptyJson.keys).isEmpty();
    });

    test('validates integer, float, boolean, dateTime, timestamp, uri', () {
      const json = JsonObject({
        'age': 25,
        'score': 98.5,
        'active': true,
        'date': '2026-01-01T00:00:00.000Z',
        'ts': 1600000000,
        'link': 'https://dart.dev',
      });

      check(json.integer('age', rules: [.range(min: 18)])).equals(25);
      check(json.integerOrNull('missing')).isNull();

      check(json.float('score', rules: [.range(min: 50.0)])).equals(98.5);
      check(json.floatOrNull('missing')).isNull();

      check(json.boolean('active')).isTrue();
      check(json.booleanOrNull('missing')).isNull();

      check(json.dateTime('date').year).equals(2026);
      check(json.dateTimeOrNull('missing')).isNull();

      check(json.timestamp('ts', isSeconds: true).year).equals(2020);
      check(json.timestampOrNull('missing')).isNull();

      check(json.uri('link').host).equals('dart.dev');
      check(json.uriOrNull('missing')).isNull();

      check(json.any('age')).equals(25);
      check(json.any('active')).equals(true);
      check(json.anyOrNull('missing')).isNull();
    });

    test('parses enumeration', () {
      const json = JsonObject({
        'status': 'active',
        'mapped_status': 'PENDING',
      });

      check(json.enumeration('status', _Status.values)).equals(_Status.active);
      check(
        json.enumeration(
          'mapped_status',
          _Status.values,
          by: (e) => e.name.toUpperCase(),
        ),
      ).equals(_Status.pending);

      check(json.enumerationOrNull('missing', _Status.values)).isNull();
    });

    test('throws error on invalid enumeration', () {
      const json = JsonObject({'status': 'unknown'});
      check(() => json.enumeration('status', _Status.values))
          .throws<ValidationErrors>()
          .has((e) => e.errors['status'], 'status error')
          .isNotNull()
          .first
          .has((e) => e.code, 'code')
          .equals('invalid_enum');
    });

    test('throws error on missing required field', () {
      const json = JsonObject({});
      check(() => json.string('missing'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('missing'), 'hasError')
          .isTrue();
    });

    test('accumulates all failed rules for a single field', () {
      const json = JsonObject({'pass': 'abc'});

      check(() => json.string('pass', rules: [.length(min: 8), .contains('!')]))
          .throws<ValidationErrors>()
          .has((e) => e.errors['pass'], 'pass errors')
          .isNotNull()
          .which(
            (it) => it
              ..length.equals(2)
              ..first.has((e) => e.code, 'code').equals('length')
              ..last.has((e) => e.code, 'code').equals('contains'),
          );
    });

    test('primitive type errors', () {
      const json = JsonObject({
        'str': 123,
        'int': 'abc',
        'float': 'abc',
        'bool': 1,
        'date': 123,
        'uri': 123,
      });

      check(() => json.string('str'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('str'), 'hasError str')
          .isTrue();
      check(() => json.integer('int'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('int'), 'hasError int')
          .isTrue();
      check(() => json.float('float'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('float'), 'hasError float')
          .isTrue();
      check(() => json.boolean('bool'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('bool'), 'hasError bool')
          .isTrue();
      check(() => json.dateTime('date'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('date'), 'hasError date')
          .isTrue();
      check(() => json.uri('uri'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('uri'), 'hasError uri')
          .isTrue();
    });

    test('primitive parse and validation errors', () {
      const json = JsonObject({
        'date': 'invalid-date',
        'uri': 'invalid-uri',
      });

      check(() => json.dateTime('date'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('date'), 'hasError date')
          .isTrue();
      check(() => json.uri('uri'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('uri'), 'hasError uri')
          .isTrue();
    });

    test('OrNull branches return valid data', () {
      const json = JsonObject({
        'str': 'hello',
        'int': 42,
        'float': 42.5,
        'bool': true,
        'date': '2026-01-01T00:00:00.000Z',
        'ts': 1600000000,
        'uri': 'https://dart.dev',
      });

      check(json.stringOrNull('str')).equals('hello');
      check(json.integerOrNull('int')).equals(42);
      check(json.floatOrNull('float')).equals(42.5);
      check(json.booleanOrNull('bool')).isNotNull().isTrue();
      check(
        json.dateTimeOrNull('date'),
      ).isNotNull().has((d) => d.year, 'year').equals(2026);
      check(
        json.timestampOrNull('ts', isSeconds: true),
      ).isNotNull().has((d) => d.year, 'year').equals(2020);
      check(
        json.uriOrNull('uri'),
      ).isNotNull().has((u) => u.host, 'host').equals('dart.dev');
    });
  });

  group('JsonObject Nested Structures (object, list, map)', () {
    test('validates primitive lists', () {
      const json = JsonObject({
        'tags': ['dart', 'flutter'],
      });

      final tags = json.list<String>('tags', rules: [.length(min: 3)]);
      check(tags).deepEquals(['dart', 'flutter']);
      check(json.listOrNull<String>('missing')).isNull();
    });

    test('validates list of nested objects', () {
      const json = JsonObject({
        'users': [
          {'name': 'Bob'},
        ],
      });

      final users = json.list<String>('users', mapper: (j) => j.string('name'));
      check(users).deepEquals(['Bob']);
    });

    test('asserts when non-primitive list has no mapper', () {
      const json = JsonObject({
        'items': [1, 2],
      });

      check(() => json.list<_CustomDto>('items')).throws<AssertionError>();
    });

    test('validates primitive map with rules', () {
      const json = JsonObject({
        'tags': {
          'color': 'red',
          'size': 'lg',
        },
      });

      final tags = json.map<String>('tags', rules: [.length(min: 2)]);
      check(tags).deepEquals({'color': 'red', 'size': 'lg'});

      const badJson = JsonObject({
        'tags': {
          'color': 'red',
          'size': 's',
        },
      });

      check(() => badJson.map<String>('tags', rules: [.length(min: 2)]))
          .throws<ValidationErrors>()
          .has((e) => e.toJson(), 'toJson')
          .containsKey('tags.size');
    });

    test('validates object map', () {
      const json = JsonObject({
        'items': {
          'first': {'title': 'A'},
          'second': {'title': 'B'},
        },
      });

      final items = json.map<_ItemDto>('items', mapper: _ItemDto.fromJson);
      check(items.keys).deepEquals(['first', 'second']);
      check(
        items['first'],
      ).isNotNull().has((i) => i.title, 'title').equals('A');
      check(
        items['second'],
      ).isNotNull().has((i) => i.title, 'title').equals('B');

      const badJson = JsonObject({
        'items': {
          'first': {'title': 'A'},
          'second': {'wrong': 'B'},
        },
      });

      check(() => badJson.map<_ItemDto>('items', mapper: _ItemDto.fromJson))
          .throws<ValidationErrors>()
          .has((e) => e.toJson(), 'toJson')
          .containsKey('items.second.title');
    });

    test('accumulates errors across multiple fields via json.parse', () {
      final rawMap = {
        'username': 'usr',
        'email': 'invalid-email',
        'age': 15,
      };

      final jsonInst = JsonObject(rawMap);
      check(
            () => jsonInst.parse(
              (j) => _UserDto(
                username: j.string('username', rules: [.length(min: 5)]),
                email: j.string('email', rules: [.email()]),
                age: j.integer('age', rules: [.range(min: 18)]),
              ),
            ),
          )
          .throws<ValidationErrors>()
          .has((e) => e.toJson(), 'toJson')
          .which(
            (it) => it
              ..containsKey('username')
              ..containsKey('email')
              ..containsKey('age'),
          );
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

        check(
              () => JsonObject(rawMap).parse(
                (j) => _ComplexDto(
                  address: j.object(
                    'address',
                    (sub) => _AddressDto(
                      zip: sub.string('zip', rules: [.length(min: 5)]),
                    ),
                  ),
                  items: j.list<_ItemDto>(
                    'items',
                    mapper: (sub) => _ItemDto(
                      title: sub.string('title', rules: [.length(min: 1)]),
                    ),
                  ),
                ),
              ),
            )
            .throws<ValidationErrors>()
            .has((e) => e.toJson(), 'toJson')
            .which(
              (it) => it
                ..containsKey('address.zip')
                ..containsKey('items.0.title'),
            );
      },
    );

    test(
      'nested object validation errors return dummy object to avoid TypeError',
      () {
        final rawMap1 = {
          'items': <Map<String, Object?>>[],
        };
        check(
              () => JsonObject(rawMap1).parse(
                (j) => _ComplexDto(
                  address: j.object(
                    'address',
                    (sub) => _AddressDto(zip: sub.string('zip')),
                  ),
                  items: j.list<_ItemDto>('items', mapper: _ItemDto.fromJson),
                ),
              ),
            )
            .throws<ValidationErrors>()
            .has((e) => e.toJson(), 'toJson')
            .containsKey('address');

        final rawMap2 = {
          'address': 'not-a-map',
          'items': <Map<String, Object?>>[],
        };
        check(
              () => JsonObject(rawMap2).parse(
                (j) => _ComplexDto(
                  address: j.object(
                    'address',
                    (sub) => _AddressDto(zip: sub.string('zip')),
                  ),
                  items: j.list<_ItemDto>('items', mapper: _ItemDto.fromJson),
                ),
              ),
            )
            .throws<ValidationErrors>()
            .has((e) => e.toJson(), 'toJson')
            .containsKey('address');

        const json = JsonObject({});
        check(
          () => json.object(
            'address',
            (sub) => _AddressDto(zip: sub.string('zip')),
          ),
        ).throws<ValidationErrors>();
      },
    );

    test('type errors in list elements', () {
      const json = JsonObject({
        'items': ['a', 2, 'c'],
        'objs': [
          {'title': 'A'},
          'not-an-obj',
        ],
      });

      check(() => json.list<String>('items'))
          .throws<ValidationErrors>()
          .has((e) => e.errors['items'], 'items error')
          .isNotNull()
          .any((err) => err.has((e) => e.code, 'code').equals('type'));

      check(() => json.list<_ItemDto>('objs', mapper: _ItemDto.fromJson))
          .throws<ValidationErrors>()
          .has((e) => e.errors['objs'], 'objs error')
          .isNotNull()
          .any((err) => err.has((e) => e.code, 'code').equals('type'));
    });

    test('type errors in map elements', () {
      const json = JsonObject({
        'items': {
          'first': 'a',
          'second': 2,
        },
        'objs': {
          'first': {'title': 'A'},
          'second': 'not-an-obj',
        },
      });

      check(() => json.map<String>('items'))
          .throws<ValidationErrors>()
          .has((e) => e.errors, 'errors')
          .containsKey('items.second');

      check(() => json.map<_ItemDto>('objs', mapper: _ItemDto.fromJson))
          .throws<ValidationErrors>()
          .has((e) => e.errors, 'errors')
          .containsKey('objs.second');
    });

    test('map primitive without mapper handles type errors', () {
      const json = JsonObject({
        'map': {'a': 1},
      });
      check(() => json.map<String>('map'))
          .throws<ValidationErrors>()
          .has((e) => e.errors, 'errors')
          .containsKey('map.a');
    });

    test('deep object dummy fallback handling', () {
      const json = JsonObject({
        'obj': {'nested': 1},
      });
      check(
            () => json.parse((j) {
              return j.object('obj', (sub1) {
                return sub1.object('nested', (sub2) {
                  return sub2.string('foo');
                });
              });
            }),
          )
          .throws<ValidationErrors>()
          .has((e) => e.toJson(), 'toJson')
          .has((m) => m['obj.nested']! as List, 'obj.nested')
          .first
          .isA<Map<String, dynamic>>()
          .has((m) => m['code'], 'code')
          .equals('type');
    });

    test('mapOrNull returns correctly', () {
      const json = JsonObject({
        'map': {'a': 'b'},
      });
      check(json.mapOrNull<String>('map')).isNotNull().deepEquals({'a': 'b'});
      check(json.mapOrNull<String>('missing')).isNull();
    });
  });

  group('JsonObject Polymorphism', () {
    test('discriminated parses correctly for valid inputs', () {
      const docJson = JsonObject({
        'type': 'doc',
        'doc_id': 'doc-1',
      });
      final doc = _FileDto.fromJson(docJson);
      check(doc).isA<_DocDto>().has((d) => d.docId, 'docId').equals('doc-1');

      const videoJson = JsonObject({
        'type': 'video',
        'duration': 120,
      });
      final video = _FileDto.fromJson(videoJson);
      check(
        video,
      ).isA<_VideoDto>().has((v) => v.duration, 'duration').equals(120);
    });

    test('discriminated throws on missing type field', () {
      const invalidJson = JsonObject({'doc_id': 'doc-1'});
      check(() => _FileDto.fromJson(invalidJson))
          .throws<ValidationErrors>()
          .has((e) => e.errors['type'], 'type error')
          .isNotNull()
          .first
          .has((e) => e.code, 'code')
          .equals('required');
    });

    test('discriminated throws on invalid discriminator value', () {
      const invalidJson = JsonObject({'type': 'audio', 'doc_id': 'doc-1'});
      check(() => _FileDto.fromJson(invalidJson))
          .throws<ValidationErrors>()
          .has((e) => e.errors['type'], 'type error')
          .isNotNull()
          .first
          .which(
            (it) => it
              ..has((e) => e.code, 'code').equals('invalid_discriminator')
              ..has(
                (e) => e.params['expected']! as List,
                'expected',
              ).unorderedEquals(['doc', 'video']),
          );
    });

    test('discriminated passes errors from child correctly', () {
      const invalidJson = JsonObject({
        'type': 'doc',
      });
      check(() => _FileDto.fromJson(invalidJson))
          .throws<ValidationErrors>()
          .has((e) => e.errors['doc_id'], 'doc_id error')
          .isNotNull()
          .first
          .has((e) => e.code, 'code')
          .equals('required');
    });
  });

  group('JsonFieldExtractor', () {
    test('absent fields return JsonAbsent', () {
      const json = JsonObject({});

      check(json.field.string('missing').isPresent).isFalse();
      check(json.field.stringOrNull('missing').isPresent).isFalse();

      final absent = json.field.string('missing');
      check(absent.valueOrNull).isNull();
      check(() => absent.value).throws<StateError>();
    });

    test('strict methods throw when value is explicitly null', () {
      const json = JsonObject({'name': null});

      check(() => json.field.string('name'))
          .throws<ValidationErrors>()
          .has((e) => e.hasError('name'), 'hasError name')
          .isTrue();
    });

    test(
      'optional methods return JsonPresent(null) when value is explicitly null',
      () {
        const json = JsonObject({'avatar': null});

        final field = json.field.stringOrNull('avatar');
        check(field.isPresent).isTrue();
        check(field.value).isNull();
        check(field.valueOrNull).isNull();
      },
    );

    test(
      'strict and optional methods return JsonPresent(value) when valid',
      () {
        const json = JsonObject({'name': 'Abob', 'avatar': 'url'});

        final nameField = json.field.string('name');
        check(nameField.isPresent).isTrue();
        check(nameField.value).equals('Abob');

        final avatarField = json.field.stringOrNull('avatar');
        check(avatarField.isPresent).isTrue();
        check(avatarField.value).equals('url');
      },
    );

    test('enumeration fields work with extractor', () {
      const json = JsonObject({'status': 'active', 'missing_status': null});

      final statusField = json.field.enumeration('status', _Status.values);
      check(statusField.isPresent).isTrue();
      check(statusField.value).equals(_Status.active);

      final missingField = json.field.enumerationOrNull(
        'absent',
        _Status.values,
      );
      check(missingField.isPresent).isFalse();

      final nullField = json.field.enumerationOrNull(
        'missing_status',
        _Status.values,
      );
      check(nullField.isPresent).isTrue();
      check(nullField.value).isNull();
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
  Map<String, Object?> toJson() => {'title': title};
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
