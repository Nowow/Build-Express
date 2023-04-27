require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.construction_manager")
require("lib.gui")
require("lib.station_manager")

local bl = require("lib.ghosts_on_water_port.blueprints")
local constants = require("constants")

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
    local destroy_ghost = global.cursor_blueprint_cache[player_index].destroy_ghost_at_build_event

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
        
    end
    end)

-- script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
--     local player_index = event.player_index
--     local player = game.players[player_index]
--     local player_inventory = player.get_inventory(defines.inventory.character_main)
--     local item, i = global.blueprint_cache_inventory.find_item_stack('blueprint')
--     if item ~= nil then
--         player_inventory.insert(item)
--     end

--     -- if player_index == cached_blueprint_player_index then
--     --     local blueprint = global.cursor_blueprint_cache.blueprint
--     --     game.print("name " .. blueprint.name)
--     --     blueprint.set_blueprint_entities(global.cursor_blueprint_cache.original_entities_cache)
--     --     global.cursor_blueprint_cache = {}
--     -- end
-- end)

script.on_event(defines.events.on_pre_build , function(event)
    local player_index = event.player_index
    log("ON PREBUILD CALLED")
    if global.cursor_blueprint_cache[player_index].dummy_entities ~= nil then
        log("")
        global.cursor_blueprint_cache[player_index].build_params.direction = event.direction
        global.cursor_blueprint_cache[player_index].tick = event.tick
        global.cursor_blueprint_cache[player_index].ready = true
    end
end)

script.on_event("buex-build-blueprint", function(event)
    --local stack = game.get_player(event.player_index).cursor_stack
    local player_index = event.player_index
    local player = game.players[player_index]
    local held_blueprint = player.cursor_stack

    --safety check: check if cursor stack is valid
    if not held_blueprint then return end
    if not held_blueprint.valid_for_read then return end
    if not held_blueprint.is_blueprint then return end
    if not held_blueprint.is_blueprint_setup() then return end


    local blueprint_entities = held_blueprint.get_blueprint_entities()
    local dummy_entities = bl.bulkConvertEntitiesToDummies(blueprint_entities)

    global.cursor_blueprint_cache[player_index].destroy_ghost_at_build_event = true
    global.cursor_blueprint_cache[player_index].dummy_entities = dummy_entities
    global.cursor_blueprint_cache[player_index].build_params = {
        surface=player.surface,
        force=player.force,
        position=event.cursor_position,
        force_build=true,
        skip_fog_of_war=true,
    }
    
    
    -- placing a copy of blueprint in players inventory
    --global.blueprint_cache_inventory.insert(held_blueprint)
  
    --held_blueprint.set_blueprint_entities(dummy_entities)

    -- player.cursor_stack.set_stack(og_blueprint.name)
    -- player.cursor_stack.set_blueprint_entities(dummy_entities)

    -- local new_bp = player.cursor_stack
    -- local built_ghost_dummies = og_blueprint.build_blueprint({
    --     surface=player.surface,
    --     force=player.force,
    --     position=cursor_position,
    --     force_build=true,
    --     skip_fog_of_war=true,
    --     --direction=defines.direction.southeast
    -- })
    -- -- placing og blueprint back into cursor
    -- player.cursor_stack.set_stack(og_blueprint)

    -- --placing entities in cache 
    -- if not blueprint_entity_cache[player_index] then
    --     blueprint_entity_cache[player_index] = {}
    -- end
    -- if not blueprint_entity_cache[player_index][blueprint_label] then
    --     blueprint_entity_cache[player_index][blueprint_label] = {}
    -- end
    --     blueprint_entity_cache[player_index][blueprint_label][event_tick] = built_ghost_dummies

end)
