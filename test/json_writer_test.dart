import 'dart:convert';

import 'package:json_codable/json_codable.dart';
import 'package:test/test.dart';

void main() {
  group('JsonWriter', () {
    test('writes primitive fields (string, int, float, bool)', () {
      final writer = JsonWriter();
      writer.string('name', 'Alice');
      writer.integer('age', 25);
      writer.float('score', 98.5);
      writer.boolean('active', true);

      final bytes = writer.toBytes();
      final jsonString = utf8.decode(bytes);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['name'], equals('Alice'));
      expect(decoded['age'], equals(25));
      expect(decoded['score'], equals(98.5));
      expect(decoded['active'], isTrue);
    });

    test('writes explicit null values for primitives', () {
      final writer = JsonWriter();
      writer.string('name', null);
      writer.integer('age', null);
      writer.float('score', null);
      writer.boolean('active', null);

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded.containsKey('name'), isTrue);
      expect(decoded['name'], isNull);
      expect(decoded['age'], isNull);
      expect(decoded['score'], isNull);
      expect(decoded['active'], isNull);
    });

    test('writes string with escaped special characters', () {
      final writer = JsonWriter();
      writer.string('message', 'Hello "World"\n\t\\');

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['message'], equals('Hello "World"\n\t\\'));
    });

    test('writes nested objects', () {
      final writer = JsonWriter();
      writer.string('id', 'usr_1');
      writer.object('author', (w) {
        w.string('name', 'Bob');
        w.integer('rating', 5);
      });

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['id'], equals('usr_1'));
      expect(decoded['author'], isA<Map<String, dynamic>>());
      final author = decoded['author'] as Map<String, dynamic>;
      expect(author['name'], equals('Bob'));
      expect(author['rating'], equals(5));
    });

    test('writes 5-level deep nested objects', () {
      final writer = JsonWriter();
      writer.object('l1', (w1) {
        w1.object('l2', (w2) {
          w2.object('l3', (w3) {
            w3.object('l4', (w4) {
              w4.object('l5', (w5) {
                w5.string('deepKey', 'deepValue');
                w5.integer('depth', 5);
              });
            });
          });
        });
      });

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final l1 = decoded['l1'] as Map<String, dynamic>;
      final l2 = l1['l2'] as Map<String, dynamic>;
      final l3 = l2['l3'] as Map<String, dynamic>;
      final l4 = l3['l4'] as Map<String, dynamic>;
      final l5 = l4['l5'] as Map<String, dynamic>;

      expect(l5['deepKey'], equals('deepValue'));
      expect(l5['depth'], equals(5));
    });

    test('writes primitive lists', () {
      final writer = JsonWriter();
      writer.list<String>('tags', ['dart', 'flutter']);
      writer.list<int>('scores', [10, 20, 30]);

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['tags'], equals(['dart', 'flutter']));
      expect(decoded['scores'], equals([10, 20, 30]));
    });

    test('writes empty and null lists', () {
      final writer = JsonWriter();
      writer.list<String>('empty', []);
      writer.list<String>('nullList', null);

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['empty'], equals([]));
      expect(decoded['nullList'], isNull);
    });

    test('writes object lists with mapper and nested objects', () {
      final writer = JsonWriter();
      final items = [
        {
          'id': 1,
          'title': 'Laptop',
          'sub': {'code': 'A1'},
        },
        {
          'id': 2,
          'title': 'Mouse',
          'sub': {'code': 'B2'},
        },
      ];

      writer.list<Map<String, dynamic>>(
        'items',
        items,
        mapper: (w, item) {
          w.integer('id', item['id'] as int);
          w.string('title', item['title'] as String);
          w.object('sub', (wSub) {
            final subMap = item['sub'] as Map<String, dynamic>;
            wSub.string('code', subMap['code'] as String);
          });
        },
      );

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final decodedItems = decoded['items'] as List;
      expect(decodedItems.length, equals(2));
      expect(
        decodedItems[0],
        equals({
          'id': 1,
          'title': 'Laptop',
          'sub': {'code': 'A1'},
        }),
      );
      expect(
        decodedItems[1],
        equals({
          'id': 2,
          'title': 'Mouse',
          'sub': {'code': 'B2'},
        }),
      );
    });

    test('encodes root JSON list of DTO objects', () {
      final items = [
        {'id': 101, 'name': 'Item A'},
        {'id': 102, 'name': 'Item B'},
      ];

      final bytes = JsonWriter.encodeList(
        items,
        mapper: (w, item) {
          w.integer('id', item['id'] as int?);
          w.string('name', item['name'] as String?);
        },
      );
      final jsonStr = utf8.decode(bytes);

      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded.length, equals(2));
      expect(decoded[0], equals({'id': 101, 'name': 'Item A'}));
      expect(decoded[1], equals({'id': 102, 'name': 'Item B'}));
    });

    test('encodes root JSON list of primitives', () {
      final jsonStr = utf8.decode(
        JsonWriter.encodeList(['alpha', 'beta', 'gamma']),
      );
      final decoded = jsonDecode(jsonStr) as List;
      expect(decoded, equals(['alpha', 'beta', 'gamma']));
    });

    test('writes primitive maps', () {
      final writer = JsonWriter();
      writer.map<String>('strMap', {'a': 'alpha', 'b': 'beta'});
      writer.map<int>('intMap', {'count': 1, 'total': 100});

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['strMap'], equals({'a': 'alpha', 'b': 'beta'}));
      expect(decoded['intMap'], equals({'count': 1, 'total': 100}));
    });

    test('writes null and empty maps', () {
      final writer = JsonWriter();
      writer.map<String>('empty', {});
      writer.map<String>('nullMap', null);

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['empty'], equals({}));
      expect(decoded['nullMap'], isNull);
    });

    test('writes object maps with mapper', () {
      final writer = JsonWriter();
      final users = {
        'usr_1': {'name': 'Alice', 'role': 'admin'},
        'usr_2': {'name': 'Bob', 'role': 'user'},
      };

      writer.map<Map<String, String>>(
        'users',
        users,
        mapper: (w, user) {
          w.string('name', user['name']);
          w.string('role', user['role']);
        },
      );

      final jsonString = utf8.decode(writer.toBytes());
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final decodedUsers = decoded['users'] as Map<String, dynamic>;
      expect(
        decodedUsers['usr_1'],
        equals({'name': 'Alice', 'role': 'admin'}),
      );
      expect(
        decodedUsers['usr_2'],
        equals({'name': 'Bob', 'role': 'user'}),
      );
    });
  });
}
