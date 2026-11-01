import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';
import 'package:test/scaffolding.dart';

import 'support.dart';

void main() {
  group('reading values', () {
    test('reads each type', () {
      const json = JsonObject({
        'string': 'Alice',
        'int': 25,
        'double': 98.5,
        'bool': true,
        'date': '2026-01-01T00:00:00.000Z',
        'ts': 1600000000,
        'uri': 'https://dart.dev',
        'status': 'active',
        'mapped': 'PENDING',
      });

      check(json.string('string')).equals('Alice');
      check(json.int('int')).equals(25);
      check(json.double('double')).equals(98.5);
      check(json.num('int')).equals(25);
      check(json.num('double')).equals(98.5);
      check(json.bool('bool')).isTrue();
      check(json.dateTime('date')).equals(DateTime.utc(2026));
      check(json.timestamp('ts', isSeconds: true).year).equals(2020);
      check(json.timestamp('ts').year).equals(1970);
      check(json.uri('uri').host).equals('dart.dev');
      check(json.enumeration('status', _Status.values)).equals(_Status.active);
      check(
        json.enumeration(
          'mapped',
          _Status.values,
          by: (e) => e.name.toUpperCase(),
        ),
      ).equals(_Status.pending);
      check(json.any('int')).equals(25);

      check(json.stringOrNull('string')).equals('Alice');
      check(json.intOrNull('int')).equals(25);
    });

    test('reads whole numbers as doubles', () {
      check(const JsonObject({'n': 1}).double('n')).equals(1);
    });

    test('exposes keys', () {
      check(const JsonObject({'a': 1, 'b': 'x'}).keys).deepEquals(['a', 'b']);
      check(const JsonObject({}).keys).isEmpty();
    });

    final optionalReads = <String, Object? Function(JsonObject json)>{
      'stringOrNull': (j) => j.stringOrNull('x'),
      'intOrNull': (j) => j.intOrNull('x'),
      'doubleOrNull': (j) => j.doubleOrNull('x'),
      'numOrNull': (j) => j.numOrNull('x'),
      'boolOrNull': (j) => j.boolOrNull('x'),
      'dateTimeOrNull': (j) => j.dateTimeOrNull('x'),
      'timestampOrNull': (j) => j.timestampOrNull('x'),
      'uriOrNull': (j) => j.uriOrNull('x'),
      'enumerationOrNull': (j) => j.enumerationOrNull('x', _Status.values),
      'objectOrNull': (j) => j.objectOrNull('x', (j) => j.string('y')),
      'listOrNull': (j) => j.listOrNull('x', .int),
      'mapOrNull': (j) => j.mapOrNull('x', .int),
      'anyOrNull': (j) => j.anyOrNull('x'),
    };

    for (final MapEntry(key: name, value: read) in optionalReads.entries) {
      test('$name returns null for absent and null values', () {
        check(read(const JsonObject({}))).isNull();
        check(read(const JsonObject({'x': null}))).isNull();
      });
    }

    final requiredReads = <String, Object? Function(JsonObject json)>{
      'string': (j) => j.string('x'),
      'int': (j) => j.int('x'),
      'double': (j) => j.double('x'),
      'num': (j) => j.num('x'),
      'bool': (j) => j.bool('x'),
      'dateTime': (j) => j.dateTime('x'),
      'timestamp': (j) => j.timestamp('x'),
      'uri': (j) => j.uri('x'),
      'enumeration': (j) => j.enumeration('x', _Status.values),
      'object': (j) => j.object('x', (j) => j.string('y')),
      'list': (j) => j.list('x', .int),
      'map': (j) => j.map('x', .int),
      'any': (j) => j.any('x'),
    };

    for (final MapEntry(key: name, value: read) in requiredReads.entries) {
      test('$name requires a non-null value', () {
        for (final json in const [
          JsonObject({}),
          JsonObject({'x': null}),
        ]) {
          check(() => read(json)).throwsValidation().deepEquals({
            'x': ['required'],
          });
        }
      });
    }

    final invalidReads =
        <String, (Object, Object? Function(JsonObject), String)>{
          'string': (1, (j) => j.string('x'), 'type'),
          'int': ('1', (j) => j.int('x'), 'type'),
          'int from double': (1.5, (j) => j.int('x'), 'type'),
          'double': ('1', (j) => j.double('x'), 'type'),
          'bool': (1, (j) => j.bool('x'), 'type'),
          'dateTime': (1, (j) => j.dateTime('x'), 'type'),
          'dateTime format': (
            'not-a-date',
            (j) => j.dateTime('x'),
            'date_time',
          ),
          'timestamp': ('1', (j) => j.timestamp('x'), 'type'),
          'uri': (1, (j) => j.uri('x'), 'type'),
          'uri format': ('no-scheme', (j) => j.uri('x'), 'url'),
          'enumeration': (1, (j) => j.enumeration('x', _Status.values), 'type'),
          'enumeration value': (
            'unknown',
            (j) => j.enumeration('x', _Status.values),
            'enum',
          ),
          'object': ('a', (j) => j.object('x', (j) => j.string('y')), 'type'),
          'list': ('a', (j) => j.list('x', .int), 'type'),
          'map': ('a', (j) => j.map('x', .int), 'type'),
        };

    for (final MapEntry(key: name, value: (value, read, code))
        in invalidReads.entries) {
      test('$name rejects $value with $code', () {
        check(
          () => read(JsonObject({'x': value})),
        ).throwsValidation().deepEquals({
          'x': [code],
        });
      });
    }

    final typeNames = <String, (Object, Object? Function(JsonObject), String)>{
      'integer': (1, (j) => j.string('x'), 'string'),
      'number': (1.5, (j) => j.int('x'), 'integer'),
      'boolean': (true, (j) => j.double('x'), 'number'),
      'array': (<Object?>[], (j) => j.bool('x'), 'boolean'),
      'object': (<String, Object?>{}, (j) => j.list('x', .any), 'array'),
      'string': ('a', (j) => j.map('x', .any), 'object'),
    };

    for (final MapEntry(key: actual, value: (value, read, expected))
        in typeNames.entries) {
      test('type errors name $expected and $actual like JSON Schema', () {
        check(() => read(JsonObject({'x': value})))
            .throws<ValidationErrors>()
            .has((e) => e.errors['x']!.single.params, 'params')
            .deepEquals({'expected': expected, 'actual': actual});
      });
    }

    test('enum errors list the accepted values', () {
      check(
            () => const JsonObject({
              'x': 'unknown',
            }).enumeration('x', _Status.values),
          )
          .throws<ValidationErrors>()
          .has((e) => e.errors['x']!.single.params['expected'], 'expected')
          .isA<List<Object?>>()
          .deepEquals(['active', 'inactive', 'pending']);
    });
  });

  group('rules', () {
    test('accept valid values', () {
      const json = JsonObject({'name': 'Alice', 'age': 25});

      check(
        json.string('name', rules: [.length(min: 2, max: 10)]),
      ).equals('Alice');
      check(json.int('age', rules: [.range(min: 18)])).equals(25);
    });

    test('report every failed rule of a field', () {
      check(
        () => const JsonObject({
          'pass': 'abc',
        }).string('pass', rules: [.length(min: 8), .contains('!')]),
      ).throwsValidation().deepEquals({
        'pass': ['length', 'contains'],
      });
    });

    test('apply to present optional values only', () {
      const json = JsonObject({'age': 15});

      check(json.intOrNull('missing', rules: [.range(min: 18)])).isNull();
      check(
        () => json.intOrNull('age', rules: [.range(min: 18)]),
      ).throwsValidation().deepEquals({
        'age': ['range'],
      });
    });

    test('of uri apply to the string before parsing', () {
      check(
        () => const JsonObject({
          'link': 'https://dart.dev',
        }).uri('link', rules: [.length(max: 5)]),
      ).throwsValidation().deepEquals({
        'link': ['length'],
      });
    });
  });

  group('objects', () {
    test('parse nested values with the mapper', () {
      const json = JsonObject({
        'address': {'zip': '12345'},
      });

      check(
        json.object('address', _AddressDto.fromJson).zip,
      ).equals('12345');
    });

    test('prefix nested errors with the field path', () {
      const json = JsonObject({
        'obj': {
          'nested': {'zip': 1},
        },
      });

      check(
        () => json.object(
          'obj',
          (j) => j.object('nested', _AddressDto.fromJson),
        ),
      ).throwsValidation().deepEquals({
        'obj.nested.zip': ['type'],
      });
    });
  });

  group('lists', () {
    test('read primitive items', () {
      const json = JsonObject({
        'tags': ['dart', 'flutter'],
        'xs': [1, 2.5],
        'mixed': ['a', 1, true],
      });

      check(json.list('tags', .string)).deepEquals(['dart', 'flutter']);
      check(json.list('xs', .double)).deepEquals([1.0, 2.5]);
      check(json.list('xs', .num)).deepEquals([1, 2.5]);
      check(json.list('mixed', .any)).deepEquals(['a', 1, true]);
    });

    test('accept null items only for nullable item types', () {
      const json = JsonObject({
        'tags': ['a', null],
      });

      check(json.list('tags', .string.orNull)).deepEquals(['a', null]);
      check(
        () => json.list('tags', .string),
      ).throwsValidation().deepEquals({
        'tags.1': ['required'],
      });
    });

    test('report item errors at the item path', () {
      const json = JsonObject({
        'items': ['a', 2, 'c'],
        'tags': ['dart', 'go'],
      });

      check(
        () => json.parse((j) => j.list('items', .string)),
      ).throwsValidation().deepEquals({
        'items.1': ['type'],
      });
      check(
        () => json.parse(
          (j) => j.list('tags', .string.where([.length(min: 3)])),
        ),
      ).throwsValidation().deepEquals({
        'tags.1': ['length'],
      });
    });

    test('parse object items with the mapper', () {
      const json = JsonObject({
        'items': [
          {'title': 'A'},
          {'title': 'B'},
        ],
      });

      check(
        json.list('items', .object(_ItemDto.fromJson)).map((i) => i.title),
      ).deepEquals(['A', 'B']);
    });

    test('report object item errors at the item path', () {
      const json = JsonObject({
        'items': [
          {'title': 'A'},
          {'wrong': 'B'},
          'not-an-object',
        ],
      });

      check(
        () => json.parse((j) => j.list('items', .object(_ItemDto.fromJson))),
      ).throwsValidation().deepEquals({
        'items.1.title': ['required'],
        'items.2': ['type'],
      });
    });
  });

  group('maps', () {
    test('read primitive and object values', () {
      const json = JsonObject({
        'tags': {'color': 'red'},
        'items': {
          'first': {'title': 'A'},
        },
      });

      check(json.map('tags', .string)).deepEquals({'color': 'red'});
      check(
        json.map('items', .object(_ItemDto.fromJson))['first']?.title,
      ).equals('A');
    });

    test('report value errors at the key path', () {
      const json = JsonObject({
        'tags': {'color': 'red', 'size': 's', 'weight': 1},
        'items': {
          'first': {'title': 'A'},
          'second': {'wrong': 'B'},
          'third': 'not-an-object',
        },
      });

      check(
        () => json.parse(
          (j) => (
            j.map('tags', .string.where([.length(min: 2)])),
            j.map('items', .object(_ItemDto.fromJson)),
          ),
        ),
      ).throwsValidation().deepEquals({
        'tags.size': ['length'],
        'tags.weight': ['type'],
        'items.second.title': ['required'],
        'items.third': ['type'],
      });
    });
  });

  group('discriminated', () {
    test('works as a list item type', () {
      const json = JsonObject({
        'files': [
          {'type': 'doc', 'doc_id': 'd1'},
          {'type': 'video'},
        ],
      });

      check(
        () => json.parse(
          (j) => j.list(
            'files',
            .discriminated('type', {
              'doc': _DocDto.fromJson,
              'video': _VideoDto.fromJson,
            }),
          ),
        ),
      ).throwsValidation().deepEquals({
        'files.1.duration': ['required'],
      });
    });

    test('parses with the mapper of the tag', () {
      check(
        _FileDto.fromJson(const JsonObject({'type': 'doc', 'doc_id': 'd1'})),
      ).isA<_DocDto>().has((d) => d.docId, 'docId').equals('d1');
      check(
        _FileDto.fromJson(const JsonObject({'type': 'video', 'duration': 1})),
      ).isA<_VideoDto>().has((v) => v.duration, 'duration').equals(1);
    });

    test('rejects a missing or unknown tag', () {
      check(
        () => _FileDto.fromJson(const JsonObject({'doc_id': 'd1'})),
      ).throwsValidation().deepEquals({
        'type': ['required'],
      });
      check(() => _FileDto.fromJson(const JsonObject({'type': 'audio'})))
          .throws<ValidationErrors>()
          .has((e) => e.errors['type']!.single, 'type error')
          .which(
            (it) => it
              ..has((e) => e.code, 'code').equals('discriminator')
              ..has(
                (e) => e.params['expected'],
                'expected',
              ).isA<List<Object?>>().deepEquals(['doc', 'video']),
          );
    });

    test('reports variant errors at the object path', () {
      const json = JsonObject({
        'file': {'type': 'doc'},
      });

      check(
        () => json.parse(
          (j) => (j.string('name'), j.object('file', _FileDto.fromJson)),
        ),
      ).throwsValidation().deepEquals({
        'name': ['required'],
        'file.doc_id': ['required'],
      });
    });
  });

  group('error collection', () {
    const invalidUser = JsonObject({
      'username': 'usr',
      'email': 'invalid-email',
      'age': 15,
    });

    test('parse collects the errors of every field', () {
      check(
        () => invalidUser.parse(_UserDto.fromJson),
      ).throwsValidation().deepEquals({
        'username': ['length'],
        'email': ['email'],
        'age': ['range'],
      });
    });

    test('direct reads throw on the first error', () {
      check(() => _UserDto.fromJson(invalidUser)).throwsValidation().deepEquals(
        {
          'username': ['length'],
        },
      );
    });

    test('parse collects errors across nested objects and lists', () {
      const json = JsonObject({
        'address': {'zip': '12'},
        'items': [
          {'title': ''},
        ],
      });

      check(
        () => json.parse(
          (j) => (
            j.object(
              'address',
              (j) => j.string('zip', rules: [.length(min: 5)]),
            ),
            j.list(
              'items',
              .object((j) => j.string('title', rules: [.length(min: 1)])),
            ),
          ),
        ),
      ).throwsValidation().deepEquals({
        'address.zip': ['length'],
        'items.0.title': ['length'],
      });
    });

    test('parse goes on after a failed object', () {
      for (final address in [null, 'not-an-object', <String, Object?>{}]) {
        check(
          () => JsonObject({'address': address}).parse(
            (j) => (
              j.object('address', _AddressDto.fromJson),
              j.string('name'),
            ),
          ),
        ).throwsValidation().has((e) => e.keys, 'paths').deepEquals([
          if (address is Map) 'address.zip' else 'address',
          'name',
        ]);
      }
    });

    test('parse reports field errors when the mapper rejects placeholders', () {
      const json = JsonObject({
        'users': [
          {'email': 'a@b.c'},
          {'email': 1},
        ],
      });

      check(
        () => const JsonObject({}).parse((j) => _Email(j.string('email'))),
      ).throwsValidation().deepEquals({
        'email': ['required'],
      });
      check(
        () => json.parse(
          (j) => (
            j.list('users', .object((j) => _Email(j.string('email')))),
            j.string('name'),
          ),
        ),
      ).throwsValidation().deepEquals({
        'users.1.email': ['type'],
        'name': ['required'],
      });
    });

    test('nested parse joins the enclosing parse', () {
      check(
        () => const JsonObject({'address': <String, Object?>{}}).parse(
          (j) => (
            j.object('address', (j) => j.parse(_AddressDto.fromJson)),
            j.string('name'),
          ),
        ),
      ).throwsValidation().deepEquals({
        'address.zip': ['required'],
        'name': ['required'],
      });
    });

    test('parse rethrows mapper errors that no field caused', () {
      check(
        () => const JsonObject({
          'email': 'nope',
        }).parse((j) => _Email(j.string('email'))),
      ).throws<ArgumentError>();
    });

    test('mapper validation errors join at the object path', () {
      const json = JsonObject({
        'promo': {'code': 'TAKEN'},
      });

      String uniqueCode(JsonObject j) {
        final code = j.string('code');
        if (code == 'TAKEN') {
          throw ValidationErrors()
            ..add('code', const ValidationError(code: 'taken'));
        }
        return code;
      }

      check(
        () => json.parse((j) => (j.object('promo', uniqueCode), j.int('n'))),
      ).throwsValidation().deepEquals({
        'promo.code': ['taken'],
        'n': ['required'],
      });
      check(
        () => json.object('promo', uniqueCode),
      ).throwsValidation().deepEquals({
        'promo.code': ['taken'],
      });
    });
  });

  group('JsonFieldExtractor', () {
    test('tells absent, null and present values apart', () {
      const json = JsonObject({'avatar': null, 'name': 'Bob'});

      final absent = json.field.stringOrNull('missing');
      check(absent.isPresent).isFalse();
      check(absent.valueOrNull).isNull();
      check(() => absent.value).throws<StateError>();

      final explicitNull = json.field.stringOrNull('avatar');
      check(explicitNull.isPresent).isTrue();
      check(explicitNull.value).isNull();

      final present = json.field.string('name');
      check(present.isPresent).isTrue();
      check(present.value).equals('Bob');
    });

    test('required reads reject explicit null', () {
      check(
        () => const JsonObject({'name': null}).field.string('name'),
      ).throwsValidation().deepEquals({
        'name': ['required'],
      });
    });

    test('works with every getter', () {
      const json = JsonObject({'status': 'active', 'tags': <Object?>[]});

      check(
        json.field.enumeration('status', _Status.values).value,
      ).equals(_Status.active);
      check(json.field.list('tags', .string).value).isEmpty();
      check(json.field.read('status', JsonType.string).value).equals('active');
      check(
        json.field.readOrNull('missing', JsonType.string).isPresent,
      ).isFalse();
    });
  });
}

class _UserDto {
  _UserDto.fromJson(JsonObject json)
    : username = json.string('username', rules: [.length(min: 5)]),
      email = json.string('email', rules: [.email()]),
      age = json.int('age', rules: [.range(min: 18)]);

  final String username;
  final String email;
  final int age;
}

class _AddressDto {
  _AddressDto.fromJson(JsonObject json) : zip = json.string('zip');

  final String zip;
}

class _ItemDto {
  _ItemDto.fromJson(JsonObject json) : title = json.string('title');

  final String title;
}

class _Email {
  _Email(this.value) {
    if (!value.contains('@')) throw ArgumentError.value(value, 'value');
  }

  final String value;
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
  _VideoDto.fromJson(JsonObject json) : duration = json.int('duration');

  final int duration;
}

enum _Status { active, inactive, pending }
