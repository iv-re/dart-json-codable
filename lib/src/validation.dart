import 'package:equatable/equatable.dart';
import 'package:json_codable/src/json/json.dart';
import 'package:meta/meta.dart';

@immutable
class ValidationError extends Equatable implements ToJson {
  const ValidationError({
    required this.code,
    this.message,
    this.params = const {},
  });

  /// Factory for a required field validation error.
  const ValidationError.required([this.message])
    : code = 'required',
      params = const {};

  /// Factory for a field type mismatch validation error.
  ValidationError.type({
    required String expected,
    required Object? actual,
    this.message,
  }) : code = 'type',
       params = {
         'expected': expected,
         'actual': _getTypeName(actual),
       };

  /// Factory for constructing a [ValidationError] from a [JsonObject].
  factory ValidationError.fromJson(JsonObject json) {
    return ValidationError(
      code: json.string('code'),
      message: json.stringOrNull('message'),
      params: json.mapOrNull<Object?>('params') ?? const {},
    );
  }

  static String _getTypeName(Object? obj) {
    if (obj == null) return 'null';
    if (obj is String) return 'string';
    if (obj is int) return 'int';
    if (obj is double) return 'double';
    if (obj is bool) return 'bool';
    if (obj is List) return 'list';
    if (obj is Map) return 'map';
    return obj.runtimeType.toString().toLowerCase();
  }

  /// Identifier code for the validation rule (e.g. `'length'`, `'email'`).
  final String code;

  /// Optional custom display error message.
  final String? message;

  /// Map of parameter names to values (e.g. `{'min': 5, 'value': 'abc'}`).
  final Map<String, Object?> params;

  @override
  Map<String, Object?> toJson() => {
    'code': code,
    if (message != null) 'message': message,
    if (params.isNotEmpty) 'params': params,
  };

  @override
  String toString() {
    return 'ValidationError(code: $code, message: $message, params: $params)';
  }

  @override
  List<Object?> get props => [code, message, params];
}

/// Top-level container for validation errors.
class ValidationErrors implements Exception, ToJson {
  ValidationErrors([Map<String, List<ValidationError>>? errors])
    : errors = errors ?? {};

  /// Factory for constructing a [ValidationErrors] from a [JsonObject].
  factory ValidationErrors.fromJson(JsonObject json) {
    final errors = <String, List<ValidationError>>{};
    for (final key in json.keys) {
      errors[key] = json.list<ValidationError>(
        key,
        mapper: ValidationError.fromJson,
      );
    }
    return ValidationErrors(errors);
  }

  final Map<String, List<ValidationError>> errors;

  /// Check if a field has an error.
  bool hasError(String field) => errors.containsKey(field);

  /// Add a single field validation error.
  void add(String field, ValidationError error) {
    (errors[field] ??= []).add(error);
  }

  /// Add multiple validation errors for a field.
  void addAll(String field, Iterable<ValidationError> newErrors) {
    (errors[field] ??= []).addAll(newErrors);
  }

  /// Merge another ValidationErrors container with an optional prefix.
  void merge(ValidationErrors other, [String prefix = '']) {
    for (final entry in other.errors.entries) {
      final key = prefix.isEmpty ? entry.key : '$prefix.${entry.key}';
      (errors[key] ??= []).addAll(entry.value);
    }
  }

  /// True if there are no validation errors.
  bool get isEmpty => errors.isEmpty;

  /// True if there are any validation errors.
  bool get isNotEmpty => errors.isNotEmpty;

  @override
  Map<String, Object?> toJson() {
    return {
      for (final entry in errors.entries)
        entry.key: entry.value.map((e) => e.toJson()).toList(),
    };
  }

  @override
  String toString() => 'ValidationErrors(${toJson()})';
}

/// Extension on List of ValidationRule for concise field validation.
extension ValidationRulesExtensions<T> on List<ValidationRule<T>> {
  /// Evaluates all rules against [value] and returns a list of failed
  /// [ValidationError]s.
  @pragma('vm:prefer-inline')
  List<ValidationError> evaluate(T value) {
    List<ValidationError>? errors;
    for (final rule in this) {
      final err = rule.validate(value);
      if (err != null) {
        (errors ??= []).add(err);
      }
    }
    return errors ?? const [];
  }

  /// Evaluates all rules against [value] for field [key].
  /// Throws [ValidationErrors] containing ALL failed rule errors.
  @pragma('vm:prefer-inline')
  void validate(String key, T value) {
    final failed = evaluate(value);
    if (failed.isNotEmpty) {
      final container = ValidationErrors();
      for (final err in failed) {
        container.add(key, err);
      }
      throw container;
    }
  }
}

