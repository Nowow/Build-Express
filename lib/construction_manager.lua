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
local bl = require("lib.ghosts_on_water_port.blueprints")
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

function initOrderCaches()
    if global.cursor_blueprint_cache == nil then
        global.cursor_blueprint_cache = {}
    end

    if global.catch_deconstruction_order == nil then
        global.catch_deconstruction_order = {}
    end

    for i, p in pairs(game.players) do
        if not global.cursor_blueprint_cache[i] then
            global.cursor_blueprint_cache[i] = {}
        end
        if not global.catch_deconstruction_order[i] then
            global.catch_deconstruction_order[i] = {}
        end
    end
end


script.on_event(defines.events.on_tick, function(event)

    for player_index, cache in pairs(global.cursor_blueprint_cache) do
        if cache.ready then
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
                    local worker_type = build_params.worker_type
                    local task
                    if worker_type == constants.order_worker_type_express_construction_unit then
                        task = EcuTask:new()
                    else
                        task = Task:new()
                    end
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
    
    
    for player_index, info in pairs(global.catch_deconstruction_order) do
        log('Reached deconstruction task assembler')
        if info.ready then
            local cache = info.cache
            for tick, tick_cache in pairs(cache) do
                if tick == event.tick then
                    return
                end
                local worker_type = info.worker_type
                local task
                if worker_type == constants.order_worker_type_express_construction_unit then
                    task = EcuTask:new()
                else
                    task = Task:new()
                end
                task:initialize({
                    player_index=player_index,
                    type=constants.TASK_TYPES.DECONSTRUCT,
                    tick=tick,
                    blueprint_label=constants.deconstruction_blueprint_label_placeholder,
                    entities=tick_cache
                })
                task:changeState(constants.TASK_STATES.TASK_CREATED)
                global.catch_deconstruction_order[tick] = nil
            end
            deconstruct_entity_cache[player_index] = nil
        end
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

function handleConstructionOrder(event, worker_type)
    local player_index = event.player_index
    local player = game.players[player_index]
    local held_blueprint = player.cursor_stack

    --safety check: check if cursor stack is valid
    if not held_blueprint then return end
    if not held_blueprint.valid_for_read then return end

    local blueprint_type = held_blueprint.type

    if not blueprint_type then return end
    if blueprint_type == 'blueprint' then
        
        if not held_blueprint.is_blueprint then return end
        if not held_blueprint.is_blueprint_setup() then return end


        local blueprint_entities = held_blueprint.get_blueprint_entities()
        local dummy_entities = bl.bulkConvertEntitiesToDummies(blueprint_entities)

        global.cursor_blueprint_cache[player_index] = {}
        global.cursor_blueprint_cache[player_index].worker_type = worker_type
        global.cursor_blueprint_cache[player_index].dummy_entities = dummy_entities
        global.cursor_blueprint_cache[player_index].build_params = {
            surface=player.surface,
            force=player.force,
            force_build=true,
            skip_fog_of_war=true,
        }
        displayCatchBlueprintOrderMessage(player_index, constants.order_type_blueprint, worker_type)

    elseif blueprint_type == 'deconstruction-item' then
        global.catch_deconstruction_order[player_index].ready = true
        global.catch_deconstruction_order[player_index].worker_type = worker_type
        displayCatchBlueprintOrderMessage(player_index, constants.order_type_deconstruction, worker_type)
    end
end

script.on_event("buex-build-blueprint-left", function(event)
    handleConstructionOrder(event, constants.order_worker_type_express_construction_unit)
end)

script.on_event("buex-build-blueprint-right", function(event)
    handleConstructionOrder(event, constants.order_worker_type_construcion_train)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player_index = event.player_index
    destroyCatchBlueprintOrderMessage(player_index)
    global.cursor_blueprint_cache[player_index] = {}
    global.catch_deconstruction_order[player_index] = {}
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