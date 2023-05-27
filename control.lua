require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.construction_manager")
require("lib.gui")
require("lib.station_manager")

local constants = require("constants")
local table_lib = require('__stdlib__/stdlib/utils/table')
local pathfinder = require("lib.pathfinder")

local next = next

if script.active_mods["gvv"] then require("__gvv__.gvv")() end

function initGlobal()

    initWorkerStationRegister()

    initConstructionTasks()

    initPlayersGui()
    
    pathfinder.init()

    initOrderCaches()

    local emptySpaceTileCollisionLayerPrototype = game.entity_prototypes["collision-mask-empty-space-tile"]
    if emptySpaceTileCollisionLayerPrototype then
        global.emptySpaceCollsion = table_lib.first(table_lib.keys(emptySpaceTileCollisionLayerPrototype.collision_mask))
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

script.on_event(defines.events.on_built_entity, function(event)

    if event.created_entity.prototype.name == constants.buex_depot_name then

        local entity = event.created_entity
        registerWorkerStation(entity)
        --createBlueprintFrames(event.player_index)
        return

    end
    
    local player_index = event.player_index
    local destroy_ghost = global.blueprint_posted_trigger[player_index]
    local created_entity = event.created_entity

    if destroy_ghost and created_entity.valid then created_entity.destroy() return end

end, {{filter = "ghost"}, {filter = 'name', name = constants.buex_depot_name}})

script.on_event(defines.events.on_marked_for_deconstruction, function(event)
    local player_index = event.player_index
    local tick = event.tick
    local entity = event.entity
    if not entity.valid then return end
    if global.deconstruction_posted_trigger[player_index] then
        if not global.catch_deconstruction_order[player_index].cache then
            global.catch_deconstruction_order[player_index].cache = {}
        end
        if global.catch_deconstruction_order[player_index].cache[tick] == nil then
            global.catch_deconstruction_order[player_index].cache[tick] = {}
        end
        table.insert(global.catch_deconstruction_order[player_index].cache[tick], entity)
    end

end)
