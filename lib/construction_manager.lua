require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.gui")
require("lib.station_manager")
require("lib.task_queue")
require("settings")

local constants = require("constants")
local landfill = require("lib.ghosts_on_water_port.landfillPlacer")
local util = require('util')
local next = next

function initConstructionTasks()
    if not global.construction_tasks then
        global.construction_tasks = {}
    end
    for task_state, _ in pairs(TASK_STATES) do
        if global.construction_tasks[task_state] == nil then
            game.print("CREATING EMPTY QUEUE FOR " .. task_state .. " TASK STATE IN global.construction_tasks")
            global.construction_tasks[task_state] = TaskQueue:create(task_state)
        end
    end
end

function endTask(task)
    log_task(task.id, "ENDING TASK " .. task.id .. " IN STATE " .. task.state)

    -- destroying all ghosts that are left
    local valid_ghosts_counter = 0
    for _, ghost in pairs(task.ghosts) do
        if ghost.valid then
            ghost.destroy()
            valid_ghosts_counter = valid_ghosts_counter + 1
        end
    end
    log_task(task.id, "VALID GHOSTS LEFT: " .. valid_ghosts_counter)

    --destroying flying textx
    for _, render_id in pairs(task.flying_text) do
        rendering.destroy(render_id)
    end

    local worker = task.worker
    if worker ~= nil then
        --removing all temp stops except current, so worker waits for robots to come back
        removeTimePassedConditionFromCurrentStop(worker)
        local temps_removed = removeAllTempStops(worker, true)
        log_task(task.id, "REMOVED " .. temps_removed .. " TEMP STOPS")
    end

    --makeTrainGoToDepot(task.worker)
    update_task_frame(task, true)
    global.construction_tasks[task.state]:remove(task.id)
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
                    local task = createTask(building_tick, player_index, blueprint_label, built_ghost_dummies, cost_to_build)
                    game.print("PUSHED TASK IN CREATED")
                    global.construction_tasks.TASK_CREATED:push(task)
                    update_task_frame(task)
                else
                    game.print("NO DUMMIES GOT BUILT")  
                end
                
            end
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
    task.bounding_box = findBlueprintBoundigBox(task.ghosts)
    local task_id_flying_text = rendering.draw_text({
        text="TASK " .. task.id,
        surface = task.surface,
        target = {
            x=task.bounding_box.left_top.x + (task.bounding_box.right_bottom.x - task.bounding_box.left_top.x)/2,
            y=task.bounding_box.left_top.y + (task.bounding_box.right_bottom.y - task.bounding_box.left_top.y)/2,
        },
        color={r=0,g=1,b=0.7},
        scale=3.0,
    })
    table.insert(task.flying_text,task_id_flying_text)
    task.state = TASK_STATES.UNASSIGNED
    global.construction_tasks.UNASSIGNED:push(task)
    update_task_frame(task)

end)

-- assigning train to task
script.on_nth_tick(32, function(event)
    if next(global.construction_tasks.UNASSIGNED.data) == nil then
        return
    end
    
    log('Reached UNASSIGNED handler')

    local task = global.construction_tasks.UNASSIGNED:pop()
    local worker = getWorker(task.blueprint_label)
    log_task(task.id, "Looking for workers")
    if not worker then
        log_task(task.id, 'No workers available')
        global.construction_tasks.UNASSIGNED:push(task)
        return
    end
    log_task(task.id, "Worker found!")
    task.worker = worker
    -- calculating construction are reach , but accounting for the fact that locomotive is first and 2 more for good measure
    task.worker_construction_radius = getRoboportRange(worker) - 10
    task.subtasks = solveBoundingBoxSubdivision(task.bounding_box, task.worker_construction_radius)
    task.subtask_count = #task.subtasks
    log_task(task.id, "Subdivision finished, total subtasks: " .. task.subtask_count)
    task.subtasks = attributeGhostsToSubtask(task.ghosts, task.subtasks)
    log_task(task.id, "Ghost attribution finished, subtask statistics:")
    local checksum = 0
    for i, subtask in pairs(task.subtasks) do
        local ghost_count = table_size(subtask.ghosts)
        checksum = checksum + ghost_count
        log_task(task.id, "subtask id: " .. i .. ", ghosts count: " .. ghost_count)
    end
    log_task(task.id, "Total ghosts in task: " .. table_size(task.ghosts) .. ', checksum: ' .. checksum)
    task.state = TASK_STATES.PREPARING
    global.construction_tasks.PREPARING:push(task)
    update_task_frame(task)

end)

