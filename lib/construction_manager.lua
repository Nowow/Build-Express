require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.events")



-- assigning train to task
script.on_nth_tick(31, function(event)
    local task = construction_tasks[event.task_id]
    local worker = TrainRegister:get_free_train_and_mark_busy()
    if not worker then
        game.print('No workers available')
        return
    end
    task.worker = worker
    task.subtasks = solveBoundingBoxSubdivision(task.bounding_box, 50)
    task.subtasks = attributeGhostsToSubtask(task.ghosts, task.subtasks)
    task.state = TASK_STATES.ASSIGNED
    construction_tasks[task.id] = task
    game.print('TASK_READY_FOR_ASSIGNMENT TICK ' .. game.tick)
    script.raise_event(EVENTS.TASK_ASSIGNED, {task_id=task.id})
    -- for i, st in pairs(task.subtasks) do
    --     game.print(i)
    --     local color = {r = math.random(), g = math.random(), b = math.random()}
    --     hightligtBoundingBox(st.bounding_box, color)
    --     for _, e in pairs(st.ghosts) do
    --         hightlightEntity(e, 1, color)

    --     end
    -- end
end)

-- dispatch
script.on_event(EVENTS.TASK_ASSIGNED, function(event)
    game.print('TASK_ASSIGNED ' .. game.tick)
    local task = construction_tasks[event.task_id]
    local spot = findBuildingSpot(task, 1)
    hightlighRail(spot)
    makeTrainGoToRail(spot, task.worker)

end)