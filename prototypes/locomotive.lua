local constants = require("constants")

local color = {r=1, g=0.914, b=0.525}
local buex_locomotive = table.deepcopy(data.raw['locomotive']['locomotive'])
buex_locomotive.name = constants.buex_locomotive
buex_locomotive.color = color
buex_locomotive.minable.result = constants.buex_locomotive

local buex_locomotive_item = table.deepcopy(data.raw['item-with-entity-data']['locomotive'])
buex_locomotive_item.name = constants.buex_locomotive
buex_locomotive_item.color = color
buex_locomotive_item.place_result = constants.buex_locomotive

local buex_locomotive_recipe = {
    type = "recipe",
    name = constants.buex_locomotive,
    enabled = false,
    ingredients =
    {
        {"electronic-circuit", 10},
        {"advanced-circuit", 20},
        {"engine-unit", 20},
        {"steel-plate", 30},

    },
    result = constants.buex_locomotive
}

data:extend({buex_locomotive, buex_locomotive_item, buex_locomotive_recipe})

