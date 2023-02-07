require("lib.utils")
require("lib.trains")
require("lib.test_buttons")
require("lib.blueprints")

local next = next


function initGlobal()
	if not global.registred_trains then
		global.registred_trains = {}
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
    PrintTrainWhereabouts(event.train)

    local station = event.train.station

    if station ~= nil and station.name == 'test-train-stop' and global.registred_trains[train.id] == nil then
        global.registred_trains[train.id] = train
        game.print('Registred train ' .. train.id)
    end

    -- local registred_train_ids = {"", 'Registed trains count: '}
    -- for unit, _ in pairs(global.registred_trains) do
    --     table.insert(registred_train_ids, unit)
    -- end
    -- game.print(registred_train_ids)

end
)

function hightlighRail(rail)
    local color = {r = 0, g = 1, b = 0}
    local rail_box = {
        {rail.position.x - 1, rail.position.y - 1},
        {rail.position.x + 1, rail.position.y + 1}
    }
    rendering.draw_rectangle({
        left_top=rail_box[1],
        right_bottom=rail_box[2],
        color=color,
        surface=rail.surface,
        time_to_live=300
    })
end


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


script.on_nth_tick(30, function(event)
    if next(blueprint_entity_cache) == nil then
        return
    end
    
    for player_index, tick_cache in pairs(blueprint_entity_cache) do
        for tick, cache in pairs(tick_cache) do
            if tick == event.tick then
                return
            end
            local task = createTask(tick, player_index, cache)
            task.bounding_box = findBlueprintBoundigBox(task.ghosts_to_build)
            task.subtasks = solveBoundingBoxSubdivision(task.bounding_box, 60)
            table.insert(construction_tasks, task)
            for _, st in pairs(task.subtasks) do
                hightligtBoundingBox(st.bounding_box)
            end
        end
    end
end)
