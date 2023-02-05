require("lib.utils")

first_tick = nil
last_tick = nil

blueprint_entity_cache = {}
blueprint_bounding_box = {}



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
    table.insert(subtasks, {{subtask_left_top_x, subtask_left_top_y}, {subtask_right_bottom_x, subtask_right_bottom_y}})

    for i=1, side_x_ceil do
        for j=1, sidside_y_ceile_b_ceil do
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(i-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(j-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*i
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*j
            table.insert(subtasks, {{subtask_left_top_x, subtask_left_top_y}, {subtask_right_bottom_x, subtask_right_bottom_y}})
        end
    end
    return subtasks

end


-- algorithm:

-- 1. Calculate bounding box for a blueprint
-- 2. tile it into proportional rectangles, their shape depedning on the expected train construction area
-- 3. select subarea, find closest possible rail (1 tile away, two tiles away, etc until train construction are cant cover them)
-- 4. if found, check if reachable
-- 5. if reachable, send train and build
-- 6. repeat for all subareas
-- 8. when done, check if any ghosts left, calculate closest spot individually (maybe can optimize by getting best shared spot)