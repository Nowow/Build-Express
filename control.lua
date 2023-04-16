require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.events")
require("lib.construction_manager")
require("lib.gui")
require("lib.station_manager")

local next = next

function initGlobal()

    initWorkerStationRegister()

    if not global.construction_tasks then
		global.construction_tasks = {
            NEW = {},
            UNASSIGNED = {},
            ASSIGNED = {},
            BUILDING = {},
        }
	end
    if not global.gui_player_info then
        global.gui_player_info = {}
    end
    for i, p in pairs(game.players) do
        if not global.gui_player_info[i] then
            global.gui_player_info[i] = {
                -- gui vars go here
                gui_created=false,
            }
        end

        if not global.gui_player_info[i].gui_created then

        -- mod-gui gutton 
        local button_flow = mod_gui.get_button_flow(p)
        button_flow.add{type="sprite-button", name="buex_open_gui", sprite="item/locomotive", style=mod_gui.button_style}
        
        createTestWidget(i)

        global.gui_player_info[i].gui_created = true

        end
        
    end

    
    

end 

script.on_configuration_changed(function(data)
	initGlobal()
end)

script.on_init(function()
	initGlobal()
end)

-- script.on_event(defines.events.on_tick, function(event)
-- 	update_cam_position()
-- end)

script.on_event(defines.events.on_player_created, function(event)
    if not global.gui_player_info then
        global.gui_player_info = {}
    end
    if not global.gui_player_info[event.player_index] then
        global.gui_player_info[event.player_index] = {}
    end
end)

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
    
    if game.players[event.player_index].is_cursor_blueprint() then
        local stack = game.get_player(event.player_index).cursor_stack
        if stack.valid_for_read then
            local blueprint_label = stack.label
            local event_tick = event.tick
            local player_index = event.player_index
            if not blueprint_entity_cache[player_index] then
                blueprint_entity_cache[player_index] = {}
            end
            if not blueprint_entity_cache[player_index][blueprint_label] then
                blueprint_entity_cache[player_index][blueprint_label] = {}
            end
            if not blueprint_entity_cache[player_index][blueprint_label][event_tick] then
                blueprint_entity_cache[player_index][blueprint_label][event_tick] = {}
            end
            table.insert(blueprint_entity_cache[player_index][blueprint_label][event_tick], event.created_entity)
        end
    end
    
end, {{filter = "ghost"}, {filter = 'name', name = 'test-train-stop'}})

script.on_event(defines.events.on_player_setup_blueprint, function(e)
    game.print("THAT EVENT FIRED")
end)



-- user triggered keyboard shortcut
script.on_event("test-custom-hotkey", function(event)
    if event then

       
    
        --create_entity_cam(event)
    
        
        PrintSelectedBlueprintName(event)
    
        --PrintEntityCollisionMasks(selected_entity)
        
        --CheckIfRailsIsAccessible(selected_entity)
    
        -- makeRegistredTrainsGoToRail(selected_entity)
        
        -- checkIfRailIsInSameRailroad(selected_entity)
        
        -- game.print(selected_entity.position.x .. ' ' .. selected_entity.position.y)
        -- FindNearestRails(surface, selected_entity.position, 10)
    end
    end)
