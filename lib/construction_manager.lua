require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.events")

local next = next

-- move create tasks from cached build ghosts 
script.on_nth_tick(30, function(event)
    if next(blueprint_entity_cache) == nil then
        return
    end

    log('Reached task assembler')
    
    for player_index, tick_cache in pairs(blueprint_entity_cache) do
        for tick, cache in pairs(tick_cache) do
            if tick == event.tick then
                return
            end
            local task = createTask(tick, player_index, cache)
            global.construction_tasks.NEW[task.id] = task
            --script.raise_event(EVENTS.GHOST_CACHE_MOVED_TO_TASK, {task_id=task.id})
            blueprint_entity_cache[player_index][tick] = nil
        end
    blueprint_entity_cache[player_index] = nil
    end
end)

-- formulating construnstruction plan
script.on_nth_tick(31, function(event)
    if next(global.construction_tasks.NEW) == nil then
        return
    end

    log('Reached NEW handler')
    
    local _, task = next(global.construction_tasks.NEW)
    task.bounding_box = findBlueprintBoundigBox(task.ghosts)
    task.state = TASK_STATES.READY_TO_BE_ASSIGNED
    global.construction_tasks.NEW[task.id] = nil
    global.construction_tasks.UNASSIGNED[task.id] = task
    --script.raise_event(EVENTS.TASK_READY_FOR_ASSIGNMENT, {task_id=task.id})

end)

-- assigning train to task
script.on_nth_tick(32, function(event)
    if next(global.construction_tasks.UNASSIGNED) == nil then
        return
    end
    
    log('Reached UNASSIGNED handler')

    local _, task = next(global.construction_tasks.UNASSIGNED)
    local worker = getFreeTrain()
    if not worker then
        game.print('No workers available')
        return
    end
    task.worker = worker
    task.subtasks = solveBoundingBoxSubdivision(task.bounding_box, 50)
    task.subtasks = attributeGhostsToSubtask(task.ghosts, task.subtasks)
    task.state = TASK_STATES.ASSIGNED
    global.construction_tasks.UNASSIGNED[task.id] = nil
    global.construction_tasks.ASSIGNED[task.id] = task
end) 

---- building loop ----
--   pick active subtask and send worker to build
script.on_nth_tick(33, function(event)
    if next(global.construction_tasks.ASSIGNED) == nil then
        return
    end

    log('Reached ASSIGNED handler')
    
    local _, task = next(global.construction_tasks.ASSIGNED)
    local modified_task = findBuildingSpot(task, 1)
    if modified_task ~= nil then task = modified_task
    else
        game.print("found no spot")
    end
    hightlighRail(task.building_spot)
    makeTrainGoToRail(task.building_spot, task.worker)
    task.state = TASK_STATES.BUILDING
    task.timer_tick = game.tick
    global.construction_tasks.ASSIGNED[task.id] = nil
    global.construction_tasks.BUILDING[task.id] = task

end)

---- building loop ----
--   manage completion of an active subtask
script.on_nth_tick(34, function(event)
    if next(global.construction_tasks.BUILDING) == nil then
        return
    end

    log('Reached BUILDING handler')
    

    local _, task = next(global.construction_tasks.BUILDING)

    -- hard timeout if task cound not be completed
    if task.timer_tick ~= nil then
        if (game.tick - task.timer_tick) > 7200 then
            game.print("TIMEOUT FOR TASK " .. task.id)
        end
    end

    -- checking if active subtask has valid ghosts
    local subtask = task.subtasks[task.active_subtask_index]
    hightligtBoundingBox(subtask.bounding_box, {r = math.random(), g = math.random(), b = math.random()})
    local subtask_finished = true
    for j, ghost in pairs(subtask.ghosts) do
        if ghost.valid then
            --log('found valid ghost')
            --hightlightEntity(ghost, 1, {r = math.random(), g = math.random(), b = math.random()})
            subtask_finished = false
            break
        else
            log('removed invalidated entity')
            hightlightEntity(ghost, 1, {r = math.random(), g = math.random(), b = math.random()})
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
        global.construction_tasks.BUILDING[task.id] = nil

        if next(task.subtasks) == nil then
            -- task is finished, sending back to depot
            -- temp func
            makeTrainGoToDepot(task.worker)
        else
            -- rerun loop, complete new subtask
            task.state = TASK_STATES.ASSIGNED
            global.construction_tasks.ASSIGNED[task.id] = task
        end
    end
end)

