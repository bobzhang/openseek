# Logger

This package provides a tiny native-only async logger for OpenSeek. It wraps an
`@stdio.Output`, applies a minimum severity level, and exposes `<+`-compatible
sinks.

## API Shape

- `Level`: `TRACE`, `DEBUG`, `INFO`, `WARN`, and `ERROR`.
- `stdout(min_level?)`: build a stdout logger.
- `Logger::at(level)`: get a level-filtered sink.
- `Logger::trace/debug/info/warn/error()`: convenience sinks.
- `Logger` itself supports `<+` as an `INFO` sink.

```moonbit check
///|
test "logger filters by severity" {
  let logger = @logger.Logger(@stdio.stdout, min_level=WARN)
  assert_false(logger.enabled(INFO))
  assert_true(logger.enabled(ERROR))
}
```
