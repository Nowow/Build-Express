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

function initGlobal()

    initWorkerStationRegister()

    initConstructionTasks()

    initPlayersGui()
    
    pathfinder.init()

    if global.cursor_blueprint_cache == nil then
        global.cursor_blueprint_cache = {}
    end
    for i, p in pairs(game.players) do
        if not global.cursor_blueprint_cache[i] then
            global.cursor_blueprint_cache[i] = {}
        end
    end

    if global.catch_deconstruction_order == nil then
        global.catch_deconstruction_order = {}
    end

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

-- script.on_event(defines.events.on_tick, function(event)
-- 	update_cam_position()
-- end)



-- when a train station is destroyed
script.on_event(defines.events.on_entity_renamed, function(event)

    local entity = event.entity
    if event.entity.name == 'test-train-stop' then
        unregisterWorkerStation(entity.backer_name, entity)
        createBlueprintFrames(event.player_index)
    end

end)

-- when a train station is renamed
script.on_event(defines.events.on_entity_renamed, function(event)

    local entity = event.entity
    if entity.name == 'test-train-stop' then
        game.print("STATION NAME CHANGED FROM " .. event.old_name .. ' TO ' .. event.entity.backer_name)

        unregisterWorkerStation(event.old_name, entity)
        registerWorkerStation(entity)
        createBlueprintFrames(event.player_index)
        
    end

end)

script.on_event(defines.events.on_built_entity, function(event)


    if event.created_entity.prototype.name == 'test-train-stop' then

        local entity = event.created_entity

        registerWorkerStation(entity)
        createBlueprintFrames(event.player_index)
        return

    end
    
    local player_index = event.player_index
    local destroy_ghost = global.cursor_blueprint_cache[player_index].ready
    local created_entity = event.created_entity

    if destroy_ghost and created_entity.valid then created_entity.destroy() return end
    

    -- if player.is_cursor_blueprint() and not player.cursor_stack_temporary then
    --     local stack = game.get_player(event.player_index).cursor_stack
    --     if stack.valid_for_read then
    --         local blueprint_label = stack.label
    --         local event_tick = event.tick
    --         local player_index = event.player_index
    --         if not blueprint_entity_cache[player_index] then
    --             blueprint_entity_cache[player_index] = {}
    --         end
    --         if not blueprint_entity_cache[player_index][blueprint_label] then
    --             blueprint_entity_cache[player_index][blueprint_label] = {}
    --         end
    --         if not blueprint_entity_cache[player_index][blueprint_label][event_tick] then
    --             blueprint_entity_cache[player_index][blueprint_label][event_tick] = {}
    --         end
    --         table.insert(blueprint_entity_cache[player_index][blueprint_label][event_tick], event.created_entity)
    --     end
    -- end
    
end, {{filter = "ghost"}, {filter = 'name', name = 'test-train-stop'}})



script.on_event(defines.events.on_marked_for_deconstruction, function(event)
    local player_index = event.player_index
    local tick = event.tick
    local entity = event.entity
    if not entity.valid then return end
    if global.catch_deconstruction_order[player_index] then
        if deconstruct_entity_cache[player_index] == nil then
            deconstruct_entity_cache[player_index] = {}
        end
        if deconstruct_entity_cache[player_index][tick] == nil then
            deconstruct_entity_cache[player_index][tick] = {}
        end 
        table.insert(deconstruct_entity_cache[player_index][tick], entity)
    end
end)
