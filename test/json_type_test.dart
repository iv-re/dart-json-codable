// ignore_for_file: avoid_dynamic_calls

import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';
import 'package:test/scaffolding.dart';

import 'support.dart';

void main() {
  group('JsonType', () {
    final userId = JsonType.string.convert(
      (value, reader) => value.startsWith('u_')
          ? _UserId(value)
          : reader.fail(const ValidationError(code: 'user_id')),
      placeholder: const _UserId(''),
      schema: Schema.string(pattern: '^u_'),
    );

    test('convert builds custom types', () {
      check(
        const JsonObject({'id': 'u_1'}).read('id', userId).value,
      ).equals('u_1');
      check(
        () => const JsonObject({'id': '1'}).read('id', userId),
      ).throwsValidation().deepEquals({
        'id': ['user_id'],
      });
      check(
        () => const JsonObject({'id': 1}).read('id', userId),
      ).throwsValidation().deepEquals({
        'id': ['type'],
      });
    });

    test('custom types work in collections, schema and field', () {
      const json = JsonObject({
        'ids': ['u_1', '2'],
      });

      check(
        () => json.parse((j) => j.read('ids', JsonType.list(userId))),
      ).throwsValidation().deepEquals({
        'ids.1': ['user_id'],
      });
      check(json.field.readOrNull('missing', userId).isPresent).isFalse();

      final dynamic schema = JsonObject.schema((j) => j.read('id', userId));
      check(schema['properties']['id']['pattern']).equals('^u_');
    });

    test('where adds rules to values and schema', () {
      final percent = JsonType.int.where([.range(min: 0, max: 100)]);

      check(
        () => const JsonObject({'p': 101}).read('p', percent),
      ).throwsValidation().deepEquals({
        'p': ['range'],
      });

      final dynamic schema = JsonObject.schema((j) => j.read('p', percent));
      check(schema['properties']['p']['maximum']).equals(100);
    });

    test('orNull accepts null', () {
      const json = JsonObject({
        'ids': [1, null],
      });

      check(
        json.read('ids', JsonType.list(JsonType.int.orNull)),
      ).deepEquals([1, null]);
    });
  });

  group('JsonSource.text', () {
    JsonObject text(Map<String, Object?> map) => JsonObject(map, source: .text);

    test('converts strings to the requested type', () {
      final json = text({
        'phone': '+79991234567',
        'zip': '007',
        'q': 'true',
        'page': '-2',
        'price': '1.5e2',
        'flag': 'false',
        'date': '2026-01-01',
        'status': 'active',
        'link': 'https://dart.dev',
      });

      check(json.string('phone')).equals('+79991234567');
      check(json.string('zip')).equals('007');
      check(json.string('q')).equals('true');
      check(json.int('page')).equals(-2);
      check(json.double('price')).equals(150);
      check(json.bool('flag')).isFalse();
      check(json.dateTime('date')).equals(DateTime(2026));
      check(json.enumeration('status', _Status.values)).equals(_Status.active);
      check(json.uri('link').host).equals('dart.dev');
    });

    final invalid = {
      'hex integer': ('0x1F', (JsonObject j) => j.int('x')),
      'plus sign': ('+5', (JsonObject j) => j.int('x')),
      '64-bit overflow': (
        '99999999999999999999',
        (JsonObject j) => j.int('x'),
      ),
      'exponent integer': ('1e3', (JsonObject j) => j.int('x')),
      'infinity': ('-Infinity', (JsonObject j) => j.double('x')),
      'NaN': ('NaN', (JsonObject j) => j.double('x')),
      'numeric boolean': ('1', (JsonObject j) => j.bool('x')),
      'capitalized boolean': ('True', (JsonObject j) => j.bool('x')),
    };

    for (final MapEntry(key: name, value: (value, read)) in invalid.entries) {
      test('rejects $name', () {
        check(() => read(text({'x': value}))).throwsValidation().deepEquals({
          'x': ['type'],
        });
      });
    }

    test('treats empty values as absent except for strings', () {
      final json = text({'topic_id': '', 'status': '', 'q': ''});

      check(json.intOrNull('topic_id')).isNull();
      check(json.enumerationOrNull('status', _Status.values)).isNull();
      check(json.stringOrNull('q')).equals('');
      check(json.field.intOrNull('topic_id').isPresent).isTrue();
      check(() => json.int('topic_id')).throwsValidation().deepEquals({
        'topic_id': ['required'],
      });
    });

    test('accepts a single value where a list is expected', () {
      final json = text({
        'one': '1',
        'many': ['1', '2'],
      });

      check(json.list('one', .int)).deepEquals([1]);
      check(json.list('many', .int)).deepEquals([1, 2]);
    });

    test('reports item errors at the item path', () {
      check(
        () => text({
          'ids': ['1', 'x'],
        }).parse((j) => j.list('ids', .int)),
      ).throwsValidation().deepEquals({
        'ids.1': ['type'],
      });
    });

    test('converts values of nested objects', () {
      final json = text({
        'filter': {'min': '1', 'max': '5'},
      });

      check(
        json.object('filter', (j) => (j.int('min'), j.int('max'))),
      ).equals((1, 5));
    });

    test('leaves values of JSON sources unconverted', () {
      check(
        () => const JsonObject({'page': '2'}).int('page'),
      ).throwsValidation().deepEquals({
        'page': ['type'],
      });
      check(
        () => const JsonObject({'ids': 1}).list('ids', .int),
      ).throwsValidation().deepEquals({
        'ids': ['type'],
      });
    });
  });
}

class _UserId {
  const _UserId(this.value);

  final String value;
}

enum _Status { active, inactive }