/// Interface for validation rules.
abstract interface class ValidationRule<T> {
  /// Evaluates rule against [value], returning `ValidationError?` if
  /// rule fails.
  ValidationError? validate(T value);

  /// Custom validation rule from function.
  static ValidationRule<T> custom<T>(ValidationError? Function(T value) fn) {
    return CustomValidationRule(fn);
  }

  /// String length rule (min, max, equal).
  static ValidationRule<String> length({
    int? min,
    int? max,
    int? equal,
    String? message,
  }) {
    return LengthValidationRule(
      min: min,
      max: max,
      equal: equal,
      message: message,
    );
  }

  /// Numeric range rule (min, max, exclusiveMin, exclusiveMax).
  static ValidationRule<num> range({
    num? min,
    num? max,
    num? exclusiveMin,
    num? exclusiveMax,
    String? message,
  }) {
    return RangeValidationRule(
      min: min,
      max: max,
      exclusiveMin: exclusiveMin,
      exclusiveMax: exclusiveMax,
      message: message,
    );
  }

  /// Email validation rule.
  static ValidationRule<String> email([String? message]) {
    return EmailValidationRule(message);
  }

  /// URL validation rule.
  static ValidationRule<String> url([String? message]) {
    return UrlValidationRule(message);
  }

  /// IP validation rule (IPv4 or IPv6).
  static ValidationRule<String> ip([String? message]) {
    return IpValidationRule(message);
  }

  /// IPv4 validation rule.
  static ValidationRule<String> ipv4([String? message]) {
    return Ipv4ValidationRule(message);
  }

  /// IPv6 validation rule.
  static ValidationRule<String> ipv6([String? message]) {
    return Ipv6ValidationRule(message);
  }

  /// Must contain substring rule.
  static ValidationRule<String> contains(String pattern, [String? message]) {
    return ContainsValidationRule(pattern, message);
  }

  /// Must not contain substring rule.
  static ValidationRule<String> doesNotContain(
    String pattern, [
    String? message,
  ]) {
    return DoesNotContainValidationRule(pattern, message);
  }

  /// Must match another target string rule.
  static ValidationRule<String> mustMatch(String target, [String? message]) {
    return MustMatchValidationRule(target, message);
  }

  /// Regex pattern rule.
  static ValidationRule<String> regex(RegExp pattern, [String? message]) {
    return RegexValidationRule(pattern, message);
  }

  /// Credit card number rule (Luhn algorithm).
  static ValidationRule<String> creditCard([String? message]) {
    return CreditCardValidationRule(message);
  }

  /// Non-control character rule.
  static ValidationRule<String> nonControlCharacter([String? message]) {
    return NonControlCharacterValidationRule(message);
  }
}

class CustomValidationRule<T> implements ValidationRule<T> {
  const CustomValidationRule(this._fn);

  final ValidationError? Function(T value) _fn;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(T value) => _fn(value);
}

class LengthValidationRule implements ValidationRule<String> {
  const LengthValidationRule({this.min, this.max, this.equal, this.message});

  final int? min;
  final int? max;
  final int? equal;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (equal != null && value.length != equal) {
      return ValidationError(
        code: 'length',
        message: message,
        params: {'equal': equal, 'value': value},
      );
    }
    if (min != null && value.length < min!) {
      return ValidationError(
        code: 'length',
        message: message,
        params: {'min': min, 'value': value},
      );
    }
    if (max != null && value.length > max!) {
      return ValidationError(
        code: 'length',
        message: message,
        params: {'max': max, 'value': value},
      );
    }
    return null;
  }
}

class RangeValidationRule implements ValidationRule<num> {
  const RangeValidationRule({
    this.min,
    this.max,
    this.exclusiveMin,
    this.exclusiveMax,
    this.message,
  });

  final num? min;
  final num? max;
  final num? exclusiveMin;
  final num? exclusiveMax;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(num value) {
    if (min != null && value < min!) {
      return ValidationError(
        code: 'range',
        message: message,
        params: {'min': min, 'value': value},
      );
    }
    if (max != null && value > max!) {
      return ValidationError(
        code: 'range',
        message: message,
        params: {'max': max, 'value': value},
      );
    }
    if (exclusiveMin != null && value <= exclusiveMin!) {
      return ValidationError(
        code: 'range',
        message: message,
        params: {'exclusive_min': exclusiveMin, 'value': value},
      );
    }
    if (exclusiveMax != null && value >= exclusiveMax!) {
      return ValidationError(
        code: 'range',
        message: message,
        params: {'exclusive_max': exclusiveMax, 'value': value},
      );
    }
    return null;
  }
}

