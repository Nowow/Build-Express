require("lib.utils")

blueprint_entity_cache = {}

TASK_STATES = {
    TASK_CREATED = 'TASK_CREATED',
    UNASSIGNED = 'UNASSIGNED',
    PREPARING = 'PREPARING',
    ASSIGNED = 'ASSIGNED',
    BUILDING = 'BUILDING',
    TERMINATING = 'TERMINATING'
}

function log_task(task_id, msg)
    log(string.format("TASK_ID %-12s", task_id .. ':') .. msg)
end


function createTask(tick, player_index, blueprint_label, ghosts, cost_to_build, tiles)
    local tiles = tiles or tiles == nil and {}
    return {
        id=player_index .. '_' .. tick,
        tick=tick,
        player_index=player_index,
        blueprint_label=blueprint_label,
        ghosts=ghosts,
        tile_ghosts=tiles,
        surface=game.players[player_index].surface,
        bounding_box=nil,
        subtasks=nil,
        worker=nil,
        active_subtask=nil,
        building_spot=nil,
        state=TASK_STATES.TASK_CREATED,
        flying_text={},
        cost_to_build=cost_to_build
    }
end

function createSubtask(bounding_box)
    return {
        bounding_box=bounding_box,
        ghosts={},
        tile_ghosts={}
    }
end


function HightlightCachedEntities(entities)
    for _, e in pairs(entities) do
        hightlightEntity(e, 2)
    end
end


function findBlueprintBoundigBox(entities, hightlight)
    local hightlight = hightlight or hightlight==nil and false
    local color = {r = 1, g = 0, b = 1}
    local left_top_x = math.huge
    local left_top_y = math.huge
    local right_bottom_x = -1*math.huge
    local right_bottom_y = -1*math.huge
    for _, e in pairs(entities) do

        local bb = e.ghost_prototype.selection_box
        if bb ~= nil then
            if left_top_x > bb.left_top.x + e.position.x then
                left_top_x = bb.left_top.x + e.position.x
            end
            if left_top_y > bb.left_top.y + e.position.y then
                left_top_y = bb.left_top.y + e.position.y
            end
            if right_bottom_x < bb.right_bottom.x + e.position.x then
                right_bottom_x = bb.right_bottom.x + e.position.x
            end
            if right_bottom_y < bb.right_bottom.y + e.position.y then
                right_bottom_y = bb.right_bottom.y + e.position.y
            end
        end
    end
    if hightlight then
        rendering.draw_rectangle({
            left_top={left_top_x, left_top_y},
            right_bottom={right_bottom_x, right_bottom_y},
            color=color,
            surface=game.players[1].surface,
            time_to_live=300
        })
    end
    return {
        left_top={x=left_top_x,y=left_top_y},
        right_bottom={x=right_bottom_x, y=right_bottom_y}
    }

end


function solveBoundingBoxSubdivision(bounding_box, max_side_length)
    local bb_width = bounding_box.right_bottom.x - bounding_box.left_top.x
    local bb_height = bounding_box.right_bottom.y - bounding_box.left_top.y
    local subtask_width = 0
    local subtask_height = 0
    if bb_width >= bb_height then
        subtask_width = max_side_length
        subtask_height = max_side_length*bb_height/bb_width
    else
        subtask_height = max_side_length
        subtask_width = max_side_length*bb_width/bb_height
    end
    local side_x_ceil = math.ceil(bb_width/subtask_width)
    local side_y_ceil = math.ceil(bb_height/subtask_height)
    local subtasks = {}
    local subtask_left_top_x
    local subtask_left_top_y
    local subtask_right_bottom_x
    local subtask_right_bottom_y

    for i=1, side_x_ceil do
        for j=1, side_y_ceil do
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(i-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(j-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*i
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*j
            table.insert(subtasks, createSubtask({
                left_top={x=subtask_left_top_x, y=subtask_left_top_y},
                right_bottom={x=subtask_right_bottom_x, y=subtask_right_bottom_y}
            }))
        end
    end
    return subtasks
end

function attributeGhostsToSubtask(ghosts, subtasks)
    for ghost_i, ghost in pairs(ghosts) do
        if not ghost.valid then
            ghosts[ghost_i] = nil
        else
            local ghost_bb = ghost.ghost_prototype.selection_box
            ghost_bb.left_top.x = ghost_bb.left_top.x + ghost.position.x
            ghost_bb.left_top.y = ghost_bb.left_top.y + ghost.position.y
            ghost_bb.right_bottom.x = ghost_bb.right_bottom.x + ghost.position.x
            ghost_bb.right_bottom.y = ghost_bb.right_bottom.y + ghost.position.y
            for subtask_i, subtask in pairs(subtasks) do
                if rectangleOverlapsRectangle(ghost_bb, subtask.bounding_box) then
                    table.insert(subtask.ghosts, ghost)
                    break
                end
            end
        end
    end
    return subtasks
end

function findBuildingSpot(task, offset)
    for i, subtask in pairs(task.subtasks) do

        if next(subtask.ghosts) ~= nil then

            candidates = findNearestRails(task.surface, subtask.bounding_box, offset)
            log_task(task.id, "Testign rails: found " .. #candidates .. ' rails for subtask ' .. i )
            if #candidates > 0 then
                log_task(task.id, "Testign rails: testing rails for subtask " .. i)
                for _, rail in pairs(candidates) do
                    if checkIfTrainCanGetToRail(task.worker, rail) then
                        --hightligtBoundingBox(subtask.bounding_box, {r = math.random(), g = math.random(), b = math.random()})
                        task.active_subtask_index = i
                        task.building_spot = rail
                        hightlighRail(rail, {r = 0, g = 1, b = 0})
                        return task
                    else
                        hightlighRail(rail, {r = 1, g = 0, b = 0})
                    end
                end
            end

        else
            task.subtasks[i] = nil
        end
    end
    return task
end

 
-- algorithm:

-- 1. Calculate bounding box for a blueprint
-- 2. tile it into proportional rectangles, their shape depedning on the expected train construction area
-- 3. select subarea, find closest possible rail (1 tile away, two tiles away, etc until train construction are cant cover them)
-- 4. if found, check if reachable
-- 5. if reachable, send train and build
-- 6. repeat for all subareas
-- 8. when done, check if any ghosts left, calculate closest spot individually (maybe can optimize by getting best shared spot)