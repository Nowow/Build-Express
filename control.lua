require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.construction_manager")
require("lib.gui")
require("lib.station_manager")
require("lib.ghosts_on_water_port.water_dummies_replacer")

local constants = require("constants")
local table_lib = require('__stdlib__/stdlib/utils/table')
local pathfinder = require("lib.pathfinder")

local next = next

if script.active_mods["gvv"] then require("__gvv__.gvv")() end

function initGlobal()

    initWorkerStationRegister()

    initFleetRegister()

    initConstructionTasks()

    initPlayersGui()
    
    pathfinder.init()

    initOrderCaches()

    initWaterGhostReplacerQueue()

    local emptySpaceTileCollisionLayerPrototype = game.entity_prototypes["collision-mask-empty-space-tile"]
    if emptySpaceTileCollisionLayerPrototype then
        global.emptySpaceCollsion = table_lib.first(table_lib.keys(emptySpaceTileCollisionLayerPrototype.collision_mask))
    end

    global.roboport_prototypes = {}
    local robot_limit
    for name, prototype in pairs(game.equipment_prototypes) do
        if prototype.type == "roboport-equipment" then
            robot_limit = prototype.logistic_parameters.robot_limit
            global.roboport_prototypes[name] = robot_limit
        end
    end
end 

script.on_configuration_changed(function(data)
	initGlobal()
end)

script.on_init(function()
	initGlobal()
end)

script.on_event(defines.events.on_player_created, function(event)
    initGlobal()
end)

