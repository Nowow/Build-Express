local pathfinder = {}

function pathfinder.request_path(unit, goal)
    local unit_position = unit.position
    local surface = unit.surface
    local pathing_collision_mask = {"water-tile", "consider-tile-transitions", "colliding-with-tiles-only", "not-colliding-with-itself"}

    unit.autopilot_destination = nil
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
    game.print("FINISHED PATHING REQUEST " .. event.id)
    if event.try_again_later then
        game.print("PATHFINDER SAID IM TOO BUSY")
        return
    end
    if not event.path then
        game.print("NO PATH WAS FOUND")
        return
    end
    pathfinder.set_autopilot(global.entity_selected, event.path)


end

--on_script_path_request_finished 

script.on_event(defines.events.on_script_path_request_finished , pathfinder.handle_finished_pathing_request)

return pathfinder