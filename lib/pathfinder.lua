local pathfinder = {}
local constants = require("constants")

function pathfinder.init()
    if global.pathfinding_requests == nil then
        global.pathfinding_requests = {}
    end
end

function pathfinder.find_route_point_candidates(surface, bounding_box)
     local tiles = surface.find_tiles_filtered{
        area = bounding_box,
        collision_mask="water-tile",
        invert=true
    }
    return tiles
end

function pathfinder.find_non_colliding_spot(surface, area)
    return surface.find_non_colliding_position_in_box(constants.pathfinding_proxy_name, area, 1)
    
end

function pathfinder.request_path(params)
    local unit = params.unit
    local start = params.start or unit.position
    local goal = params.goal
    
    local surface = unit.surface
    local pathing_collision_mask = params.pathing_collision_mask or {"water-tile", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"}
    --local bounding_box = params.bounding_box or {{0.0, 0.0}, {0.0, 0.0}}
    local bounding_box = params.bounding_box or  {{-0.015, -0.015}, {0.015, 0.015}}
    -- if landfill_job then
    --     bounding_box = {{-0.015, -0.015}, {0.015, 0.015}}
    --     path_resolution_modifier = 0
    -- end
    local path_resolution_modifier = 0
    local id = surface.request_path({
        bounding_box=bounding_box,
        collision_mask=pathing_collision_mask,
        force=unit.force,
        start=start,
        goal=goal,
        pathfinder_flags={no_break=true},
        path_resolution_modifier=path_resolution_modifier,
    })
    global.pathfinding_requests[id] = params
end

function pathfinder.set_autopilot(unit, path) -- set path
    if unit and unit.valid then
        unit.autopilot_destination = nil
        for i, waypoint in ipairs(path) do
            unit.add_autopilot_destination(waypoint.position)
        end
    end
end

function pathfinder.handle_finished_pathing_request(event)
    local id = event.id
    local request_info = global.pathfinding_requests[id]
    local unit = request_info.unit
    local next_attempt = request_info.attempt + 1
    local goal = request_info.goal
    local callback = request_info.callback_source
    local autoretry = request_info  .autoretry

    if event.try_again_later then
        game.print("Pathfinder was too busy!")
        if autoretry then
            if not (next_attempt > constants.max_pathfinding_attempts) then
                game.print("Trying one more time, attempt " .. next_attempt)
                request_info.attempt = next_attempt
                pathfinder.request_path(request_info)
            else
                game.print("Giving up trying")
                callback:callback(nil, request_info)
            end
            return
        else
            game.print("No autoretry")
            if callback then
                callback:callback(nil, request_info)
            end
            return
        end
    end

    local path = event.path
    if not event.path then
        game.print("NO PATH WAS FOUND")
        if callback then callback:callback(nil, request_info) end
        return
    end

    if callback then
        callback:callback(path, request_info)
    else
        pathfinder.set_autopilot(unit, path)
    end
end


--on_script_path_request_finished 

script.on_event(defines.events.on_script_path_request_finished , pathfinder.handle_finished_pathing_request)

return pathfinder