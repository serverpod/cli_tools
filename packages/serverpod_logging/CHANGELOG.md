## 0.2.0

> Note: This release has breaking changes.

 - **FIX**: Wire MultiLogWriter.add into the writer chain ([#120](https://github.com/serverpod/cli_tools/issues/120)). ([3b7a945f](https://github.com/serverpod/cli_tools/commit/3b7a945f702d07b7583213a18c645020be433140))
 - **FEAT**(serverpod_logging): Add isolate-backed IsolatedLogWriter ([#123](https://github.com/serverpod/cli_tools/issues/123)). ([a9cf5b30](https://github.com/serverpod/cli_tools/commit/a9cf5b3028b8317bc63f20b1e06098a4410c4eb2))
 - **FEAT**: Add isolated_object package ([#121](https://github.com/serverpod/cli_tools/issues/121)). ([11a7fcf3](https://github.com/serverpod/cli_tools/commit/11a7fcf34b1a559a9df6e0896f97ec6be6a2bf4b))
 - **BREAKING** **CHORE**: Bumped min Dart SDK version to 3.9.0 ([#131](https://github.com/serverpod/cli_tools/issues/131)). ([712e19ac](https://github.com/serverpod/cli_tools/commit/712e19aca0856f83f1f04f91db9018e5eda6e04b))

## 0.1.0

- Add `IsolatedLogWriter`, a `LogWriter` that runs a wrapped writer on a
  dedicated isolate (via `package:isolated_object`).
- Lower the SDK constraint to `^3.6.0`.

## 0.0.1

- Initial version.
