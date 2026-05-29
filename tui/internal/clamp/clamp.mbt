///|
pub fn int(value : Int, min? : Int, max? : Int) -> Int {
  let mut value = value
  if min is Some(min_value) {
    if value < min_value {
      value = min_value
    }
  }
  if max is Some(max_value) {
    if value > max_value {
      value = max_value
    }
  }
  value
}
