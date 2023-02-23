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
    
    local _, task = next(global.construction_tasks.NEW)
    task.bounding_box = findBlueprintBoundigBox(task.ghosts)
    task.state = TASK_STATES.READY_TO_BE_ASSIGNED
    global.construction_tasks.UNASSIGNED[event.task_id] = task
    --script.raise_event(EVENTS.TASK_READY_FOR_ASSIGNMENT, {task_id=task.id})

end)

-- assigning train to task
script.on_nth_tick(32, function(event)
    if next(global.construction_tasks.UNASSIGNED) == nil then
        return
    end
    
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
    global.construction_tasks.ASSIGNED[task.id] = task
    script.raise_event(EVENTS.TASK_ASSIGNED, {task_id=task.id})
    -- for i, st in pairs(task.subtasks) do
    --     game.print(i)
    --     local color = {r = math.random(), g = math.random(), b = math.random()}
    --     hightligtBoundingBox(st.bounding_box, color)
    --     for _, e in pairs(st.ghosts) do
    --         hightlightEntity(e, 1, color)

    --     end
    -- endцк 


-- dispatch
script.on_nth_tick(33, function(event)
    game.print('TASK_ASSIGNED ' .. game.tick)
    local task = construction_tasks[event.task_id]
    local spot = findBuildingSpot(task, 1)
    hightlighRail(spot)
    makeTrainGoToRail(spot, task.worker)

end)
