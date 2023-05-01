
local custom_test_input = {
  type = "custom-input",
  name = "test-custom-hotkey",
  key_sequence = "SHIFT + I"
}

local custom_test_input_a = {
  type = "custom-input",
  name = "test-custom-hotkey-a",
  key_sequence = "SHIFT + V"
}

local build_buex_blueprint = {
  type = "custom-input",
  name = "buex-build-blueprint",
  key_sequence = "CONTROL + SHIFT + mouse-button-1"
}

data:extend({custom_test_input, build_buex_blueprint, custom_test_input_a})
