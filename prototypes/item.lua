local test_train_stop = table.deepcopy(data.raw["item"]["train-stop"]) 

test_train_stop.name = "test-train-stop"
test_train_stop.icon_size = 32
test_train_stop.icons = {
    {icon = test_train_stop.icon}, {
        icon = "__Build-Express__/resources/test_icon.png",
        tint = {r=1,g=0,b=0,a=0.3}
      }
}


local recipe = table.deepcopy(data.raw["recipe"]["train-stop"])
recipe.enabled = true
recipe.name = "test-train-stop"
recipe.ingredients = {{"copper-plate",200},{"steel-plate",50}}
recipe.result = "test-train-stop"

data:extend{test_train_stop,recipe}
