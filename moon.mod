name = "bobzhang/openseek"

version = "0.1.3"

import {
  "moonbitlang/async@0.19.0",
}

readme = "README.mbt.md"

repository = "https://github.com/bobzhang/openseek"

license = "Apache-2.0"

keywords = [ ]

description = "DeepSeek-backed MoonBit coding agent"

preferred_target = "native"

rule(
  name: "md_to_mbt_string",
  command: "moon run --target native scripts/md_to_mbt_string.mbtx -- \"$input\" \"$output\"",
)
