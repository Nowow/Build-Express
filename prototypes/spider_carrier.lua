constants = require("constants")


local e
local tint = {0.5, 0.0, 0.5}

e = table.deepcopy(data.raw["cargo-wagon"]["cargo-wagon"])
e.name = constants.spider_carrier_prototype_name
e.icons = {{icon=e.icon, tint=tint}}
e.minable.result = e.name
e.weight = 4000
e.inventory_size = 100
e.equipment_grid = constants.spider_carrier_grid_prototype_name
e.inventory_size = 1
e.allow_robot_dispatch_in_automatic_mode = true
e.pictures.layers[1].tint = tint
e.pictures.layers[1].hr_version.tint = tint
e.pictures.layers[2].tint = tint
e.pictures.layers[2].hr_version.tint = tint
e.horizontal_doors.layers[1].tint = tint
e.horizontal_doors.layers[1].hr_version.tint = tint
e.horizontal_doors.layers[2].tint = tint
e.horizontal_doors.layers[2].hr_version.tint = tint
e.horizontal_doors.layers[3].tint = tint
e.horizontal_doors.layers[3].hr_version.tint = tint
e.horizontal_doors.layers[4].tint = tint
e.horizontal_doors.layers[4].hr_version.tint = tint
e.horizontal_doors.layers[5].tint = tint
e.horizontal_doors.layers[5].hr_version.tint = tint
e.vertical_doors.layers[1].tint = tint
e.vertical_doors.layers[1].hr_version.tint = tint
e.vertical_doors.layers[2].tint = tint
e.vertical_doors.layers[2].hr_version.tint = tint
e.vertical_doors.layers[3].tint = tint
e.vertical_doors.layers[3].hr_version.tint = tint
e.vertical_doors.layers[4].tint = tint
e.vertical_doors.layers[4].hr_version.tint = tint
e.vertical_doors.layers[5].tint = tint
e.vertical_doors.layers[5].hr_version.tint = tint

local item = {
    type = "item-with-entity-data",
    name = e.name,
    icons = e.icons,
    icon_size = 64, icon_mipmaps = 4,
    subgroup = "train-transport",
    order = "a[train-system]-g2[cargo-wagon]",
    place_result = e.name,
    stack_size = 5
  }

local recipe = {
    type = "recipe",
    name = e.name,
    energy_required = 5,
    enabled = true,
    ingredients =
    {
      {"iron-gear-wheel", 40},
      {"steel-plate", 100},
      {"advanced-circuit", 50}
    },
    result = e.name
  }

local equipment_category = {
    type = "equipment-category",
    name = constants.spider_carrier_equipment_category_prototype_name
  }

local grid = {
    type = "equipment-grid",
    name = constants.spider_carrier_grid_prototype_name,
    width = 12,
    height = 10,
    equipment_categories = {"armor", constants.spider_carrier_equipment_category_prototype_name}
  }

-- TBD
local technology = {
    type = "technology",
    name = constants.buex_technology,
    icon_size = 128,
    icon = "__construction-train__/graphics/technology/ct-construction-train.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = "ct-construction-wagon"
      }
    },
    prerequisites = {"personal-roboport-equipment", "railway"},
    unit =
    {
      count = 50,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1}
      },
      time = 30
    },
    order = "c-k-d-zz2"
  }

data:extend({e, item, recipe, equipment_category, grid})

-- if mods["basic-robots"] then
--   data.raw.technology["ct-construction-train"].prerequisites = {"basic-robots-robotics", "railway"}
--   data.raw.technology["ct-construction-train"].unit.ingredients = {{"automation-science-pack", 1}, {"logistic-science-pack", 1}}
-- end
-- if mods["Krastorio2"] then
--   data.raw["cargo-wagon"]["ct-construction-wagon"].equipment_grid = "kr-wagons-grid"
--   data.raw.recipe["ct-construction-wagon"].energy_required = data.raw.recipe["cargo-wagon"].energy_required
-- end
-- if mods["space-exploration"] then
--   data.raw["item-with-entity-data"]["ct-construction-wagon"].subgroup = "rail"
-- end
