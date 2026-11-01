// ignore_for_file: avoid_dynamic_calls

import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('JsonObject.schema', () {
    test('generates basic object schema', () {
      final dynamic schema = JsonObject.schema(
        (j) => {
          'id': j.int('id'),
          'name': j.string('name'),
          'isActive': j.bool('isActive'),
          'tag': j.any('tag'),
          'score': j.double('score'),
          'createdAt': j.dateTime('createdAt'),
        },
        title: 'User',
        description: 'A basic user',
      );

      check(schema['title']).equals('User');
      check(schema['description']).equals('A basic user');
      check(schema['type']).equals('object');
      check(schema['required'] as Iterable<Object?>).unorderedEquals([
        'id',
        'name',
        'isActive',
        'tag',
        'score',
        'createdAt',
      ]);
      check((schema['properties'] as Map).keys).unorderedEquals([
        'id',
        'name',
        'isActive',
        'tag',
        'score',
        'createdAt',
      ]);

      check(schema['properties']['id']['type']).equals('integer');
      check(schema['properties']['name']['type']).equals('string');
      check(schema['properties']['isActive']['type']).equals('boolean');
      check(schema['properties']['tag']['type']).isNull();
      check(schema['properties']['score']['type']).equals('number');
      check(schema['properties']['createdAt']['type']).equals('string');
      check(schema['properties']['createdAt']['format']).equals('date-time');
    });

    test('generates schema with optional fields', () {
      final dynamic schema = JsonObject.schema((j) {
        j.intOrNull('id');
        j.stringOrNull('name');
        j.boolOrNull('isActive');
        j.anyOrNull('tag');
        j.doubleOrNull('score');
        j.dateTimeOrNull('createdAt');
      });

      check((schema['required'] ?? <String>[]) as Iterable).isEmpty();
      check((schema['properties'] as Map).keys).unorderedEquals([
        'id',
        'name',
        'isActive',
        'tag',
        'score',
        'createdAt',
      ]);
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

      check(schema['properties']['username']['minLength']).equals(3);
      check(schema['properties']['username']['maxLength']).equals(20);
      check(schema['properties']['username']['pattern']).equals(r'^[a-z]+$');

      check(schema['properties']['email']['format']).equals('email');
      check(schema['properties']['url']['format']).equals('uri');
      check(schema['properties']['ip']['format']).equals('ipv4');
      check(schema['properties']['ip6']['format']).equals('ipv6');

      check(schema['properties']['exact']['minLength']).equals(5);
      check(schema['properties']['exact']['maxLength']).equals(5);
    });

    test('generates schema constraints from validation rules (number)', () {
      final dynamic schema = JsonObject.schema((j) {
        j.int('age', rules: [ValidationRule.range(min: 18, max: 100)]);
        j.double(
          'score',
          rules: [
            ValidationRule.range(exclusiveMin: 0, exclusiveMax: 10),
          ],
        );
      });

      check(schema['properties']['age']['minimum']).equals(18);
      check(schema['properties']['age']['maximum']).equals(100);

      check(schema['properties']['score']['exclusiveMinimum']).equals(0);
      check(schema['properties']['score']['exclusiveMaximum']).equals(10);
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

      check(schema['required'] as List).deepEquals(['address']);

      final address = schema['properties']['address'];
      check(address['type']).equals('object');
      check(
        address['required'] as Iterable<Object?>,
      ).unorderedEquals(['city', 'zip']);
      check(
        (address['properties'] as Map).keys,
      ).unorderedEquals(['city', 'zip']);

      final profile = schema['properties']['profile'];
      check(profile['type']).equals('object');
      check(profile['required'] as Iterable<Object?>).unorderedEquals(['bio']);
      check((profile['properties'] as Map).keys).unorderedEquals(['bio']);
    });

    test('generates schema with arrays', () {
      final dynamic schema = JsonObject.schema((j) {
        j.list('tags', .string.where([.length(min: 2)]));
        j.listOrNull('counts', .int);
        j.list('users', .object((j) => {'id': j.int('id')}));
      });

      check(schema['required'] as List).deepEquals(['tags', 'users']);

      final tags = schema['properties']['tags'];
      check(tags['type']).equals('array');
      check(tags['items']['type']).equals('string');
      check(tags['items']['minLength']).equals(2);

      final counts = schema['properties']['counts'];
      check(counts['type']).equals('array');
      check(counts['items']['type']).equals('integer');

      final users = schema['properties']['users'];
      check(users['type']).equals('array');
      check(users['items']['type']).equals('object');
      check((users['items']['properties'] as Map).keys).deepEquals(['id']);
    });

    test(r'describes the root value with the $ key', () {
      final dynamic schema = JsonObject.schema((j) => j.list(r'$', .int));

      check(schema['type']).equals('array');
      check(schema['items']['type']).equals('integer');
    });

    test('keeps fields traced before the mapper throws', () {
      final dynamic schema = JsonObject.schema((j) {
        final email = _Email(j.string('email'));
        return (email, j.string('name'));
      });

      // The placeholder email is rejected, so `name` is never read.
      check((schema['properties'] as Map).keys).deepEquals(['email']);
    });

    test('generates schema through JsonFieldExtractor', () {
      final dynamic schema = JsonObject.schema((j) {
        j.field.string('name');
        j.field.intOrNull('age');
      });

      check(schema['required'] as List).deepEquals(['name']);
      check(
        (schema['properties'] as Map).keys,
      ).unorderedEquals(['name', 'age']);
      check(schema['properties']['name']['type']).equals('string');
      check(schema['properties']['age']['type']).equals('integer');
    });

    test('generates schema for timestamp, uri, and map', () {
      final dynamic schema = JsonObject.schema((j) {
        j.timestamp('createdAt');
        j.timestampOrNull('updatedAt');
        j.uri('website');
        j.uriOrNull('avatarUrl');
        j.map('metadata', .string);
        j.mapOrNull('stats', .object((j) => {'count': j.int('count')}));
        j.map('anyMap', .any);
      });

      check(schema['required'] as Iterable<Object?>).unorderedEquals([
        'createdAt',
        'website',
        'metadata',
        'anyMap',
      ]);

      check(schema['properties']['createdAt']['type']).equals('integer');
      check(schema['properties']['updatedAt']['type']).equals('integer');

      check(schema['properties']['website']['type']).equals('string');
      check(schema['properties']['website']['format']).equals('uri');

      check(schema['properties']['avatarUrl']['type']).equals('string');
      check(schema['properties']['avatarUrl']['format']).equals('uri');

      final metadata = schema['properties']['metadata'];
      check(metadata['type']).equals('object');
      check(metadata['additionalProperties']['type']).equals('string');

      final stats = schema['properties']['stats'];
      check(stats['type']).equals('object');
      check(stats['additionalProperties']['type']).equals('object');
      check(
        stats['additionalProperties']['properties']['count']['type'],
      ).equals('integer');

      final anyMap = schema['properties']['anyMap'];
      check(anyMap['type']).equals('object');
      check(anyMap['additionalProperties'] as Map).deepEquals({});
    });

    test('generates schema for discriminated objects (oneOf)', () {
      final dynamic schema = JsonObject.schema((j) {
        j.string('base_field');
        j.discriminated('type', {
          'doc': (j) => j.string('doc_id'),
          'video': (j) => j.int('duration'),
        });
      });

      check(schema['allOf']).isNotNull();
      final allOf = schema['allOf'] as List;
      check(allOf.length).equals(2);

      final baseObj = allOf[0];
      check(baseObj['properties']['base_field']['type']).equals('string');
      check(baseObj['required'] as List).deepEquals(['base_field']);

      final oneOfObj = allOf[1];
      check(oneOfObj['discriminator']['propertyName']).equals('type');
      final oneOfList = oneOfObj['oneOf'] as List;
      check(oneOfList.length).equals(2);

      final docSchema = oneOfList[0];
      check(docSchema['properties']['type']['const']).equals('doc');
      check(docSchema['properties']['doc_id']['type']).equals('string');
      check(
        docSchema['required'] as Iterable<Object?>,
      ).unorderedEquals(['type', 'doc_id']);

      final videoSchema = oneOfList[1];
      check(videoSchema['properties']['type']['const']).equals('video');
      check(videoSchema['properties']['duration']['type']).equals('integer');
      check(
        videoSchema['required'] as Iterable<Object?>,
      ).unorderedEquals(['type', 'duration']);
    });

    test('generates schema for list of discriminated objects', () {
      final dynamic schema = JsonObject.schema((j) {
        j.list(
          'items',
          .discriminated('kind', {
            'text': (j) => j.string('text'),
            'image': (j) => j.string('url'),
          }),
        );
      });

      check(schema['required'] as List).deepEquals(['items']);
      final itemsField = schema['properties']['items'];
      check(itemsField['type']).equals('array');
      check(
        itemsField['items']['discriminator']['propertyName'],
      ).equals('kind');

      final oneOfList = itemsField['items']['oneOf'] as List;
      check(oneOfList.length).equals(2);

      final textVariant = oneOfList[0];
      check(textVariant['properties']['kind']['const']).equals('text');
      check(textVariant['properties']['text']['type']).equals('string');
      check(
        textVariant['required'] as Iterable<Object?>,
      ).unorderedEquals(['kind', 'text']);

      final imageVariant = oneOfList[1];
      check(imageVariant['properties']['kind']['const']).equals('image');
      check(imageVariant['properties']['url']['type']).equals('string');
      check(
        imageVariant['required'] as Iterable<Object?>,
      ).unorderedEquals(['kind', 'url']);
    });

    test('generates schema for nested discriminated object', () {
      final dynamic schema = JsonObject.schema((j) {
        j.object(
          'payload',
          (childJson) => childJson.discriminated('event', {
            'click': (j) => j.string('target'),
            'hover': (j) => j.int('duration'),
          }),
        );
      });

      check(schema['required'] as List).deepEquals(['payload']);
      final payloadField = schema['properties']['payload'];
      final oneOfList = payloadField['oneOf'] as List;
      check(oneOfList.length).equals(2);

      final clickVariant = oneOfList[0];
      check(clickVariant['properties']['event']['const']).equals('click');
      check(clickVariant['properties']['target']['type']).equals('string');

      final hoverVariant = oneOfList[1];
      check(hoverVariant['properties']['event']['const']).equals('hover');
      check(hoverVariant['properties']['duration']['type']).equals('integer');
    });

    test('generates schema for map of discriminated objects', () {
      final dynamic schema = JsonObject.schema((j) {
        j.map(
          'by_id',
          .discriminated('type', {
            'a': (j) => j.string('name'),
            'b': (j) => j.bool('flag'),
          }),
        );
      });

      check(schema['required'] as List).deepEquals(['by_id']);
      final mapField = schema['properties']['by_id'];
      check(mapField['type']).equals('object');

      final addProps = mapField['additionalProperties'];
      final oneOfList = addProps['oneOf'] as List;
      check(oneOfList.length).equals(2);
      check(oneOfList[0]['properties']['type']['const']).equals('a');
      check(oneOfList[1]['properties']['type']['const']).equals('b');
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

      check(schema['required'] as List).deepEquals(['role', 'mapped_role']);

      final role = schema['properties']['role'];
      check(role['type']).equals('string');
      check(role['enum'] as List).deepEquals(['admin', 'user', 'guest']);

      final optionalRole = schema['properties']['optional_role'];
      check(optionalRole['type']).equals('string');
      check(
        optionalRole['enum'] as List,
      ).deepEquals(['admin', 'user', 'guest']);

      final mappedRole = schema['properties']['mapped_role'];
      check(mappedRole['type']).equals('string');
      check(mappedRole['enum'] as List).deepEquals(['ADMIN', 'USER', 'GUEST']);
    });
  });
}

enum _Role { admin, user, guest }

class _Email {
  _Email(this.value) {
    if (!value.contains('@')) throw ArgumentError.value(value, 'value');
  }

  final String value;
}
