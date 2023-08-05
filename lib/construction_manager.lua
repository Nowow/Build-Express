require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.gui")
require("lib.station_manager")
require("lib.train_register")
require("lib.concepts.task_queue")
require("lib.concepts.task")
require("lib.concepts.ecu_task")

local constants = require("constants")
local landfill = require("lib.ghosts_on_water_port.landfillPlacer")
local util = require('util')
local bl = require("lib.ghosts_on_water_port.blueprints")
local next = next

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

    if global.captured_task_cache == nil then
        global.captured_task_cache = {}
    end

    if global.blueprint_posted_trigger == nil then
        global.blueprint_posted_trigger = {}
    end

    if global.deconstruction_posted_trigger == nil then
        global.deconstruction_posted_trigger = {}
    end

    if global.order_catch_mode == nil then
        global.order_catch_mode = {}
    end

    if global.worker_type == nil then
        global.worker_type = {}
    end

    for i, p in pairs(game.players) do
        if not global.cursor_blueprint_cache[i] then
            global.cursor_blueprint_cache[i] = {}
        end
        if not global.catch_deconstruction_order[i] then
            global.catch_deconstruction_order[i] = {}
        end
        if not global.captured_task_cache[i] then
            global.captured_task_cache[i] = {}
        end
    end

end


script.on_event(defines.events.on_tick, function(event)

    if not next(global.blueprint_posted_trigger)then
        return
    end

    log('Reached blueprint task assembler')

    for player_index, cache in pairs(global.cursor_blueprint_cache) do
        local ready = global.blueprint_posted_trigger[player_index]
        if ready then
            local current_tick = event.tick
            local building_tick = cache.tick
            if current_tick <= building_tick then
                log("BAD TICK FOR CONSTRUCTION " .. current_tick .. building_tick)
                return
            end
            -- invalidate trigger for this player
            global.blueprint_posted_trigger[player_index] = nil
            local player = game.players[player_index]
            -- little race unsafe, if player manages to lose blueprint from cursor stack in 1 tick
            -- could be made safe with create_inventory, but probably will bother later
            local blueprint = player.cursor_stack
            local blueprint_label = blueprint.label or blueprint.label == nil and constants.unlabeled_blueprints_placeholder_label
            local blueprint_entities = blueprint.get_blueprint_entities()
            local build_params = cache.build_params
            blueprint.set_blueprint_entities(cache.dummy_entities)                
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
                local cost_to_build = calculateCostToBuild(built_ghost_dummies)
                cost_to_build = convertDummyCostToActualCost(cost_to_build)
                local payload = {
                    player_index=player_index,
                    type=constants.TASK_TYPES.BUILD,
                    tick=building_tick,
                    blueprint_label=blueprint_label,
                    entities=built_ghost_dummies,
                    cost_to_build=cost_to_build
                }
                local capture_mode = cache.capture_mode
                local worker_type = cache.worker_type

                if capture_mode == nil then
                    log("Catch mode is nil, dont know why")
                elseif capture_mode == constants.CAPTURE_MODES.REGULAR then
                    log("Capture mode is " .. capture_mode)
                    local task
                    log("Creating task for worker type " .. worker_type)
                    if worker_type == constants.order_worker_type_express_construction_unit then
                        task = EcuTask:new()
                    else
                        task = Task:new()
                    end
                    task:initialize(payload)
                    task:changeState(constants.TASK_STATES.TASK_CREATED)
                elseif capture_mode == constants.CAPTURE_MODES.ADDITIVE then
                    log("Capture mode is " .. capture_mode)
                    payload.worker_type = worker_type
                    table.insert(global.captured_task_cache[player_index], payload)
                end
            else
                log("NO DUMMIES GOT BUILT")
            end

        end
    end
end)

