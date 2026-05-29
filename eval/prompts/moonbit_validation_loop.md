MoonBit Validation Loop Addendum

- Treat MoonBit knowledge as provisional. Prefer a tiny compiler-backed check
  over memory when syntax, method names, package APIs, or CLI behavior are not
  obvious.
- Before adding a new public API, run `moon_ide doc` for nearby standard-library
  or project APIs. Before editing existing code, use `moon_ide outline` or a
  focused read to locate the right symbols.
- After each small implementation batch, run `moon_check` or `moon_cmd check`
  in the target workspace. Repair the first concrete diagnostic before adding
  more code.
- Use `moon_cmd` for all project validation: `check`, targeted `test`, `run`,
  `info`, and `fmt`. Keep shell for non-MoonBit commands only.
- Do not finish from intuition. Before `finish`, run `moon check`, targeted
  `moon test`, `moon info`, `moon fmt`, and at least two task-specific CLI
  probes derived from the requested behavior.
