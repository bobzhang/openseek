///|
const DefaultEscTimeoutMs : Int = 50

///|
const DefaultComposerMaxRows : Int = @composer.DefaultMaxTextRows

///|
struct Config {
  esc_timeout_ms : Int
  composer_max_rows : Int
}

///|
pub fn Config::new(
  esc_timeout_ms? : Int = DefaultEscTimeoutMs,
  composer_max_rows? : Int = DefaultComposerMaxRows,
) -> Config {
  let esc_timeout_ms = if esc_timeout_ms < 1 {
    DefaultEscTimeoutMs
  } else {
    esc_timeout_ms
  }
  let composer_max_rows = if composer_max_rows < 1 {
    DefaultComposerMaxRows
  } else {
    composer_max_rows
  }
  { esc_timeout_ms, composer_max_rows }
}
