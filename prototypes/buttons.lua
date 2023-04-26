
local custom_test_input = {
  type = "custom-input",
  name = "test-custom-hotkey",
  key_sequence = "SHIFT + I"
}

local build_buex_blueprint = {
  type = "custom-input",
  name = "buex-build-blueprint",
  key_sequence = "CONTROL + SHIFT + mouse-button-1"
}

data:extend({custom_test_input, build_buex_blueprint})
