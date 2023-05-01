constants = require("constants")

local character = table.deepcopy(data.raw["character"]["character"])
character.name = constants.spider_carrier_proxy_prototype_name
character.collision_mask = {"ghost-layer"}

data:extend({character})