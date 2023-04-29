require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.construction_manager")
require("lib.gui")
require("lib.station_manager")

local bl = require("lib.ghosts_on_water_port.blueprints")
local constants = require("constants")
local table_lib = require('__stdlib__/stdlib/utils/table')

local next = next

function initGlobal()

    initWorkerStationRegister()

    initConstructionTasks()

    initPlayersGui()

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

    if destroy_ghost then event.created_entity.destroy() return end

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

-- user triggered keyboard shortcut
script.on_event("test-custom-hotkey", function(event)
    if event then

        local gui_main_frame = get_player_screen(event.player_index).buex_main_frame

        if gui_main_frame ~= nil then
            gui_main_frame.destroy()
        end

        global.construction_tasks = nil
        
        initGlobal()

        --replaceEntityWithSchmentity(event)
        getLogisticCell(event)
    end
    end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player_index = event.player_index
    global.cursor_blueprint_cache[player_index] = {}
    global.catch_deconstruction_order[player_index] = nil
end)

script.on_event(defines.events.on_pre_build , function(event)
    local player_index = event.player_index
    if global.cursor_blueprint_cache[player_index].dummy_entities ~= nil then
        global.cursor_blueprint_cache[player_index].build_params.direction = event.direction
        global.cursor_blueprint_cache[player_index].build_params.position=event.position
        global.cursor_blueprint_cache[player_index].tick = event.tick
        global.cursor_blueprint_cache[player_index].ready = true
    end
end)

script.on_event("buex-build-blueprint", function(event)
    --local stack = game.get_player(event.player_index).cursor_stack
    local player_index = event.player_index
    local player = game.players[player_index]
    local held_blueprint = player.cursor_stack
    local blueprint_type = held_blueprint.type

    if not blueprint_type then return end
    if blueprint_type == 'blueprint' then
    

        --safety check: check if cursor stack is valid
        if not held_blueprint then return end
        if not held_blueprint.valid_for_read then return end
        if not held_blueprint.is_blueprint then return end
        if not held_blueprint.is_blueprint_setup() then return end


        local blueprint_entities = held_blueprint.get_blueprint_entities()
        local dummy_entities = bl.bulkConvertEntitiesToDummies(blueprint_entities)

        global.cursor_blueprint_cache[player_index].dummy_entities = dummy_entities
        global.cursor_blueprint_cache[player_index].build_params = {
            surface=player.surface,
            force=player.force,
            force_build=true,
            skip_fog_of_war=true,
        }

    elseif blueprint_type == 'deconstruction-item' then
        global.catch_deconstruction_order[player_index] = true
    end
end)
