local pathfinder = {}
local constants = require("constants")

function pathfinder.init()
    if global.pathfinding_requests == nil then
        global.pathfinding_requests = {}
    end
end

function pathfinder.request_path(unit, goal, attempt)
    local attempt = attempt or 0
    local unit_position = unit.position
    local surface = unit.surface
    local pathing_collision_mask = {"water-tile", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"}
    local bounding_box = {{-5, -5}, {5, 5}}
    -- if landfill_job then
    --     bounding_box = {{-0.015, -0.015}, {0.015, 0.015}}
    --     path_resolution_modifier = 0
    -- end
    local path_resolution_modifier = -2
    local id = surface.request_path({
        bounding_box=bounding_box,
        collision_mask=pathing_collision_mask,
        force=unit.force,
        start=unit_position,
        goal=goal,
        pathfinder_flags={no_break=true},
        path_resolution_modifier=path_resolution_modifier,
    })
    global.pathfinding_requests[id] = {unit=unit, goal=goal, attempt=attempt}
    game.print("GENERATED PATHING REQUEST " .. id)
end

function pathfinder.set_autopilot(unit, path) -- set path
    if unit and unit.valid then
        for i, waypoint in ipairs(path) do
            unit.add_autopilot_destination(waypoint.position)
        end
    end
end

function pathfinder.handle_finished_pathing_request(event)
    local id = event.id
    game.print("FINISHED PATHING REQUEST " .. id)
    local request_info = global.pathfinding_requests[id]
    local unit = request_info.unit
    local attempt = request_info.attempt + 1
    local goal = request_info.goal

    if event.try_again_later then
        game.print("Pathfinder was too busy!")
        if not attempt > constants.max_pathfinding_attempts then
            game.print("Trying one more time, attempt " .. attempt)
            pathfinder.request_path(unit, goal, attempt)
            return
        else
            game.print("Giving up trying!")
            return
        end
    end
    if not event.path then
        game.print("NO PATH WAS FOUND")
        return
    end
    unit.autopilot_destination = nil
    pathfinder.set_autopilot(unit, event.path)

end

--on_script_path_request_finished 

script.on_event(defines.events.on_script_path_request_finished , pathfinder.handle_finished_pathing_request)

return pathfinder