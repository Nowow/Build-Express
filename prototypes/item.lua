
local test_train_stop_entity = table.deepcopy(data.raw["train-stop"]["train-stop"])

test_train_stop_entity.name = "test-train-stop"
test_train_stop_entity.icon_size = 32
test_train_stop_entity.icons = {
    {icon = test_train_stop_entity.icon}, {
        icon = "__Build-Express__/resources/test_icon.png",
        tint = {r=1,g=0,b=0,a=0.3}
      }
}


local test_train_stop_item = table.deepcopy(data.raw["item"]["train-stop"]) 

test_train_stop_item.name = "test-train-stop"
test_train_stop_item.icon_size = 32
test_train_stop_item.place_result = "test-train-stop"
test_train_stop_item.icons = {
    {icon = test_train_stop_item.icon}, {
        icon = "__Build-Express__/resources/test_icon.png",
        tint = {r=1,g=0,b=0,a=0.3}
      }
}

local recipe = table.deepcopy(data.raw["recipe"]["train-stop"])
recipe.enabled = true
recipe.name = "test-train-stop"
recipe.ingredients = {{"copper-plate",200},{"steel-plate",50}}
recipe.result = "test-train-stop"

data:extend{test_train_stop_entity, test_train_stop_item, recipe}

