require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.gui")
require("lib.station_manager")
require("lib.concepts.task_queue")
require("lib.concepts.task")
require("lib.concepts.ecu_task")
require("settings")

local constants = require("constants")
local landfill = require("lib.ghosts_on_water_port.landfillPlacer")
local util = require('util')
local next = next

deconstruct_entity_cache = {}

function initConstructionTasks()
    if not global.construction_tasks then
        ---@type { [string]: TaskQueue }
        global.construction_tasks = {}
    end
    for task_state, _ in pairs(constants.TASK_STATES) do
        if global.construction_tasks[task_state] == nil then
            game.print("CREATING EMPTY QUEUE FOR " .. task_state .. " TASK STATE IN global.construction_tasks")
            global.construction_tasks[task_state] = TaskQueue:create(task_state)
        end
    end
end

script.on_event(defines.events.on_tick, function(event)

    for player_index, cache in pairs(global.cursor_blueprint_cache) do
        if cache.ready then
            game.print('Calling build blueprint for player ' .. player_index)
            local current_tick = event.tick
            local building_tick = cache.tick
            if current_tick > building_tick then
                local player = game.players[player_index]
                -- little race unsafe, if player manages to lose blueprint from cursor stack in 1 tick
                -- could be made safe with create_inventory, but probably will bother later
                local blueprint = player.cursor_stack
                local blueprint_label = blueprint.label or blueprint.label == nil and constants.unlabeled_blueprints_placeholder_label
                local blueprint_entities = blueprint.get_blueprint_entities()
                local cost_to_build = blueprint.cost_to_build
                local build_params = cache.build_params
                blueprint.set_blueprint_entities(cache.dummy_entities)
                global.cursor_blueprint_cache[player_index].ready = nil
                local built_ghost_dummies = blueprint.build_blueprint({
                        surface=build_params.surface,
                        force=build_params.force,
                        position=build_params.position,
                        force_build=build_params.force_build,
                        skip_fog_of_war=build_params.skip_fog_of_war,
                        direction=build_params.direction
                })
                blueprint.set_blueprint_entities(blueprint_entities)
                if next(built_ghost_dummies) ~= nil then
                    local task = EcuTask:new()
                    task:initialize({
                        player_index=player_index,
                        type=constants.TASK_TYPES.BUILD,
                        tick=building_tick,
                        blueprint_label=blueprint_label,
                        entities=built_ghost_dummies,
                        cost_to_build=cost_to_build
                    })
                    task:changeState(constants.TASK_STATES.TASK_CREATED)
                else
                    log("NO DUMMIES GOT BUILT")
                end
            end
        end
    end
    
end)

-- move create tasks from cached build ghosts 
script.on_nth_tick(30, function(event)
    if next(deconstruct_entity_cache) == nil then
        return
    end
    log('Reached deconstruction task assembler')
    
    for player_index, tick_cache in pairs(deconstruct_entity_cache) do
        for tick, cache in pairs(tick_cache) do
            if tick == event.tick then
                return
            end
            local task = EcuTask:new()
            task:initialize({
                player_index=player_index,
                type=constants.TASK_TYPES.DECONSTRUCT,
                tick=tick,
                blueprint_label=constants.deconstruction_blueprint_label_placeholder,
                entities=cache
            })
            task:changeState(constants.TASK_STATES.TASK_CREATED)
            deconstruct_entity_cache[player_index][tick] = nil
        end
        deconstruct_entity_cache[player_index] = nil
    end
end)

-- formulating construnstruction plan
script.on_nth_tick(31, function(event)
    if next(global.construction_tasks.TASK_CREATED.data) == nil then
        return
    end

    log('Reached TASK_CREATED handler')
    
    
    local task = global.construction_tasks.TASK_CREATED:pop()

    task:TASK_CREATED()

end)

-- assigning train to task
script.on_nth_tick(32, function(event)
    if next(global.construction_tasks.UNASSIGNED.data) == nil then
        return
    end
    
    log('Reached UNASSIGNED handler')

    local task = global.construction_tasks.UNASSIGNED:pop()

    task:UNASSIGNED()

end)

-- assigning train to task
script.on_nth_tick(33, function(event)
    if next(global.construction_tasks.PARKING.data) == nil then
        return
    end
    
    log('Reached PARKING handler')

    local task = global.construction_tasks.PARKING:pop()

    task:PARKING()

end)


-- modifying changes before dispatching
-- place tile ghosts under water hovering entity ghosts
script.on_nth_tick(34, function(event)
    if next(global.construction_tasks.PREPARING.data) == nil then
        return
    end

    log('Reached PREPARING handler')

    local task = global.construction_tasks.PREPARING:pop()
    task:PREPARING()
end)


---- building loop ----
--   pick active subtask and send worker to build
script.on_nth_tick(35, function(event)
    if next(global.construction_tasks.ASSIGNED.data) == nil then
        return
    end
    
    local task = global.construction_tasks.ASSIGNED:pop()
    task:ASSIGNED()
end)

---- building loop ----
--   manage completion of an active subtask
script.on_nth_tick(36, function(event)
    if next(global.construction_tasks.BUILDING.data) == nil then
        return
    end

    local task = global.construction_tasks.BUILDING:pop()
    task:BUILDING()
end)

-- termination
script.on_nth_tick(37, function(event)
    if next(global.construction_tasks.TERMINATING.data) == nil then
        return
    end

    log('Reached TERMINATING handler')
    
    local task = global.construction_tasks.TERMINATING:pop()
    task:TERMINATING()
end)

script.on_event(defines.events.on_gui_click, function(event)

    local element = event.element

    if element.name == "buex_open_gui" then
        toggleTestWidget(event.player_index)
        return
    end

    if element.name == "buex_task_delete_button" then
        local element_tags = element.tags
        local task = global.construction_tasks[element_tags.task_state]:lookup(element_tags.task_id)
        game.print("END BUTTON CALLED, TAGS ".. task.id .. ', STATE ' .. task.state)
        task:endTask()
        return
    end
end)
