local constants = require("constants")

local buex_depot_entity = table.deepcopy(data.raw["train-stop"]["train-stop"])

buex_depot_entity.name = constants.buex_depot_name
buex_depot_entity.minable = {
  hardness = 0.2,
  mining_time = 0.5,
  result = constants.buex_depot_name
}
buex_depot_entity.icon_size = 64
buex_depot_entity.icons = {
      {
        icon = "__Build-Express__/graphics/buex_depot_icon.png",
        --tint = {r=1,g=0,b=0,a=0.3}
      }
}


local buex_depot_item = table.deepcopy(data.raw["item"]["train-stop"]) 

buex_depot_item.name = constants.buex_depot_name
buex_depot_item.icon_size = 64
buex_depot_item.place_result = constants.buex_depot_name
buex_depot_item.icons = {
      {
      icon = "__Build-Express__/graphics/buex_depot_icon.png",
      --tint = {r=1,g=0,b=1,a=0.3}
      }
}

local buex_depot_recipe = table.deepcopy(data.raw["recipe"]["train-stop"])
buex_depot_recipe.enabled = false
buex_depot_recipe.name = constants.buex_depot_name
buex_depot_recipe.ingredients = {
  {"iron-plate",6},{"steel-plate",3},{"iron-stick",6},{"electronic-circuit",5},{"advanced-circuit",10}
}
buex_depot_recipe.result = constants.buex_depot_name

data:extend{buex_depot_entity, buex_depot_item, buex_depot_recipe}

