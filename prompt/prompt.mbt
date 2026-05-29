///|
/// Selects the built-in system prompt for a DeepSeek model.
pub fn system_prompt_for_model(model : @deepseek.Model) -> String {
  match model {
    V4Flash => flash_prompt()
    V4Pro => base_prompt()
  }
}