function mergePayloadsInTask(player_index)
    local player_payload_cache = global.captured_task_cache[player_index]
    if not next(player_payload_cache) then
        log("Nothing to merge for player " .. player_index)
        return
    end
    local worker_type = player_payload_cache[1].worker_type
    local entities
    local cost_to_build
    local n
    local final_payload
    for _, payload in pairs(player_payload_cache) do
        final_payload = payload
        n = _
        if payload.worker_type ~= worker_type then
            log("ALARM WORKER TYPES IN ONE MERGE ARE DIFFERENT, SOMETHING WENT WRONG")
        end

        local payload_entities = payload.entities
        local payload_cost_to_build = payload.cost_to_build
        if entities == nil then
            log("First payload, assigning entities")
            entities = payload_entities
        else
            local index = #entities
            log("Merging task entities cache had " .. index .. " entities")
            for _, e in pairs(payload_entities) do
                index = index + 1
                entities[index] = e
            end
            log("Now has " .. index .. " entities")
        end
        if cost_to_build == nil then
            log("First payload, assigning cost to build")
            cost_to_build = payload_cost_to_build
        else
            log("Cost to build was:" .. serpent.block(cost_to_build))
            for item, count in pairs(payload_cost_to_build) do
                cost_to_build[item] = (cost_to_build[item] or 0) + count
            end
            log("Cost to build now:" .. serpent.block(cost_to_build))
        end
    end

    log("Merged " .. n .. " tasks, creating merged task...")
    final_payload.entities = entities
    final_payload.cost_to_build = cost_to_build
    if worker_type == constants.order_worker_type_express_construction_unit then
        task = EcuTask:new()
    else
        task = Task:new()
    end
    task:initialize(final_payload)
    task:changeState(constants.TASK_STATES.TASK_CREATED)
    global.captured_task_cache[player_index] = {}
end

