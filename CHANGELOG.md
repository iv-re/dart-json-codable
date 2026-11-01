## 0.3.0

- **Breaking:** name getters after Dart types: `integer`, `float` and `boolean`
  become `int`, `double` and `bool` (`json.int('age')`), and `JsonType.integer`,
  `float`, `number` and `boolean` become `JsonType.int`, `double`, `num` and
  `bool`. Add `num` and `numOrNull`.
- **Breaking:** `list`, `listOrNull`, `map` and `mapOrNull` take the item type
  as a `JsonType` instead of `mapper` and `rules`: `json.list('ids', .int)`,
  `json.list('users', .object(UserDto.fromJson))`.
- **Breaking:** `ValidationRule.range` is generic, and `int` and `double`
  take `ValidationRule<int>` and `ValidationRule<double>` rules.
- **Breaking:** type errors name types like JSON Schema in both `expected` and
  `actual`: `string`, `integer`, `number`, `boolean`, `array`, `object`, `null`.
- **Breaking:** list item errors are reported at the item path (`tags.1`), not at
  the list.
- **Breaking:** remove `ValidationRulesExtensions.validate`.
- **Breaking:** rename error codes `invalid_enum` to `enum` and
  `invalid_discriminator` to `discriminator`, matching the other codes.
- Add `JsonType` to describe how a field is decoded, validated and described in
  a schema, with `where`, `convert` and `orNull` to derive custom types, and
  `JsonObject.read` and `readOrNull` to read them.
- Add `JsonType.discriminated` for polymorphic list items and map values.
- Add `JsonSource.text` to convert string values, such as query parameters, to
  the requested type.
- `parse` reports field errors instead of rethrowing when a mapper throws on the
  placeholder values of failed fields.
- `ValidationErrors` thrown by mappers are reported at the object path.
- `parse` inside a mapper joins the enclosing parse, keeping error paths.
- Fix `list<double>` rejecting whole numbers.

## 0.2.1

- Fix schema generation for nested and collection fields (`list`, `object`, `map`) using `discriminated`.
- Add OpenAPI `discriminator` property to schemas containing `oneOf`.

## 0.2.0

- Flatten `ValidationErrors` representation using dot-notation keys (e.g. `address.zip`, `items.0.title`).
- Add `keys` getter to `JsonObject`.
- Add `ValidationError.fromJson` and `ValidationErrors.fromJson` factories.

## 0.1.0

- Initial version.