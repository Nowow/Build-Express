require("lib.utils")
require("lib.ghosts_on_water_port.common")


function log_task(task_id, msg)
    log(string.format("TASK_ID %-12s", task_id .. ':') .. msg)
end

function createSubtask(bounding_box)
    local subtask_center_coords = getBoundingBoxCenter(bounding_box)
    return {
        bounding_box=bounding_box,
        subtask_coords=subtask_center_coords,
        entities={},
        cost_to_build={}
    }
end

function calculateCostToBuild(entities)
    local cost_to_build = {}
    local item_to_place, item_name, count
    for _, entity in pairs(entities) do
        item_to_place = entity.ghost_prototype.items_to_place_this[1]
        item_name = item_to_place.name
        count = item_to_place.count
        cost_to_build[item_name] = (cost_to_build[item_name] or 0) + count
    end
    return cost_to_build
end

function convertDummyCostToActualCost(cost_to_build)
    local real_item_name
    local converted_cost = {}
    for item, cost in pairs(cost_to_build) do
        real_item_name = getOriginalEntityName(item)
        converted_cost[real_item_name] = (converted_cost[real_item_name] or 0) + cost
    end
    return converted_cost
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
    local subtask_width = max_side_length
    local subtask_height = max_side_length
    local x_denumenator = math.ceil(bb_width/subtask_width)
    local y_denumenator = math.ceil(bb_height/subtask_height)
    subtask_width = math.ceil(bb_width/x_denumenator)
    subtask_height = math.ceil(bb_height/y_denumenator)
    local side_x_ceil = math.ceil(bb_width/subtask_width)
    local side_y_ceil = math.ceil(bb_height/subtask_height)



    local traverse_outer_layer_counterclockwise = function (ii, jj, h, w)
        local subtask_sequence = {}
        local subtask_left_top_x
        local subtask_left_top_y
        local subtask_right_bottom_x
        local subtask_right_bottom_y

        -- traversing from left top to left bottom
        for t=1,h do
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(ii-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(jj-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*ii
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*jj
            table.insert(subtask_sequence, createSubtask({
                left_top={x=subtask_left_top_x, y=subtask_left_top_y},
                right_bottom={x=subtask_right_bottom_x, y=subtask_right_bottom_y}
            }))
            jj = jj + 1
        end
        jj = jj - 1

        -- traversing from left bottom to right bottom
        for t=1,w-1 do
            ii = ii + 1
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(ii-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(jj-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*ii
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*jj
            table.insert(subtask_sequence, createSubtask({
                left_top={x=subtask_left_top_x, y=subtask_left_top_y},
                right_bottom={x=subtask_right_bottom_x, y=subtask_right_bottom_y}
            }))
        end

        -- traversing from right bottom to right top
        for t=1,h-1 do
            jj = jj - 1
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(ii-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(jj-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*ii
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*jj
            table.insert(subtask_sequence, createSubtask({
                left_top={x=subtask_left_top_x, y=subtask_left_top_y},
                right_bottom={x=subtask_right_bottom_x, y=subtask_right_bottom_y}
            }))
        end

        -- traversing from right top up to starting point
        for t=1,w-2 do
            ii = ii - 1
            subtask_left_top_x = bounding_box.left_top.x + subtask_width*(ii-1)
            subtask_left_top_y = bounding_box.left_top.y + subtask_height*(jj-1)
            subtask_right_bottom_x = bounding_box.left_top.x + subtask_width*ii
            subtask_right_bottom_y = bounding_box.left_top.y + subtask_height*jj
            table.insert(subtask_sequence, createSubtask({
                left_top={x=subtask_left_top_x, y=subtask_left_top_y},
                right_bottom={x=subtask_right_bottom_x, y=subtask_right_bottom_y}
            }))
        end
        return subtask_sequence

    end

    local traverse_subtasks_counterclockwise
    traverse_subtasks_counterclockwise = function (start_i, start_j, h, w)

        local subtask_sequence = traverse_outer_layer_counterclockwise(start_i, start_j, h, w)

        local next_i, next_j, next_h, next_w = start_i + 1, start_j + 1, h - 2, w - 2
        if next_h < 1 or next_w < 1 then
            return subtask_sequence
        else
            local inner_subtask_sequence = traverse_subtasks_counterclockwise(next_i, next_j, next_h, next_w)
            for _, s in pairs(inner_subtask_sequence) do
                table.insert(subtask_sequence, s)
            end
            return subtask_sequence
        end
    end

    return traverse_subtasks_counterclockwise(1, 1, side_y_ceil, side_x_ceil)
    
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

function spreadBuildingCostIntoCyclicalChunks(cost_to_build)
    cost_to_build = cost_to_build or {}
    local item_prototype, stack_size, cycles, current_cycle, residue
    local max_cycles = 0
    local cache = {}
    local result = {}

    for item, cost in pairs(cost_to_build) do
        item_prototype = nil
        item_prototype = game.item_prototypes[item] or game.tile_prototypes[item]
        if not item_prototype then
            stack_size=cost
            cycles = 1
        else
            stack_size = item_prototype.stack_size
            cycles = math.floor(cost/stack_size)
        end
        cache[item] = {
            cycles=cycles,
            stack_size=stack_size,
            total_cost=cost
        }
        if cycles > max_cycles then
            max_cycles = cycles
        end
    end

    -- inserting residue at first
    for item, info in pairs(cache) do
        residue = info.total_cost - (info.cycles * info.stack_size)
        if residue > 0 then
            table.insert(result, {
                item=item,
                count=residue
            })
        end
    end

    current_cycle = 0
    while current_cycle < max_cycles do
        for item, info in pairs(cache) do
            if current_cycle < info.cycles then
                table.insert(result,{
                    item=item,
                    count=info.stack_size
                })
            end
        end
        current_cycle = current_cycle + 1
    end

    return result
end