import 'dart:convert';
import 'dart:typed_data';

import 'package:json_codable/json_codable.dart';
import 'package:test/test.dart';

Uint8List _toBytes(String jsonStr) => Uint8List.fromList(utf8.encode(jsonStr));

void main() {
  group('JsonReader - Key Existence & Nullability', () {
    test('hasKey returns true for present keys and false for absent keys', () {
      final reader = JsonReader(_toBytes('{"name": "Alice", "age": null}'));

      expect(reader.hasKey('name'), isTrue);
      expect(reader.hasKey('age'), isTrue);
      expect(reader.hasKey('missing'), isFalse);
    });

    test('isNull returns true for null values and false for non-null', () {
      final reader = JsonReader(
        _toBytes('{"active": true, "deletedAt": null}'),
      );

      expect(reader.isNull('deletedAt'), isTrue);
      expect(reader.isNull('active'), isFalse);
      expect(reader.isNull('missing'), isFalse);
    });

    test('handles empty string key ""', () {
      final reader = JsonReader(_toBytes('{"": "emptyKeyVal"}'));

      expect(reader.hasKey(''), isTrue);
      expect(reader.readString(''), equals('emptyKeyVal'));
    });
  });

  group('JsonReader - Primitive & Escape String Extraction', () {
    test('reads simple and escaped strings', () {
      const jsonStr = r'''
      {
        "simple": "Hello World",
        "escaped": "Line1\nLine2\tTab \"Quote\" \\Slash\\",
        "unicode": "Unicode \u0041\u0042\u0043"
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readString('simple'), equals('Hello World'));
      expect(
        reader.readString('escaped'),
        equals('Line1\nLine2\tTab "Quote" \\Slash\\'),
      );
      expect(reader.readString('unicode'), equals('Unicode ABC'));
      expect(reader.readString('missing'), isNull);
    });

    test('handles raw multibyte UTF-8 characters and all standard escapes', () {
      const jsonStr = r'''
      {
        "cyrillic": "Привет, мир!",
        "emoji": "🚀 Dart & JSON 😀",
        "chinese": "你好世界",
        "escapes": "Backspace\b Formfeed\f CR\r Slash\/",
        "cyrillicEscaped": "Привет\nМир\t😀"
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readString('cyrillic'), equals('Привет, мир!'));
      expect(reader.readString('emoji'), equals('🚀 Dart & JSON 😀'));
      expect(reader.readString('chinese'), equals('你好世界'));
      expect(
        reader.readString('escapes'),
        equals('Backspace\b Formfeed\f CR\r Slash/'),
      );
      expect(reader.readString('cyrillicEscaped'), equals('Привет\nМир\t😀'));
    });

    test(r'parses unicode surrogate pairs like \uD83C\uDF95', () {
      final reader = JsonReader(
        _toBytes(r'{"flower": "\uD83C\uDF95", "rocket": "\uD83D\uDE80"}'),
      );
      expect(reader.readString('flower'), equals('\u{1F395}'));
      expect(reader.readString('rocket'), equals('🚀'));
    });

    test('reads booleans', () {
      const jsonStr = '{"isTrue": true, "isFalse": false}';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readBool('isTrue'), isTrue);
      expect(reader.readBool('isFalse'), isFalse);
      expect(reader.readBool('missing'), isNull);
    });

    test(
      'readAny dynamically determines types for primitives and structures',
      () {
        const jsonStr = '''
      {
        "str": "text",
        "numInt": 10,
        "numFloat": 2.5,
        "flag": true,
        "nil": null,
        "nestedMap": {"a": 1},
        "nestedList": [1, 2]
      }
      ''';
        final reader = JsonReader(_toBytes(jsonStr));

        expect(reader.readAny('str'), equals('text'));
        expect(reader.readAny('numInt'), equals(10));
        expect(reader.readAny('numFloat'), equals(2.5));
        expect(reader.readAny('flag'), isTrue);
        expect(reader.readAny('nil'), isNull);
        expect(reader.readAny('missing'), isNull);
        expect(reader.readAny('nestedMap'), equals({'a': 1}));
        expect(reader.readAny('nestedList'), equals([1, 2]));
      },
    );
  });

  group('JsonReader - Numbers & Numeric Edge Cases', () {
    test('reads integers', () {
      const jsonStr = '''
      {
        "zero": 0,
        "positive": 42,
        "negative": -100,
        "maxInt": 9007199254740991
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readInt('zero'), equals(0));
      expect(reader.readInt('positive'), equals(42));
      expect(reader.readInt('negative'), equals(-100));
      expect(reader.readInt('maxInt'), equals(9007199254740991));
      expect(reader.readInt('missing'), isNull);
    });

    test('reads floats/doubles', () {
      const jsonStr = '''
      {
        "pi": 3.14159,
        "negative": -0.5,
        "exp": 1.23e4,
        "negExp": 1.5e-3,
        "plusExp": 2.5E+2
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readFloat('pi'), equals(3.14159));
      expect(reader.readFloat('negative'), equals(-0.5));
      expect(reader.readFloat('exp'), equals(12300.0));
      expect(reader.readFloat('negExp'), equals(0.0015));
      expect(reader.readFloat('plusExp'), equals(250.0));
      expect(reader.readFloat('missing'), isNull);
    });

    test('readFloat parses integer JSON values as double', () {
      final reader = JsonReader(_toBytes('{"intVal": 42, "zero": 0}'));
      expect(reader.readFloat('intVal'), equals(42.0));
      expect(reader.readFloat('zero'), equals(0.0));
    });

    test('handles zero, negative numbers and scientific notation formats', () {
      const jsonStr = '''
      {
        "zero": 0,
        "negZero": -0,
        "negFloat": -0.0,
        "sciSmall": 1e-5,
        "sciLarge": 2.5E+10,
        "sciPlain": 1e5
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readInt('zero'), equals(0));
      expect(reader.readInt('negZero'), equals(0));
      expect(reader.readFloat('negFloat'), equals(-0.0));
      expect(reader.readFloat('sciSmall'), equals(0.00001));
      expect(reader.readFloat('sciLarge'), equals(25000000000.0));
      expect(reader.readFloat('sciPlain'), equals(100000.0));
    });
  });

  group('JsonReader - Nested Objects, Lists & Maps', () {
    test('reads nested JsonReader object and deep structures', () {
      const jsonStr = '''
      {
        "title": "Main",
        "author": {
          "name": "Bob",
          "age": 30
        }
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));
      final author = reader.readObject('author');

      expect(author, isNotNull);
      expect(author!.readString('name'), equals('Bob'));
      expect(author.readInt('age'), equals(30));
      expect(reader.readObject('missing'), isNull);
    });

    test('reads deeply nested objects', () {
      const jsonStr = '{"l1": {"l2": {"l3": {"value": "deep"}}}}';
      final reader = JsonReader(_toBytes(jsonStr));

      final l3 = reader.readObject('l1')?.readObject('l2')?.readObject('l3');
      expect(l3, isNotNull);
      expect(l3!.readString('value'), equals('deep'));
    });

    test('reads list of nested objects with custom mapper', () {
      const jsonStr = '''
      {
        "items": [
          {"id": 1, "label": "first"},
          {"id": 2, "label": "second"}
        ]
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));
      final items = reader.readList(
        'items',
        (r) => (id: r.readInt('id')!, label: r.readString('label')!),
      );

      expect(items, isNotNull);
      expect(items!.length, equals(2));
      expect(items[0].id, equals(1));
      expect(items[0].label, equals('first'));
      expect(items[1].id, equals(2));
      expect(items[1].label, equals('second'));
    });

    test('reads primitive lists', () {
      const jsonStr = '''
      {
        "numbers": [10, 20, 30],
        "tags": ["a", "b", "c"],
        "floats": [1.1, 2.2],
        "booleans": [true, false]
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.readList<int>('numbers'), equals([10, 20, 30]));
      expect(
        reader.readList<String>('tags'),
        equals(['a', 'b', 'c']),
      );
      expect(
        reader.readList<double>('floats'),
        equals([1.1, 2.2]),
      );
      expect(
        reader.readList<bool>('booleans'),
        equals([true, false]),
      );
    });

    test('readList<Object?> handles heterogeneous arrays and empty lists', () {
      const jsonStr = '{"mixed": ["text", 100, 3.14, true, null], "empty": []}';
      final reader = JsonReader(_toBytes(jsonStr));

      final mixed = reader.readList<Object?>('mixed');
      expect(mixed, equals(['text', 100, 3.14, true, null]));
      expect(reader.readList<Object?>('empty'), isEmpty);
      expect(reader.readList<JsonReader>('empty'), isEmpty);
    });

    test('readList<int?> handles nullable int items', () {
      final reader = JsonReader(_toBytes('{"nums": [1, null, 3]}'));
      final nums = reader.readList<int?>('nums');
      expect(nums, equals([1, null, 3]));
    });

    test('reads primitive map and object map', () {
      const jsonStr = '''
      {
        "scores": {"alice": 100, "bob": 85},
        "configs": {"debug": "true", "env": "prod"},
        "users": {
          "u1": {"name": "Alice"},
          "u2": {"name": "Bob"}
        }
      }
      ''';
      final reader = JsonReader(_toBytes(jsonStr));

      final scores = reader.readMap<int>('scores');
      expect(scores, equals({'alice': 100, 'bob': 85}));

      final configs = reader.readMap<String>('configs');
      expect(configs, equals({'debug': 'true', 'env': 'prod'}));

      final users = reader.readMap('users', (r) => r.readString('name'));
      expect(users, isNotNull);
      expect(users!.keys, containsAll(['u1', 'u2']));
      expect(users['u1'], equals('Alice'));
      expect(users['u2'], equals('Bob'));
    });

    test('readMap<int?> handles map with null values', () {
      final reader = JsonReader(_toBytes('{"map": {"a": 1, "b": null}}'));
      final map = reader.readMap<int?>('map');
      expect(map, equals({'a': 1, 'b': null}));
    });
  });

  group('JsonReader - Type Mismatch Exception Handling', () {
    test('throws JsonTypeMismatchException when reading int as string', () {
      final reader = JsonReader(_toBytes('{"age": "twenty-five"}'));

      expect(
        () => reader.readInt('age'),
        throwsA(
          isA<JsonTypeMismatchException>()
              .having((e) => e.key, 'key', 'age')
              .having((e) => e.expected, 'expected', 'integer')
              .having((e) => e.actual, 'actual', 'twenty-five'),
        ),
      );
    });

    test('throws JsonTypeMismatchException when reading string as int', () {
      final reader = JsonReader(_toBytes('{"count": 42}'));

      expect(
        () => reader.readString('count'),
        throwsA(
          isA<JsonTypeMismatchException>()
              .having((e) => e.key, 'key', 'count')
              .having((e) => e.expected, 'expected', 'string')
              .having((e) => e.actual, 'actual', 42),
        ),
      );
    });

    test('throws JsonTypeMismatchException when reading list as object', () {
      final reader = JsonReader(_toBytes('{"data": [1, 2, 3]}'));

      expect(
        () => reader.readObject('data'),
        throwsA(
          isA<JsonTypeMismatchException>()
              .having((e) => e.key, 'key', 'data')
              .having((e) => e.expected, 'expected', 'object'),
        ),
      );
    });

    test('throws JsonTypeMismatchException when reading object as list', () {
      final reader = JsonReader(_toBytes('{"data": {"a": 1}}'));

      expect(
        () => reader.readList<Object?>('data'),
        throwsA(
          isA<JsonTypeMismatchException>()
              .having((e) => e.key, 'key', 'data')
              .having((e) => e.expected, 'expected', 'list'),
        ),
      );
    });

    test('throws JsonTypeMismatchException when list item has wrong type', () {
      final reader = JsonReader(_toBytes('{"nums": [10, "twenty", 30]}'));

      expect(
        () => reader.readList<int>('nums'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
    });

    test('throws JsonTypeMismatchException when map value has wrong type', () {
      final reader = JsonReader(_toBytes('{"map": {"a": 100, "b": "str"}}'));

      expect(
        () => reader.readMap<int>('map'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
    });
  });

  group('JsonReader - Syntax Violations & Malformed JSON', () {
    test('throws JsonSyntaxException on unclosed object', () {
      final reader = JsonReader(_toBytes('{"key": "value"'));
      expect(
        () => reader.readString('key'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });

    test('throws JsonSyntaxException on missing colon', () {
      final reader = JsonReader(_toBytes('{"key" "value"}'));
      expect(
        () => reader.readString('key'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });

    test('throws JsonSyntaxException on missing value after colon', () {
      final reader = JsonReader(_toBytes('{"key":}'));
      expect(
        () => reader.readString('key'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });

    test('throws JsonSyntaxException on trailing comma', () {
      final reader = JsonReader(_toBytes('{"a": 1,}'));
      expect(
        () => reader.readInt('a'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });

    test('throws JsonSyntaxException on invalid escape sequences', () {
      final bad1 = JsonReader(_toBytes(r'{"bad": "\x12"}'));
      expect(
        () => bad1.readString('bad'),
        throwsA(isA<JsonSyntaxException>()),
      );

      final bad2 = JsonReader(_toBytes(r'{"bad": "\u00"}'));
      expect(
        () => bad2.readString('bad'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });

    test('validates malformed list and object syntax violations', () {
      final errList1 = JsonReader(_toBytes('[1,'));
      expect(
        () => errList1.readList<Object?>(''),
        throwsA(isA<JsonSyntaxException>()),
      );

      final errList2 = JsonReader(_toBytes('[1 2]'));
      expect(
        () => errList2.readList<Object?>(''),
        throwsA(isA<JsonSyntaxException>()),
      );

      final errObj1 = JsonReader(_toBytes('{ "a"'));
      expect(
        () => errObj1.readString('a'),
        throwsA(isA<JsonSyntaxException>()),
      );

      final errObj2 = JsonReader(_toBytes('{"a" 1}'));
      expect(
        () => errObj2.readInt('a'),
        throwsA(isA<JsonSyntaxException>()),
      );

      final errObj3 = JsonReader(_toBytes('{"a":1 1}'));
      expect(
        () => errObj3.readInt('a'),
        throwsA(isA<JsonSyntaxException>()),
      );
    });
  });

  group('JsonReader - Buffer Slicing & Payload Scale', () {
    test('respects buffer offset and length and bytes getter', () {
      const fullText = 'PREFIX{"val": 999}SUFFIX';
      final fullBytes = _toBytes(fullText);
      const jsonPart = '{"val": 999}';

      final startOffset = fullText.indexOf('{');
      final reader = JsonReader(
        fullBytes,
        offset: startOffset,
        length: jsonPart.length,
      );

      expect(reader.readInt('val'), equals(999));
    });

    test('handles empty object top-level and nested', () {
      final reader = JsonReader(_toBytes('{}'));
      expect(reader.hasKey('any'), isFalse);
      expect(reader.readString('any'), isNull);

      final nestedReader = JsonReader(_toBytes('{"empty": {}}'));
      final emptyObj = nestedReader.readObject('empty');
      expect(emptyObj, isNotNull);
      expect(emptyObj!.hasKey('x'), isFalse);
    });

    test('handles large object with many keys (> 10 fields)', () {
      final map = {for (var i = 0; i < 50; i++) 'key_$i': i};
      final jsonStr = jsonEncode(map);
      final reader = JsonReader(_toBytes(jsonStr));

      expect(reader.hasKey('key_0'), isTrue);
      expect(reader.readInt('key_0'), equals(0));
      expect(reader.readInt('key_25'), equals(25));
      expect(reader.readInt('key_49'), equals(49));
      expect(reader.hasKey('key_50'), isFalse);
    });

    test('handles large list with many items (> 20 elements)', () {
      final items = List.generate(50, (i) => 'item_$i');
      final jsonStr = jsonEncode({'items': items});
      final reader = JsonReader(_toBytes(jsonStr));

      final readItems = reader.readList<String>('items');
      expect(readItems, isNotNull);
      expect(readItems!.length, equals(50));
      expect(readItems[0], equals('item_0'));
      expect(readItems[49], equals('item_49'));
    });
  });

  group('JsonReader.fromMap (_MapJsonReader)', () {
    test('reads primitive and complex values directly from map', () {
      final mapReader = JsonReader.fromMap({
        'str': 'hello',
        'numInt': 42,
        'numFloat': 3.14,
        'flag': true,
        'nil': null,
        'subObj': {'name': 'Alice'},
        'intList': [1, 2, 3],
        'strMap': {'a': 'alpha', 'b': 'beta'},
      });

      expect(mapReader.hasKey('str'), isTrue);
      expect(mapReader.hasKey('missing'), isFalse);
      expect(mapReader.isNull('nil'), isTrue);
      expect(mapReader.isNull('str'), isFalse);

      expect(mapReader.readString('str'), equals('hello'));
      expect(mapReader.readInt('numInt'), equals(42));
      expect(mapReader.readFloat('numFloat'), equals(3.14));
      expect(mapReader.readFloat('numInt'), equals(42.0));
      expect(mapReader.readBool('flag'), isTrue);
      expect(mapReader.readAny('str'), equals('hello'));

      final subObj = mapReader.readObject('subObj');
      expect(subObj, isNotNull);
      expect(subObj!.readString('name'), equals('Alice'));

      expect(mapReader.readList<int>('intList'), equals([1, 2, 3]));
      expect(
        mapReader.readMap<String>('strMap'),
        equals({'a': 'alpha', 'b': 'beta'}),
      );
    });

    test('throws JsonTypeMismatchException on invalid map types', () {
      final mapReader = JsonReader.fromMap({
        'str': 123,
        'num': 'not_a_num',
        'bool': 'true',
        'list': {'not': 'a list'},
        'map': [1, 2, 3],
      });

      expect(
        () => mapReader.readString('str'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
      expect(
        () => mapReader.readInt('num'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
      expect(
        () => mapReader.readFloat('num'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
      expect(
        () => mapReader.readBool('bool'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
      expect(
        () => mapReader.readList<int>('list'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
      expect(
        () => mapReader.readMap<int>('map'),
        throwsA(isA<JsonTypeMismatchException>()),
      );
    });

    test('supports decoding nested objects in list and map', () {
      final mapReader = JsonReader.fromMap({
        'users': [
          {'id': 1, 'name': 'Bob'},
          {'id': 2, 'name': 'Alice'},
        ],
        'userMap': {
          'u1': {'name': 'Charlie'},
        },
      });

      final users = mapReader.readList(
        'users',
        (r) => (id: r.readInt('id')!, name: r.readString('name')!),
      );
      expect(users, isNotNull);
      expect(users!.length, equals(2));
      expect(users[0].name, equals('Bob'));

      final userMap = mapReader.readMap(
        'userMap',
        (r) => r.readString('name'),
      );
      expect(userMap, isNotNull);
      expect(userMap!['u1'], equals('Charlie'));
    });
  });
}
