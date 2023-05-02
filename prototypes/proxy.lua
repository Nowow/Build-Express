constants = require("constants")

local character = table.deepcopy(data.raw["character"]["character"])
character.name = constants.spider_carrier_proxy_prototype_name
character.collision_mask = {"ghost-layer"}

local pathing_collision_mask = {
    "water-tile",
    "colliding-with-tiles-only",
    "not-colliding-with-itself"
  }

local pathing_proxy = {
    name = constants.pathfinding_proxy_name,
    collision_box = {{-0.5, -0.5}, {0.5, 0.5}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    type = "simple-entity",
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    icon_mipmaps = 0,
    flags = {"placeable-neutral", "not-on-map"},
    order = "z",
    max_health = 1,
    render_layer = "object",
    collision_mask = pathing_collision_mask,
    pictures = {
      {
        filename = "__core__/graphics/empty.png",
        width = 1,
        height = 1
      }
    }
  }
  
local template_item = {
    type = "item",
    flags = {
      "hidden"
    },
    name = constants.pathfinding_proxy_name,
    place_result = constants.pathfinding_proxy_name,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    order = "z",
    stack_size = 1
}

data:extend({character, pathing_proxy, template_item})