-- move create tasks from cached build ghosts 
script.on_nth_tick(30, function(event)
    if not global.deconstruction_posted_trigger or not next(global.deconstruction_posted_trigger) then
        return
    end

    log('Reached deconstruction task assembler')
    
    for player_index, info in pairs(global.catch_deconstruction_order) do
        local cache = info.cache
        local ready = global.deconstruction_posted_trigger[player_index]
        if ready and cache then
            for tick, tick_cache in pairs(cache) do
                if tick == event.tick then
                    log("BAD TICK FOR CONSTRUCTION " .. event.tick .. tick)
                    return
                end
                -- invalidate trigger for this player
                global.deconstruction_posted_trigger[player_index] = nil
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
            global.catch_deconstruction_order[player_index] = nil
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

script.on_nth_tick(37, function(event)
    if next(global.construction_tasks.RESUPPLYING.data) == nil then
        return
    end

    local task = global.construction_tasks.RESUPPLYING:pop()
    task:RESUPPLYING()
end)

-- termination
script.on_nth_tick(38, function(event)
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
        task:forceChangeState(constants.TASK_STATES.TERMINATING)
        return
    end
end)

function handleConstructionOrder(event)
    local player_index = event.player_index
    local player = game.players[player_index]
    local held_blueprint = player.cursor_stack

    --safety check: check if cursor stack is valid
    if not held_blueprint then return end
    if not held_blueprint.valid_for_read then return end

    local blueprint_type = held_blueprint.type
    if not blueprint_type then return end

    local worker_type = global.worker_type[player_index]
    if not worker_type then
        log("handleConstructionOrder called but no worker type in global for player " .. player_index)
    end

    if blueprint_type == 'blueprint' then
        
        if not held_blueprint.is_blueprint then return end
        if not held_blueprint.is_blueprint_setup() then return end


        local blueprint_entities = held_blueprint.get_blueprint_entities()
        local dummy_entities = bl.bulkConvertEntitiesToDummies(blueprint_entities)

        global.cursor_blueprint_cache[player_index] = {}
        global.cursor_blueprint_cache[player_index].worker_type = worker_type
        global.cursor_blueprint_cache[player_index].dummy_entities = dummy_entities
        global.cursor_blueprint_cache[player_index].capture_mode = global.order_catch_mode[player_index]
        global.cursor_blueprint_cache[player_index].build_params = {
            surface=player.surface,
            force=player.force,
            force_build=true,
            skip_fog_of_war=true,
        }
        
        displayCatchBlueprintOrderMessage(player_index, constants.order_type_blueprint, worker_type)

    elseif blueprint_type == 'deconstruction-item' then
        global.deconstruction_posted_trigger[player_index] = true
        global.catch_deconstruction_order[player_index].worker_type = worker_type
        global.catch_deconstruction_order[player_index].capture_mode = global.order_catch_mode[player_index]
        displayCatchBlueprintOrderMessage(player_index, constants.order_type_deconstruction, worker_type)
    end
end

function setOrderCatchMode(player_index, worker_type_changed)
    local current_mode = global.order_catch_mode[player_index]

    if current_mode == nil then
        log("BUEX mode is set to " .. constants.CAPTURE_MODES.REGULAR)
        global.order_catch_mode[player_index] = constants.CAPTURE_MODES.REGULAR
        return
    end
    if worker_type_changed then
        return
    end

    if current_mode == constants.CAPTURE_MODES.ADDITIVE then
        log("BUEX mode is set to " .. constants.CAPTURE_MODES.REGULAR)
        global.order_catch_mode[player_index] = constants.CAPTURE_MODES.REGULAR
    elseif current_mode == constants.CAPTURE_MODES.REGULAR then
        log("BUEX mode is set to " .. constants.CAPTURE_MODES.ADDITIVE)
        global.order_catch_mode[player_index] = constants.CAPTURE_MODES.ADDITIVE
    else
        log("Unexpected behavior when setting BUEX mode, do nothing")
    end
end

script.on_event("buex-build-blueprint-left", function(event)
    local player_index = event.player_index
    local current_worker_type = global.worker_type[player_index]
    local worker_type_changed = current_worker_type ~= nil and current_worker_type ~= constants.order_worker_type_express_construction_unit
    if worker_type_changed then
        mergePayloadsInTask(player_index)
    end
    setOrderCatchMode(player_index, worker_type_changed)
    global.worker_type[player_index] = constants.order_worker_type_express_construction_unit
    handleConstructionOrder(event)
end)

script.on_event("buex-build-blueprint-right", function(event)
    local player_index = event.player_index
    local current_worker_type = global.worker_type[player_index]
    local worker_type_changed = current_worker_type ~= nil and current_worker_type ~= constants.order_worker_type_construcion_train
    if worker_type_changed then
        mergePayloadsInTask(player_index)
    end
    setOrderCatchMode(player_index, worker_type_changed)
    global.worker_type[player_index] = constants.order_worker_type_construcion_train
    handleConstructionOrder(event)
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
    local player_index = event.player_index
    mergePayloadsInTask(player_index)
    global.order_catch_mode[player_index] = nil
    global.worker_type[player_index] = nil  
    destroyCatchBlueprintOrderMessage(player_index)
    global.cursor_blueprint_cache[player_index] = {}
    global.catch_deconstruction_order[player_index] = {}
    global.blueprint_posted_trigger = {}
    global.deconstruction_posted_trigger = {}
end)

script.on_event(defines.events.on_pre_build , function(event)
    
    local player_index = event.player_index
    if global.cursor_blueprint_cache[player_index].dummy_entities ~= nil then
        global.cursor_blueprint_cache[player_index].build_params.direction = event.direction
        global.cursor_blueprint_cache[player_index].build_params.position=event.position
        global.cursor_blueprint_cache[player_index].tick = event.tick
        global.blueprint_posted_trigger[player_index] = true
    end
end)

script.on_event(defines.events.on_built_entity, function(event)

    local created_entity = event.created_entity
    local prototype_name = created_entity.prototype.name

    if prototype_name == constants.buex_locomotive then
        game.print("AAAAAAAA!")
    end

    if prototype_name == constants.buex_depot_name then
        registerWorkerStation(created_entity)
        return
    end
    
    local player_index = event.player_index
    local destroy_ghost = global.blueprint_posted_trigger[player_index]

    if destroy_ghost and created_entity.valid then created_entity.destroy() return end

end, {
    {filter = "ghost"},
    {filter = 'name', name = constants.buex_depot_name}
})

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

script.on_event(defines.events.on_robot_built_entity, function(event)
    local created_entity = event.created_entity
    local prototype_name = created_entity.prototype.name

    if prototype_name == constants.buex_locomotive then
        game.print("AAAAAAAA!")
    end

end, {{filter = 'name', name = constants.buex_locomotive}})

