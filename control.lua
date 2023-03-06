require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")
require("lib.events")
require("lib.construction_manager")

local next = next

function initGlobal()
	if not global.train_register then
		global.train_register = {
            available = {},
            busy = {}
        }
	end
    if not global.construction_tasks then
		global.construction_tasks = {
            NEW = {},
            UNASSIGNED = {},
            ASSIGNED = {},
            BUILDING = {},
        }
	end
end 

script.on_configuration_changed(function(data)
	initGlobal()
end)

script.on_init(function()
	initGlobal()
end)


-- registring trains to a dispatch system
-- TODO: unregistrer trains, check if .valid

script.on_event(defines.events.on_train_changed_state,
function(event)
    --local player = game.player
    --local player_position = player.position
    local train = event.train
    --PrintTrainWhereabouts(event.train)

    local station = event.train.station

    if 
        station ~= nil and station.name == 'test-train-stop' 
        and global.train_register.available[train.id] == nil
        and global.train_register.busy[train.id] == nil
    then
        registerTrain(train)
        game.print('Registred train ' .. train.id)
    end

end
)

script.on_event(defines.events.on_built_entity, function(event)

    --hightlightEntity(e)
    
    if game.players[event.player_index].is_cursor_blueprint() then
        local event_tick = event.tick
        local player_index = event.player_index
        if not blueprint_entity_cache[player_index] then
            blueprint_entity_cache[player_index] = {}
        end
        if not blueprint_entity_cache[player_index][event_tick] then
            blueprint_entity_cache[player_index][event_tick] = {}
        end
        table.insert(blueprint_entity_cache[player_index][event_tick], event.created_entity)
    end
    
end, {{filter = "ghost"}})




-- user triggered keyboard shortcut
script.on_event("test-custom-hotkey", function(event)
    if event then
    
        HightlightCachedEntities(blueprint_entity_cache)
        findBlueprintBoundigBox(blueprint_entity_cache)
    
        
        --PrintSelectedBlueprintName(event)
    
        --PrintEntityCollisionMasks(selected_entity)
        
        --CheckIfRailsIsAccessible(selected_entity)
    
        -- makeRegistredTrainsGoToRail(selected_entity)
        
        -- checkIfRailIsInSameRailroad(selected_entity)
        
        -- game.print(selected_entity.position.x .. ' ' .. selected_entity.position.y)
        -- FindNearestRails(surface, selected_entity.position, 10)
    end
    end)