class EmailValidationRule implements ValidationRule<String> {
  const EmailValidationRule([this.message]);

  final String? message;

  static final _emailUserRegExp = RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$");
  static final _emailDomainRegExp = RegExp(
    '^[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$',
  );

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!_validateEmail(value)) {
      return ValidationError(
        code: 'email',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }

  bool _validateEmail(String input) {
    if (input.isEmpty || !input.contains('@')) return false;
    final parts = input.split('@');
    if (parts.length != 2) return false;
    final user = parts[0];
    final domain = parts[1];

    if (user.length > 64 || domain.length > 255) return false;
    if (!_emailUserRegExp.hasMatch(user)) return false;
    if (_emailDomainRegExp.hasMatch(domain)) return true;

    if (domain.startsWith('[') && domain.endsWith(']')) {
      final ipStr = domain.substring(1, domain.length - 1);
      return _validateIp(ipStr);
    }
    return false;
  }
}

class UrlValidationRule implements ValidationRule<String> {
  const UrlValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.scheme.isEmpty) {
      return ValidationError(
        code: 'url',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }
}

bool _validateIpv4(String input) {
  try {
    Uri.parseIPv4Address(input);
    return true;
  } catch (_) {
    return false;
  }
}

bool _validateIpv6(String input) {
  try {
    Uri.parseIPv6Address(input);
    return true;
  } catch (_) {
    return false;
  }
}

bool _validateIp(String input) => _validateIpv4(input) || _validateIpv6(input);

class IpValidationRule implements ValidationRule<String> {
  const IpValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!_validateIp(value)) {
      return ValidationError(
        code: 'ip',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }
}

class Ipv4ValidationRule implements ValidationRule<String> {
  const Ipv4ValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!_validateIpv4(value)) {
      return ValidationError(
        code: 'ipv4',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }
}

class Ipv6ValidationRule implements ValidationRule<String> {
  const Ipv6ValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!_validateIpv6(value)) {
      return ValidationError(
        code: 'ipv6',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }
}

class ContainsValidationRule implements ValidationRule<String> {
  const ContainsValidationRule(this.pattern, [this.message]);

  final String pattern;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!value.contains(pattern)) {
      return ValidationError(
        code: 'contains',
        message: message,
        params: {'pattern': pattern, 'value': value},
      );
    }
    return null;
  }
}

class DoesNotContainValidationRule implements ValidationRule<String> {
  const DoesNotContainValidationRule(this.pattern, [this.message]);

  final String pattern;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (value.contains(pattern)) {
      return ValidationError(
        code: 'does_not_contain',
        message: message,
        params: {'pattern': pattern, 'value': value},
      );
    }
    return null;
  }
}

class MustMatchValidationRule implements ValidationRule<String> {
  const MustMatchValidationRule(this.target, [this.message]);

  final String target;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (value != target) {
      return ValidationError(
        code: 'must_match',
        message: message,
        params: {'target': target, 'value': value},
      );
    }
    return null;
  }
}

class RegexValidationRule implements ValidationRule<String> {
  const RegexValidationRule(this.pattern, [this.message]);

  final RegExp pattern;
  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!pattern.hasMatch(value)) {
      return ValidationError(
        code: 'regex',
        message: message,
        params: {'pattern': pattern.pattern, 'value': value},
      );
    }
    return null;
  }
}

class CreditCardValidationRule implements ValidationRule<String> {
  const CreditCardValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    if (!_validateLuhn(value)) {
      return ValidationError(
        code: 'credit_card',
        message: message,
        params: {'value': value},
      );
    }
    return null;
  }

  static final _spacesAndDashes = RegExp(r'\s+|-');
  static final _onlyDigits = RegExp(r'^\d+$');

  bool _validateLuhn(String input) {
    final clean = input.replaceAll(_spacesAndDashes, '');
    if (clean.isEmpty || !_onlyDigits.hasMatch(clean)) return false;

    var sum = 0;
    var alternate = false;
    for (var i = clean.length - 1; i >= 0; i--) {
      var digit = int.parse(clean[i]);
      if (alternate) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }
}

class NonControlCharacterValidationRule implements ValidationRule<String> {
  const NonControlCharacterValidationRule([this.message]);

  final String? message;

  @override
  @pragma('vm:prefer-inline')
  ValidationError? validate(String value) {
    for (final codeUnit in value.codeUnits) {
      if ((codeUnit >= 0 && codeUnit <= 31) ||
          (codeUnit >= 127 && codeUnit <= 159)) {
        return ValidationError(
          code: 'non_control_character',
          message: message,
          params: {'value': value},
        );
      }
    }
    return null;
  }
}
