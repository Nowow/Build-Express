
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

local build_buex_blueprint_left = {
  type = "custom-input",
  name = "buex-build-blueprint-left",
  key_sequence = "CONTROL + SHIFT + mouse-button-1"
}

local build_buex_blueprint_right = {
  type = "custom-input",
  name = "buex-build-blueprint-right",
  key_sequence = "CONTROL + SHIFT + mouse-button-2"
}

data:extend({custom_test_input, build_buex_blueprint_left, build_buex_blueprint_right, custom_test_input_a})
