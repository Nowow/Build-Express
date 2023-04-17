require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.events")
require("lib.gui")
require("lib.station_manager")
require("lib.task_queue")

local next = next

function initConstructionTasks()
    if not global.construction_tasks then
        global.construction_tasks = {}
    end
    for task_state, _ in pairs(TASK_STATES) do
        if global.construction_tasks[task_state] == nil then
            game.print("CREATING EMPTY QUEUE FOR " .. task_state .. " TASK STATE IN global.construction_tasks")
            global.construction_tasks[task_state] = TaskQueue:create()
        end
    end
end

function endTask(task)
    game.print("ENDING TASK " .. task.id .. " IN STATE " .. task.state)
    for _, ghost in pairs(task.ghosts) do
        ghost.destroy()
    end
    makeTrainGoToDepot(task.worker)
    update_task_frame(task, true)
    global.construction_tasks[task.state]:remove_task(task.id)
end

-- move create tasks from cached build ghosts 
script.on_nth_tick(30, function(event)
    if next(blueprint_entity_cache) == nil then
        return
    end

    log('Reached task assembler')
    
    for player_index, blueprint_cache in pairs(blueprint_entity_cache) do
        
        for blueprint_label, tick_cache in pairs(blueprint_cache) do

            for tick, cache in pairs(tick_cache) do
                if tick == event.tick then
                    return
                end
                local task = createTask(tick, player_index, blueprint_label, cache)
                global.construction_tasks.TASK_CREATED:push(task)
                update_task_frame(task)
                blueprint_entity_cache[player_index][blueprint_label][tick] = nil
            end
            blueprint_entity_cache[player_index][blueprint_label] = nil
        end
    blueprint_entity_cache[player_index] = nil
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
    if not worker then
        game.print('No workers available')
        global.construction_tasks.UNASSIGNED:push(task)
        return
    end
    task.worker = worker
    task.subtasks = solveBoundingBoxSubdivision(task.bounding_box, 50)
    task.subtasks = attributeGhostsToSubtask(task.ghosts, task.subtasks)
    task.subtask_count = #task.subtasks
    task.state = TASK_STATES.ASSIGNED
    global.construction_tasks.ASSIGNED:push(task)
    update_task_frame(task)

end) 

---- building loop ----
--   pick active subtask and send worker to build
script.on_nth_tick(33, function(event)
    if next(global.construction_tasks.ASSIGNED.data) == nil then
        return
    end

    log('Reached ASSIGNED handler')
    
    local task = global.construction_tasks.ASSIGNED:pop()
    local modified_task = findBuildingSpot(task, 1)
    if modified_task ~= nil then task = modified_task
    else
        game.print("found no spot")
        global.construction_tasks.ASSIGNED:push(task)
        return
    end
    hightlighRail(task.building_spot)
    makeTrainGoToRail(task.building_spot, task.worker)
    task.state = TASK_STATES.BUILDING
    task.timer_tick = game.tick
    global.construction_tasks.BUILDING:push(task)
    update_task_frame(task)

end)

---- building loop ----
--   manage completion of an active subtask
script.on_nth_tick(34, function(event)
    if next(global.construction_tasks.BUILDING.data) == nil then
        return
    end

    log('Reached BUILDING handler')

    local task = global.construction_tasks.BUILDING:pop()

    -- hard timeout if task cound not be completed
    if task.timer_tick ~= nil then
        if (game.tick - task.timer_tick) > 7200 then
            game.print("TIMEOUT FOR TASK " .. task.id) -- TODO timeout logic
            endTask(task)
            return
        end
    end

    -- checking if active subtask has valid ghosts
    local subtask = task.subtasks[task.active_subtask_index]
    hightligtBoundingBox(subtask.bounding_box, {r = math.random(), g = math.random(), b = math.random()})
    local subtask_finished = true
    for j, ghost in pairs(subtask.ghosts) do
        if ghost.valid then
            subtask_finished = false
            break
        else
            log('removed invalidated entity')
            table.remove(subtask.ghosts, j)
        end
    end

    log('subtask_finished is ' .. serpent.block(subtask_finished))

    -- removing subtask and either restarting loop or task is finished
    if subtask_finished then
        table.remove(task.subtasks, task.active_subtask_index)
        task.active_subtask_index = nil
        task.building_spot = nil
        task.timer_tick = nil

        if next(task.subtasks) == nil then
            -- task is finished, sending back to depot
            log("Ending task due to completion")
            endTask(task)
        else
            -- rerun loop, complete new subtask
            log("Looping task back to ASSIGNED")
            task.state = TASK_STATES.ASSIGNED
            global.construction_tasks.ASSIGNED:push(task)
            update_task_frame(task)
        end
    else
        global.construction_tasks.BUILDING:push(task)
    end
end)

script.on_event(defines.events.on_gui_click, function(event)

    local element = event.element

    if element.name == "buex_open_gui" then
        toggleTestWidget(event.player_index)
        return
    end

    if element.name == "buex_task_delete_button" then
        local element_tags = element.tags
        local task = global.construction_tasks[element_tags.task_state]:get_task(element_tags.task_id)
        game.print("END BUTTON CALLED, TAGS ".. task.id .. ', STATE ' .. task.state)
        endTask(task)
        return
    end
end)
