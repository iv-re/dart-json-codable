## 0.2.1

- Fix schema generation for nested and collection fields (`list`, `object`, `map`) using `discriminated`.
- Add OpenAPI `discriminator` property to schemas containing `oneOf`.

## 0.2.0

- Flatten `ValidationErrors` representation using dot-notation keys (e.g. `address.zip`, `items.0.title`).
- Add `keys` getter to `JsonObject`.
- Add `ValidationError.fromJson` and `ValidationErrors.fromJson` factories.

## 0.1.0

- Initial version.