-- modifying changes before dispatching
-- place tile ghosts under water hovering entity ghosts
script.on_nth_tick(33, function(event)
    if next(global.construction_tasks.PREPARING.data) == nil then
        return
    end

    log('Reached PREPARING handler')

    local task = global.construction_tasks.PREPARING:pop()

    for i, subtask in pairs(task.subtasks) do
        for _, ghost in pairs(subtask.ghosts) do
            if ghost.valid then
                
                local dummy_replaced = replaceDummyEntityGhost(ghost)
                -- if ghost still valid then replacement didnt take place
                if not dummy_replaced then  
                    local landfill_ghosts = landfill.placeGhostLandfill(ghost)
                    --log_task(task.id, "placed " .. #landfill_ghosts .. " landfill")
                    hightlightEntity(ghost, 3, {r=1,g=1,b=0})
                    for _, t in pairs(landfill_ghosts) do
                        table.insert(subtask.tile_ghosts, t)
                    end
                end
            end
            
        end
    end
    task.state = TASK_STATES.ASSIGNED
    global.construction_tasks.ASSIGNED:push(task)
    update_task_frame(task)
end)


---- building loop ----
--   pick active subtask and send worker to build
script.on_nth_tick(34, function(event)
    if next(global.construction_tasks.ASSIGNED.data) == nil then
        return
    end

    --log('Reached ASSIGNED handler')
    
    local task = global.construction_tasks.ASSIGNED:pop()
    task = findBuildingSpot(task, 1)
    if task.building_spot == nil then
        local subtasks_left = table_size(task.subtasks)
        if subtasks_left > 0 then
            local ghosts_left = 0
            for _, subtask in pairs(task.subtasks) do
                for __, ghost in pairs(subtask.ghosts) do
                    if ghost.valid then
                        ghosts_left = ghosts_left + 1
                    end
                end
            end
            log_task(task.id, "found no spot, subtasks left: " .. subtasks_left .. ', ghosts left: ' .. ghosts_left)
            global.construction_tasks.ASSIGNED:push(task)
        else
            log_task(task.id, "ASSIGNED, but no more subtasks left, puttin task into TERMINATION due to completion")
            task.state = TASK_STATES.TERMINATING
            global.construction_tasks.TERMINATING:push(task)
        end
        return
    end

    local color = {r = 1, g = 1, b = 0}
    for _, e in pairs(task.subtasks[task.active_subtask_index].ghosts) do
        if e.valid then
            rendering.draw_circle({
                radius=2,
                target=e,
                color=color,
                surface=e.surface,
                time_to_live=1500
            })
        end
    end
    local worker = task.worker
    removeTimePassedConditionFromCurrentStop(worker)
    addStopToSchedule(task.building_spot, worker, true)
    task.state = TASK_STATES.BUILDING
    task.timer_tick = game.tick
    global.construction_tasks.BUILDING:push(task)
    update_task_frame(task)

end)

---- building loop ----
--   manage completion of an active subtask
script.on_nth_tick(35, function(event)
    if next(global.construction_tasks.BUILDING.data) == nil then
        return
    end

    --log('Reached BUILDING handler')

    local task = global.construction_tasks.BUILDING:pop()

    -- hard timeout if task cound not be completed
    -- if task.timer_tick ~= nil then
    --     if (game.tick - task.timer_tick) > TASK_TIMEOUT_TICKS then
    --         game.print("TIMEOUT FOR TASK " .. task.id) -- TODO timeout logic
    --         log_task(task.id, "TIMEOUT") -- TODO timeout logic
    --         endTask(task)
    --         return
    --     end
    -- end

    -- checking if active subtask has valid ghosts
    local subtask = task.subtasks[task.active_subtask_index]
    hightligtBoundingBox(subtask.bounding_box, {r = 0, g = 0, b = 1})
    local subtask_finished = true

    local start_subbtask_ghosts = table_size(subtask.ghosts)
    for j, ghost in pairs(subtask.ghosts) do
        if ghost.valid then
            hightlightEntity(ghost, 2)
            subtask_finished = false
            local is_water_ghost = util.string_starts_with(ghost.ghost_name, constants.dummyPrefix)
            if is_water_ghost then
                replaceDummyEntityGhost(ghost)
            end
        else
            --log('removed invalidated entity')
            subtask.ghosts[j] = nil
        end
    end
    local end_subtask_ghosts = table_size(subtask.ghosts)
    if start_subbtask_ghosts ~= end_subtask_ghosts then
        log_task(task.id, "Some ghosts got invalidated for subtask " .. task.active_subtask_index)
        log_task(task.id, "Was ghosts: " .. start_subbtask_ghosts .. " | Left ghosts " .. end_subtask_ghosts)
    end

    if subtask_finished then
        log_task(task.id, "Subtask " .. task.active_subtask_index .. " is finished")
        if end_subtask_ghosts > 0 then
            for i, e in pairs(subtask.ghosts) do
                if e.valid then
                    hightlightEntity(e, 2)
                    log_task(task.id, "VALID")
                    local gps = " at [gps=" .. e.position.x .. "," .. e.position.y .. ']'
                    game.print("VALID "..gps)
                else
                    log_task(task.id, "INVALID")
                end 
            end
        end
    end

    -- removing subtask and either restarting loop or task is finished
    if subtask_finished then
        table.remove(task.subtasks, task.active_subtask_index)
        task.active_subtask_index = nil
        task.building_spot = nil
        task.timer_tick = nil

        if next(task.subtasks) == nil then
            -- task is finished, sending back to depot
            log_task(task.id, "Puttin task into TERMINATION due to completion")
            task.state = TASK_STATES.TERMINATING
            global.construction_tasks.TERMINATING:push(task)
        else
            log_task(task.id, "Subtasks left: " .. table_size(task.subtasks))
            -- rerun loop, complete new subtask
            log_task(task.id, "Looping task back to ASSIGNED")
            task.state = TASK_STATES.ASSIGNED
            global.construction_tasks.ASSIGNED:push(task)
            update_task_frame(task)
        end
    else
        global.construction_tasks.BUILDING:push(task)
    end
end)

-- termination
script.on_nth_tick(36, function(event)
    if next(global.construction_tasks.TERMINATING.data) == nil then
        return
    end

    log('Reached TERMINATING handler')
    
    local task = global.construction_tasks.TERMINATING:pop()
    endTask(task)
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
        endTask(task)
        return
    end
end)
