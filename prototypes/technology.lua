local constants = require("constants")

local build_express_tech = {
    type = "technology",
    name = constants.buex_construction_train_technology,
    icon_size = 128,
    icon = "__Build-Express__/graphics/buex_technology.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = constants.buex_depot_name
      }
    },
    prerequisites = {"personal-roboport-equipment", "railway", "ct-construction-train"},
    unit =
    {
      count = 100,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
      },
      time = 30
    },
    order = "c-k-d-zz2"
}




local express_construction_unit_tech = {
    type = "technology",
    name = constants.buex_express_construction_unit_technology,
    icon_size = 128,
    icon = "__Build-Express__/graphics/express_construction_unit_technology.png",
    effects =
    {
      {
        type = "unlock-recipe",
        recipe = constants.spider_carrier_prototype_name
      }
    },
    prerequisites = {name = constants.buex_construction_train_technology, "spidertron"},
    unit =
    {
      count = 50,
      ingredients =
      {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
      },
      time = 30
    },
    order = "c-k-d-zz2"
}

data:extend({build_express_tech, express_construction_unit_tech})
