import 'dart:convert';

import 'package:json_codable/json_codable.dart';
import 'package:test/test.dart';

void main() {
  group('ValidationErrors & Serialization', () {
    test('serializes scalar field errors into untagged list', () {
      final errors = ValidationErrors();
      errors.add(
        'email',
        const ValidationError(
          code: 'email',
          message: 'Invalid email address',
          params: {'value': 'invalid'},
        ),
      );

      final json = errors.toMap();
      expect(json, {
        'email': [
          {
            'code': 'email',
            'message': 'Invalid email address',
            'params': {'value': 'invalid'},
          },
        ],
      });
    });

    test('serializes nested object error', () {
      final childErrors = ValidationErrors();
      childErrors.add(
        'zip',
        const ValidationError(code: 'length', message: 'Too short'),
      );

      final parentErrors = ValidationErrors();
      parentErrors.addNested('address', ValidationErrorsObject(childErrors));

      final json = parentErrors.toMap();
      expect(json, {
        'address': {
          'zip': [
            {'code': 'length', 'message': 'Too short'},
          ],
        },
      });
    });

    test('serializes list item errors with string index keys', () {
      final itemErrors = ValidationErrors();
      itemErrors.add(
        'title',
        const ValidationError(code: 'required', message: 'Required'),
      );

      final parentErrors = ValidationErrors();
      parentErrors.addNested(
        'items',
        ValidationErrorsList({0: itemErrors}),
      );

      final json = parentErrors.toMap();
      expect(json, {
        'items': {
          '0': {
            'title': [
              {'code': 'required', 'message': 'Required'},
            ],
          },
        },
      });
    });

    test('serializes ValidationErrors with JsonWriter', () {
      final errors = ValidationErrors();
      errors.add(
        'email',
        const ValidationError(
          code: 'email',
          message: 'Invalid email address',
          params: {'value': 'invalid'},
        ),
      );

      final jsonString = utf8.decode(JsonWriter.encode(errors.toJson));
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded.containsKey('email'), isTrue);
    });

    test('ValidationErrors.add throws assert on conflict', () {
      final errors = ValidationErrors();
      errors.addNested('field', ValidationErrorsObject(ValidationErrors()));
      expect(
        () => errors.add('field', const ValidationError.required()),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ValidationErrors.addNested throws assert on conflict', () {
      final errors = ValidationErrors();
      errors.add('field', const ValidationError.required());
      expect(
        () => errors.addNested(
          'field',
          ValidationErrorsObject(ValidationErrors()),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('ValidationError equality with deep collections', () {
      const err1 = ValidationError(
        code: 'in',
        params: {
          'allowed': [1, 2, 3],
        },
      );
      const err2 = ValidationError(
        code: 'in',
        params: {
          'allowed': [1, 2, 3],
        },
      );
      const err3 = ValidationError(
        code: 'in',
        params: {
          'allowed': [1, 2, 4],
        },
      );

      expect(err1, equals(err2));
      expect(err1, isNot(equals(err3)));
    });
  });

  group('ValidationRule tests', () {
    test('length rule', () {
      final rule = ValidationRule.length(min: 3, max: 5);
      expect(rule.validate('abc'), isNull);
      expect(rule.validate('ab')?.code, equals('length'));
      expect(rule.validate('abcdef')?.code, equals('length'));

      final eqRule = ValidationRule.length(equal: 4);
      expect(eqRule.validate('1234'), isNull);
      expect(eqRule.validate('123')?.code, equals('length'));
    });

    test('range rule', () {
      final rule = ValidationRule.range(min: 10, max: 20);
      expect(rule.validate(15), isNull);
      expect(rule.validate(5)?.code, equals('range'));
      expect(rule.validate(25)?.code, equals('range'));

      final exclRule = ValidationRule.range(exclusiveMin: 5, exclusiveMax: 10);
      expect(exclRule.validate(7), isNull);
      expect(exclRule.validate(5)?.code, equals('range'));
      expect(exclRule.validate(10)?.code, equals('range'));
    });

    test('email rule', () {
      final rule = ValidationRule.email();
      expect(rule.validate('test@example.com'), isNull);
      expect(rule.validate('user@[127.0.0.1]'), isNull);
      expect(rule.validate('not-an-email')?.code, equals('email'));
      expect(rule.validate('')?.code, equals('email'));
    });

    test('url rule', () {
      final rule = ValidationRule.url();
      expect(rule.validate('https://dart.dev'), isNull);
      expect(rule.validate('just_text')?.code, equals('url'));
    });

    test('ip, ipv4, ipv6 rules', () {
      expect(ValidationRule.ip().validate('127.0.0.1'), isNull);
      expect(ValidationRule.ipv4().validate('127.0.0.1'), isNull);
      expect(ValidationRule.ipv6().validate('::1'), isNull);
      expect(ValidationRule.ipv4().validate('invalid')?.code, equals('ipv4'));
      expect(ValidationRule.ipv6().validate('invalid')?.code, equals('ipv6'));
    });

    test('contains and doesNotContain rules', () {
      expect(ValidationRule.contains('foo').validate('foobar'), isNull);
      expect(
        ValidationRule.contains('baz').validate('foobar')?.code,
        equals('contains'),
      );
      expect(ValidationRule.doesNotContain('baz').validate('foobar'), isNull);
      expect(
        ValidationRule.doesNotContain('foo').validate('foobar')?.code,
        equals('does_not_contain'),
      );
    });

    test('mustMatch, regex, nonControlCharacter, custom rules', () {
      expect(ValidationRule.mustMatch('secret').validate('secret'), isNull);
      expect(
        ValidationRule.mustMatch('secret').validate('wrong')?.code,
        equals('must_match'),
      );

      final reg = ValidationRule.regex(RegExp(r'^\d+$'));
      expect(reg.validate('12345'), isNull);
      expect(reg.validate('abc')?.code, equals('regex'));

      final nonCtrl = ValidationRule.nonControlCharacter();
      expect(nonCtrl.validate('Hello World'), isNull);
      expect(
        nonCtrl.validate('Hello\x00World')?.code,
        equals('non_control_character'),
      );

      final custom = ValidationRule.custom<int>(
        (v) => v < 0 ? const ValidationError(code: 'negative') : null,
      );
      expect(custom.validate(5), isNull);
      expect(custom.validate(-1)?.code, equals('negative'));
    });

    test('credit card Luhn rule', () {
      final rule = ValidationRule.creditCard();
      expect(rule.validate('4532015112830366'), isNull);
      expect(rule.validate('1234567890')?.code, equals('credit_card'));
    });
  });
}
