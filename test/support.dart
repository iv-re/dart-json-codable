import 'package:checks/checks.dart';
import 'package:json_codable/json_codable.dart';

extension ValidationChecks on Subject<Object? Function()> {
  /// Expects [ValidationErrors] and checks their codes by path, such as
  /// `{'address.zip': ['length']}`.
  Subject<Map<String, List<String>>> throwsValidation() =>
      throws<ValidationErrors>().has(
        (e) => {
          for (final MapEntry(:key, :value) in e.errors.entries)
            key: [for (final error in value) error.code],
        },
        'error codes',
      );
}
