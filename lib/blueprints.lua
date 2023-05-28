require("lib.utils")
require("lib.ghosts_on_water_port.common")


function log_task(task_id, msg)
    log(string.format("TASK_ID %-12s", task_id .. ':') .. msg)
end

function createSubtask(bounding_box)
    return {
        bounding_box=bounding_box,
        entities={},
        tiles={}
    }
end

function calculateActualCostToBuild(entities)
    local cost_to_build = {}
    local item
    local item_to_place
    local e_name
    local count
    for _, e in pairs(entities) do
        item_to_place = e.ghost_prototype.items_to_place_this[1]
        e_name = item_to_place.name
        count = item_to_place.count
        item = getOriginalEntityName(e_name)
        if cost_to_build[item] == nil then
            cost_to_build[item] = count
        else
            cost_to_build[item] = cost_to_build[item] + count
        end
    end
    return cost_to_build
end

function findBlueprintBoundigBox(entities)
    local left_top_x = math.huge
    local left_top_y = math.huge
    local right_bottom_x = -1*math.huge
    local right_bottom_y = -1*math.huge
    for _, e in pairs(entities) do
        local entity_type = e.type
        local bb
        if entity_type == 'entity-ghost' then
            bb = e.ghost_prototype.selection_box
        else
            bb = e.prototype.selection_box
        end
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
            local entity_type = ghost.type
            local entity_position = ghost.position
            local x = entity_position.x
            local y = entity_position.y
            -- local ghost_bb
            -- if entity_type == 'entity-ghost' then
            --     ghost_bb = ghost.ghost_prototype.selection_box
            -- else
            --     ghost_bb = ghost.prototype.selection_box
            -- end
            -- ghost_bb.left_top.x = ghost_bb.left_top.x + ghost.position.x
            -- ghost_bb.left_top.y = ghost_bb.left_top.y + ghost.position.y
            -- ghost_bb.right_bottom.x = ghost_bb.right_bottom.x + ghost.position.x
            -- ghost_bb.right_bottom.y = ghost_bb.right_bottom.y + ghost.position.y
            for subtask_i, subtask in pairs(subtasks) do
                local subtask_bb = subtask.bounding_box
                local left_top = subtask_bb.left_top
                local right_bottom = subtask_bb.right_bottom
                
                if x >= left_top.x and x <= right_bottom.x and y >= left_top.y and y <= right_bottom.y then
                -- if rectangleOverlapsRectangle(ghost_bb, subtask.bounding_box) then
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
            log_task(task.id, "Testing rails: found " .. #candidates .. ' rails for subtask ' .. i )
            if #candidates > 0 then
                log_task(task.id, "Testing rails: testing rails for subtask " .. i)
                for _, rail in pairs(candidates) do
                    if rail.valid and not rail.to_be_deconstructed() and checkIfTrainCanGetToRail(task.worker, rail) then
                        --hightligtBoundingBox(subtask.bounding_box, {r = math.random(), g = math.random(), b = math.random()})
                        task.active_subtask_index = i
                        task.building_spot = rail
                        hightlighRail(rail, {r = 0, g = 1, b = 0})
                        log_task(task.id, "Found rail for subtask " .. i)
                        return task
                    else
                        hightlighRail(rail, {r = 1, g = 0, b = 0})
                    end
                end
            end
            log_task(task.id, "Found no suitable rail for subtask " .. i)
        else
            task.subtasks[i] = nil
        end
    end
    return task
end
