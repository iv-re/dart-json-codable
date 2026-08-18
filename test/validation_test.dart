import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';
import 'package:test/scaffolding.dart';

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

      final json = errors.toJson();
      check(json).deepEquals({
        'email': [
          {
            'code': 'email',
            'message': 'Invalid email address',
            'params': {'value': 'invalid'},
          },
        ],
      });
    });

    test('serializes nested object error with dot notation', () {
      final childErrors = ValidationErrors();
      childErrors.add(
        'zip',
        const ValidationError(code: 'length', message: 'Too short'),
      );

      final parentErrors = ValidationErrors();
      parentErrors.merge(childErrors, 'address');

      final json = parentErrors.toJson();
      check(json).deepEquals({
        'address.zip': [
          {'code': 'length', 'message': 'Too short'},
        ],
      });
    });

    test('serializes list item errors with dot notation and indexed keys', () {
      final itemErrors = ValidationErrors();
      itemErrors.add(
        'title',
        const ValidationError(code: 'required', message: 'Required'),
      );

      final parentErrors = ValidationErrors();
      parentErrors.merge(itemErrors, 'items.0');

      final json = parentErrors.toJson();
      check(json).deepEquals({
        'items.0.title': [
          {'code': 'required', 'message': 'Required'},
        ],
      });
    });

    test('ValidationErrors.addAll and merge accumulate errors cleanly', () {
      final errors = ValidationErrors();
      errors.addAll('field', const [
        ValidationError(code: 'rule1'),
        ValidationError(code: 'rule2'),
      ]);

      final child = ValidationErrors();
      child.add('nested', const ValidationError(code: 'rule3'));
      errors.merge(child, 'prefix');

      check(errors.hasError('field')).isTrue();
      check(errors.errors['field']).isNotNull().length.equals(2);
      check(errors.hasError('prefix.nested')).isTrue();
      check(
        errors.errors['prefix.nested'],
      ).isNotNull().first.has((e) => e.code, 'code').equals('rule3');
    });

    test('ValidationError.fromJson parses single error', () {
      const json = JsonObject({
        'code': 'length',
        'message': 'Too short',
        'params': {'min': 5, 'value': 'abc'},
      });

      final error = ValidationError.fromJson(json);
      check(error.code).equals('length');
      check(error.message).equals('Too short');
      check(error.params).deepEquals({'min': 5, 'value': 'abc'});
    });

    test('ValidationErrors.fromJson roundtrips through JsonObject', () {
      final original = ValidationErrors();
      original.add(
        'email',
        const ValidationError(
          code: 'email',
          message: 'Invalid email',
          params: {'value': 'bad'},
        ),
      );
      original.add(
        'address.zip',
        const ValidationError(
          code: 'length',
          params: {'min': 3},
        ),
      );
      original.add(
        'items.0.title',
        const ValidationError(code: 'required'),
      );

      final jsonMap = original.toJson();
      final parsed = ValidationErrors.fromJson(JsonObject(jsonMap));

      check(parsed.hasError('email')).isTrue();
      check(parsed.hasError('address.zip')).isTrue();
      check(parsed.hasError('items.0.title')).isTrue();

      check(
        parsed.errors['email'],
      ).isNotNull().deepEquals(original.errors['email']!);
      check(
        parsed.errors['address.zip'],
      ).isNotNull().deepEquals(original.errors['address.zip']!);
      check(
        parsed.errors['items.0.title'],
      ).isNotNull().deepEquals(original.errors['items.0.title']!);
      check(parsed.toJson()).deepEquals(jsonMap);
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

      check(err1).equals(err2);
      check(err1).not((it) => it.equals(err3));
    });
  });

  group('ValidationRule tests', () {
    test('length rule', () {
      final rule = ValidationRule.length(min: 3, max: 5);
      check(rule.validate('abc')).isNull();
      check(
        rule.validate('ab'),
      ).isNotNull().has((e) => e.code, 'code').equals('length');
      check(
        rule.validate('abcdef'),
      ).isNotNull().has((e) => e.code, 'code').equals('length');

      final eqRule = ValidationRule.length(equal: 4);
      check(eqRule.validate('1234')).isNull();
      check(
        eqRule.validate('123'),
      ).isNotNull().has((e) => e.code, 'code').equals('length');
    });

    test('range rule', () {
      final rule = ValidationRule.range(min: 10, max: 20);
      check(rule.validate(15)).isNull();
      check(
        rule.validate(5),
      ).isNotNull().has((e) => e.code, 'code').equals('range');
      check(
        rule.validate(25),
      ).isNotNull().has((e) => e.code, 'code').equals('range');

      final exclRule = ValidationRule.range(exclusiveMin: 5, exclusiveMax: 10);
      check(exclRule.validate(7)).isNull();
      check(
        exclRule.validate(5),
      ).isNotNull().has((e) => e.code, 'code').equals('range');
      check(
        exclRule.validate(10),
      ).isNotNull().has((e) => e.code, 'code').equals('range');
    });

    test('email rule', () {
      final rule = ValidationRule.email();
      check(rule.validate('test@example.com')).isNull();
      check(rule.validate('user@[127.0.0.1]')).isNull();
      check(
        rule.validate('not-an-email'),
      ).isNotNull().has((e) => e.code, 'code').equals('email');
      check(
        rule.validate(''),
      ).isNotNull().has((e) => e.code, 'code').equals('email');
    });

    test('url rule', () {
      final rule = ValidationRule.url();
      check(rule.validate('https://dart.dev')).isNull();
      check(
        rule.validate('just_text'),
      ).isNotNull().has((e) => e.code, 'code').equals('url');
    });

    test('ip, ipv4, ipv6 rules', () {
      check(ValidationRule.ip().validate('127.0.0.1')).isNull();
      check(ValidationRule.ipv4().validate('127.0.0.1')).isNull();
      check(ValidationRule.ipv6().validate('::1')).isNull();
      check(
        ValidationRule.ipv4().validate('invalid'),
      ).isNotNull().has((e) => e.code, 'code').equals('ipv4');
      check(
        ValidationRule.ipv6().validate('invalid'),
      ).isNotNull().has((e) => e.code, 'code').equals('ipv6');
    });

    test('contains and doesNotContain rules', () {
      check(ValidationRule.contains('foo').validate('foobar')).isNull();
      check(
        ValidationRule.contains('baz').validate('foobar'),
      ).isNotNull().has((e) => e.code, 'code').equals('contains');
      check(ValidationRule.doesNotContain('baz').validate('foobar')).isNull();
      check(
        ValidationRule.doesNotContain('foo').validate('foobar'),
      ).isNotNull().has((e) => e.code, 'code').equals('does_not_contain');
    });

    test('mustMatch, regex, nonControlCharacter, custom rules', () {
      check(ValidationRule.mustMatch('secret').validate('secret')).isNull();
      check(
        ValidationRule.mustMatch('secret').validate('wrong'),
      ).isNotNull().has((e) => e.code, 'code').equals('must_match');

      final reg = ValidationRule.regex(RegExp(r'^\d+$'));
      check(reg.validate('12345')).isNull();
      check(
        reg.validate('abc'),
      ).isNotNull().has((e) => e.code, 'code').equals('regex');

      final nonCtrl = ValidationRule.nonControlCharacter();
      check(nonCtrl.validate('Hello World')).isNull();
      check(
        nonCtrl.validate('Hello\x00World'),
      ).isNotNull().has((e) => e.code, 'code').equals('non_control_character');

      final custom = ValidationRule.custom<int>(
        (v) => v < 0 ? const ValidationError(code: 'negative') : null,
      );
      check(custom.validate(5)).isNull();
      check(
        custom.validate(-1),
      ).isNotNull().has((e) => e.code, 'code').equals('negative');
    });

    test('credit card Luhn rule', () {
      final rule = ValidationRule.creditCard();
      check(rule.validate('4532015112830366')).isNull();
      check(
        rule.validate('1234567890'),
      ).isNotNull().has((e) => e.code, 'code').equals('credit_card');
    });
  });
}
