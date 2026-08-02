// ignore_for_file: avoid_dynamic_calls

import 'package:json_codable/json_codable.dart';
import 'package:test/test.dart';

void main() {
  group('JsonObject.schema', () {
    test('generates basic object schema', () {
      final dynamic schema = JsonObject.schema(
        (j) => {
          'id': j.integer('id'),
          'name': j.string('name'),
          'isActive': j.boolean('isActive'),
          'tag': j.any('tag'),
          'score': j.float('score'),
          'createdAt': j.dateTime('createdAt'),
        },
        title: 'User',
        description: 'A basic user',
      );

      expect(schema['title'], 'User');
      expect(schema['description'], 'A basic user');
      expect(schema['type'], 'object');
      expect(
        schema['required'],
        unorderedEquals([
          'id',
          'name',
          'isActive',
          'tag',
          'score',
          'createdAt',
        ]),
      );
      expect(
        schema['properties'].keys,
        unorderedEquals([
          'id',
          'name',
          'isActive',
          'tag',
          'score',
          'createdAt',
        ]),
      );

      expect(schema['properties']['id']['type'], 'integer');
      expect(schema['properties']['name']['type'], 'string');
      expect(schema['properties']['isActive']['type'], 'boolean');
      expect(schema['properties']['tag']['type'], null);
      expect(schema['properties']['score']['type'], 'number');
      expect(schema['properties']['createdAt']['type'], 'string');
      expect(schema['properties']['createdAt']['format'], 'date-time');
    });

    test('generates schema with optional fields', () {
      final dynamic schema = JsonObject.schema((j) {
        j.integerOrNull('id');
        j.stringOrNull('name');
        j.booleanOrNull('isActive');
        j.anyOrNull('tag');
        j.floatOrNull('score');
        j.dateTimeOrNull('createdAt');
      });

      expect(schema['required'] ?? <String>[], isEmpty);
      expect(
        schema['properties'].keys,
        unorderedEquals([
          'id',
          'name',
          'isActive',
          'tag',
          'score',
          'createdAt',
        ]),
      );
    });

    test('generates schema constraints from validation rules (string)', () {
      final dynamic schema = JsonObject.schema((j) {
        j.string(
          'username',
          rules: [
            ValidationRule.length(min: 3, max: 20),
            ValidationRule.regex(RegExp(r'^[a-z]+$')),
          ],
        );
        j.string('email', rules: [ValidationRule.email()]);
        j.string('url', rules: [ValidationRule.url()]);
        j.string('ip', rules: [ValidationRule.ipv4()]);
        j.string('ip6', rules: [ValidationRule.ipv6()]);
        j.string('exact', rules: [ValidationRule.length(equal: 5)]);
      });

      expect(schema['properties']['username']['minLength'], 3);
      expect(schema['properties']['username']['maxLength'], 20);
      expect(schema['properties']['username']['pattern'], r'^[a-z]+$');

      expect(schema['properties']['email']['format'], 'email');
      expect(schema['properties']['url']['format'], 'uri');
      expect(schema['properties']['ip']['format'], 'ipv4');
      expect(schema['properties']['ip6']['format'], 'ipv6');

      expect(schema['properties']['exact']['minLength'], 5);
      expect(schema['properties']['exact']['maxLength'], 5);
    });

    test('generates schema constraints from validation rules (number)', () {
      final dynamic schema = JsonObject.schema((j) {
        j.integer('age', rules: [ValidationRule.range(min: 18, max: 100)]);
        j.float(
          'score',
          rules: [
            ValidationRule.range(exclusiveMin: 0, exclusiveMax: 10),
          ],
        );
      });

      expect(schema['properties']['age']['minimum'], 18);
      expect(schema['properties']['age']['maximum'], 100);

      expect(schema['properties']['score']['exclusiveMinimum'], 0);
      expect(schema['properties']['score']['exclusiveMaximum'], 10);
    });

    test('generates schema with nested objects', () {
      final dynamic schema = JsonObject.schema((j) {
        j.object(
          'address',
          (j) => {
            'city': j.string('city'),
            'zip': j.string('zip'),
          },
        );
        j.objectOrNull(
          'profile',
          (j) => {
            'bio': j.string('bio'),
          },
        );
      });

      expect(schema['required'], equals(['address']));

      final address = schema['properties']['address'];
      expect(address['type'], 'object');
      expect(address['required'], unorderedEquals(['city', 'zip']));
      expect(address['properties'].keys, unorderedEquals(['city', 'zip']));

      final profile = schema['properties']['profile'];
      expect(profile['type'], 'object');
      expect(profile['required'], unorderedEquals(['bio']));
      expect(profile['properties'].keys, unorderedEquals(['bio']));
    });

    test('generates schema with arrays', () {
      final dynamic schema = JsonObject.schema((j) {
        j.list('tags', mapper: (j) => j.string(r'$'));
        j.listOrNull('counts', mapper: (j) => j.integer(r'$'));
        j.list(
          'users',
          mapper: (j) => j.object(
            r'$',
            (j) => {
              'id': j.integer('id'),
            },
          ),
        );
      });

      expect(schema['required'], equals(['tags', 'users']));

      final tags = schema['properties']['tags'];
      expect(tags['type'], 'array');
      expect(tags['items']['type'], 'string');

      final counts = schema['properties']['counts'];
      expect(counts['type'], 'array');
      expect(counts['items']['type'], 'integer');

      final users = schema['properties']['users'];
      expect(users['type'], 'array');
      expect(users['items']['type'], 'object');
      expect(users['items']['properties'].keys, equals(['id']));
    });

    test('generates schema through JsonFieldExtractor', () {
      final dynamic schema = JsonObject.schema((j) {
        j.field.string('name');
        j.field.integerOrNull('age');
      });

      expect(schema['required'], equals(['name']));
      expect(schema['properties'].keys, unorderedEquals(['name', 'age']));
      expect(schema['properties']['name']['type'], 'string');
      expect(schema['properties']['age']['type'], 'integer');
    });

    test('generates schema for timestamp, uri, and map', () {
      final dynamic schema = JsonObject.schema((j) {
        j.timestamp('createdAt');
        j.timestampOrNull('updatedAt');
        j.uri('website');
        j.uriOrNull('avatarUrl');
        j.map('metadata', mapper: (j) => j.string(r'$'));
        j.mapOrNull(
          'stats',
          mapper: (j) => j.object(
            r'$',
            (j) => {
              'count': j.integer('count'),
            },
          ),
        );
        j.map<String>('primitiveMap');
        j.map<Object>('anyMap');
      });

      expect(
        schema['required'],
        unorderedEquals([
          'createdAt',
          'website',
          'metadata',
          'primitiveMap',
          'anyMap',
        ]),
      );

      expect(schema['properties']['createdAt']['type'], 'integer');
      expect(schema['properties']['updatedAt']['type'], 'integer');

      expect(schema['properties']['website']['type'], 'string');
      expect(schema['properties']['website']['format'], 'uri');

      expect(schema['properties']['avatarUrl']['type'], 'string');
      expect(schema['properties']['avatarUrl']['format'], 'uri');

      final metadata = schema['properties']['metadata'];
      expect(metadata['type'], 'object');
      expect(metadata['additionalProperties']['type'], 'string');

      final stats = schema['properties']['stats'];
      expect(stats['type'], 'object');
      expect(stats['additionalProperties']['type'], 'object');
      expect(
        stats['additionalProperties']['properties']['count']['type'],
        'integer',
      );

      final primitiveMap = schema['properties']['primitiveMap'];
      expect(primitiveMap['type'], 'object');
      expect(primitiveMap['additionalProperties']['type'], 'string');

      final anyMap = schema['properties']['anyMap'];
      expect(anyMap['type'], 'object');
      expect(anyMap['additionalProperties'], equals({}));
    });

    test('generates schema for discriminated objects (oneOf)', () {
      final dynamic schema = JsonObject.schema((j) {
        j.string('base_field');
        j.discriminated('type', {
          'doc': (j) => j.string('doc_id'),
          'video': (j) => j.integer('duration'),
        });
      });

      expect(schema['allOf'], isNotNull);
      final allOf = schema['allOf'] as List;
      expect(allOf.length, equals(2));

      final baseObj = allOf[0];
      expect(baseObj['properties']['base_field']['type'], 'string');
      expect(baseObj['required'], equals(['base_field']));

      final oneOfObj = allOf[1];
      final oneOfList = oneOfObj['oneOf'] as List;
      expect(oneOfList.length, equals(2));

      final docSchema = oneOfList[0];
      expect(docSchema['properties']['type']['const'], 'doc');
      expect(docSchema['properties']['doc_id']['type'], 'string');
      expect(docSchema['required'], unorderedEquals(['type', 'doc_id']));

      final videoSchema = oneOfList[1];
      expect(videoSchema['properties']['type']['const'], 'video');
      expect(videoSchema['properties']['duration']['type'], 'integer');
      expect(videoSchema['required'], unorderedEquals(['type', 'duration']));
    });

    test('generates schema for enumerations', () {
      final dynamic schema = JsonObject.schema((j) {
        j.enumeration('role', _Role.values);
        j.enumerationOrNull('optional_role', _Role.values);
        j.enumeration(
          'mapped_role',
          _Role.values,
          by: (e) => e.name.toUpperCase(),
        );
      });

      expect(schema['required'], equals(['role', 'mapped_role']));

      final role = schema['properties']['role'];
      expect(role['type'], 'string');
      expect(role['enum'], equals(['admin', 'user', 'guest']));

      final optionalRole = schema['properties']['optional_role'];
      expect(optionalRole['type'], 'string');
      expect(optionalRole['enum'], equals(['admin', 'user', 'guest']));

      final mappedRole = schema['properties']['mapped_role'];
      expect(mappedRole['type'], 'string');
      expect(mappedRole['enum'], equals(['ADMIN', 'USER', 'GUEST']));
    });
  });
}

enum _Role { admin, user, guest }
