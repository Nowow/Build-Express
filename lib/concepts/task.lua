require("lib.utils")
require("lib.trains")
require("lib.blueprints")
require("lib.gui")

local constants = require("constants")
local util = require('util')
local landfill = require("lib.ghosts_on_water_port.landfillPlacer")

---@class Task
---@field id string
---@field type string
---@field tick integer
---@field player_index integer
---@field surface unknown
---@field blueprint_label string
---@field entities table
---@field tiles table
---@field cost_to_build table
---@field bounding_box table
---@field subtasks table
---@field active_subtask integer
---@field building_spot unknown
---@field worker unknown
---@field worker_construction_radius integer
---@field flying_text table
---@field attempted_to_reaquire_worker boolean
Task = {}
Task.__index = Task

script.register_metatable("task_metatable", Task)

---@return Task
function Task:new()
    local task = {}
    setmetatable(task, Task)
    return task
end

function Task:initialize(params)
    local task = self
    task.id=params.player_index .. '_' .. params.tick
    task.type = params.type
    task.tick = params.tick
    task.player_index = params.player_index
    task.surface=game.players[params.player_index].surface
    task.blueprint_label = params.blueprint_label
    task.entities = params.entities
    task.cost_to_build = params.cost_to_build or {}
    task.tiles = params.tiles or {}

    -- supposed to be empty
    task.bounding_box=params.bounding_box
    task.subtasks=params.subtasks
    task.active_subtask=params.active_subtask
    task.building_spot=params.building_spot

    task.worker=params.worker
    task.worker_construction_radius=params.worker_construction_radius

    task.state=constants.TASK_STATES.TASK_CREATED
    task.flying_text=params.flying_text or {}
    task.attempted_to_reaquire_worker = false
end

function Task:log(message)
    log(string.format("TASK_ID %-20s", self.id .. ' ' .. self.state .. ':') .. message)
end

function Task:changeState(new_state)
    local current_state = self.state
    if current_state ~= new_state then
        self.state = constants.TASK_STATES[new_state]
        self:log("Moved to state " .. new_state)
    end
    global.construction_tasks[new_state]:push(self)
    update_task_frame(self)
end

function Task:forceChangeState(new_state)
    local id = self.id
    local state = self.state
    local old_queue = global.construction_tasks[state]
    local task_popped = old_queue:remove(id)
    if not task_popped then
        self:log("something went wrong when force changing state, task was not in task queue of its current state " .. state)
        return false
    end
    local new_queue = global.construction_tasks[new_state]
    if not new_queue then
        self:log("something went wrong when force changing state, task queue for new state "  .. new_state .. " does not exist")
        old_queue:push(self)
        return false
    end
    self:changeState(new_state)
end

function Task:checkTrainFitsTask(train)
    local carriages = train.carriages
    if #carriages < 2 then
        self:log("Train has only 1 carriage, not enough")
        return false
    end
    return carriages[2].name == constants.ct_construction_wagon_name
end

function Task:checkTrainHasEnoughResources(train)
    local train_contents = train.get_contents()
    local cost_to_build = self.cost_to_build
    local enough_resources = true
    local train_has_amount
    local cost_modifier = settings.global["ecu-building-cost-modifier"].value
    self:log("Cost modifier is: " .. cost_modifier)
    for item, cost in pairs(cost_to_build) do
        cost = math.floor(cost*cost_modifier)
        train_has_amount = train_contents[item] or 0
        if train_has_amount < cost then
            enough_resources = false
            self:log("But it didnt have enough resources, item: " .. item .. ", cost: " .. cost .. ", available: " .. train_has_amount)
            break
        end
    end
    return enough_resources
end

function Task:findBoundingBox()
    local bounding_box = findBlueprintBoundigBox(self.entities)
    self.bounding_box = bounding_box
    local color = constants.task_flying_text_colors_by_task_type[self.type] or {r=1,g=1,b=1}
    local task_id_flying_text = rendering.draw_text({
        text="TASK " .. self.id,
        surface = self.surface,
        target = {
            x=bounding_box.left_top.x + (bounding_box.right_bottom.x - bounding_box.left_top.x)/2,
            y=bounding_box.left_top.y + (bounding_box.right_bottom.y - bounding_box.left_top.y)/2,
        },
        color=color,
        scale=3.0,
    })
    table.insert(self.flying_text,task_id_flying_text)
end

function Task:generateSubtasks()
    local subtasks = solveBoundingBoxSubdivision(self.bounding_box, self.worker_construction_radius)
    self.subtasks = subtasks
    self.subtask_count = #subtasks
    self:log("Subdivision finished, total subtasks: " .. self.subtask_count)
end

function Task:populateSubtasks()
    local entities = self.entities
    local subtasks = self.subtasks
    for i, entity in pairs(entities) do
        if not entity.valid then
            entities[i] = nil
        else
            local entity_type = entity.type
            local entity_bb
            if entity_type == 'entity-ghost' then
                entity_bb = entity.ghost_prototype.selection_box
            else
                entity_bb = entity.prototype.selection_box
            end
            entity_bb.left_top.x = entity_bb.left_top.x + entity.position.x
            entity_bb.left_top.y = entity_bb.left_top.y + entity.position.y
            entity_bb.right_bottom.x = entity_bb.right_bottom.x + entity.position.x
            entity_bb.right_bottom.y = entity_bb.right_bottom.y + entity.position.y
            for _, subtask in pairs(subtasks) do
                if rectangleOverlapsRectangle(entity_bb, subtask.bounding_box) then
                    table.insert(subtask.entities, entity)
                    local placed_landfill_ghosts = self.tiles[entity.unit_number]
                    if placed_landfill_ghosts and #placed_landfill_ghosts > 0 then
                        for j=1, #placed_landfill_ghosts do
                            table.insert(subtask.entities, placed_landfill_ghosts[j])
                        end
                    end
                    break
                end
            end
        end
    end
    self:log("Entity attribution finished, subtask statistics:")
    local checksum = 0
    for i, subtask in pairs(subtasks) do
        local entities_count = table_size(subtask.entities)
        checksum = checksum + entities_count
        self:log("subtask id: " .. i .. ", entities count: " .. entities_count)
    end
    self:log("Total entities in task: " .. table_size(entities) .. ', checksum: ' .. checksum)
end

function Task:assignWorker()
    local worker
    for station in iterateStations() do
        local control = station.get_control_behavior()
        if not control or (control and control.valid and not control.disabled) then
            self:log("Station ok!")
            local train = station.get_stopped_train()
            if train ~= nil then
                local is_construction_train = self:checkTrainFitsTask(train)
                if is_construction_train then
                    self:log("Train found!")
                    local enough_resources = self:checkTrainHasEnoughResources(train)
                    if enough_resources then
                        self:log("Worker found!")
                        worker = train
                        registerTrainAsInAction(worker, self)
                        break
                    end
                end
            end
        end
    end

    if not worker then
        self:log('No workers available')
        return false
    end

    self.worker = worker
    -- calculating construction area reach , but accounting for the fact that locomotive (8 tiles) is first and 2 more for good measure
    local worker_construction_radius = math.max(getRoboportRange(worker) - constants.subtask_construction_area_coverage_construction_train_offset, 15)
    self:log("worker_construction_radius: " .. worker_construction_radius)
    self.worker_construction_radius = worker_construction_radius
    return true
end

function Task:tileWaterGhosts()
    local tile_cost = {}
    local tile_cache = self.tiles

    for __, ghost in pairs(self.entities) do
        if ghost.valid then
            local dummy_replaced = replaceDummyEntityGhost(ghost)
            -- if ghost still valid then replacement didnt take place
            if not dummy_replaced then
                local landfill_ghosts = landfill.placeGhostLandfill(ghost)
                tile_cache[ghost.unit_number] = landfill_ghosts
                hightlightEntity(ghost, 3, {r=1,g=1,b=0})
                for _, t in pairs(landfill_ghosts) do
                    local tile_name = t.ghost_name
                    if tile_cost[tile_name] == nil then
                        tile_cost[tile_name] = 1
                    else
                        tile_cost[tile_name] = tile_cost[tile_name] + 1
                    end
                end
            end
        end
    end
    self:log("New tiles placed: " .. serpent.block(tile_cost))
    local cost_to_build = self.cost_to_build
    for tile_name, cost in pairs(tile_cost) do
        if cost_to_build[tile_name] == nil then
            cost_to_build[tile_name] = cost
        else
            cost_to_build[tile_name] = cost_to_build[tile_name] + cost
        end
    end

end

function Task:findBuildingSpot()
    local offset = 1
    local subtasks = self.subtasks

    for i, subtask in pairs(subtasks) do

        if next(subtask.entities) ~= nil then
            candidates = findNearestRails(self.surface, subtask.bounding_box, offset)
            self:log("Testing rails: found " .. #candidates .. ' rails for subtask ' .. i )
            if #candidates > 0 then
                self:log("Testing rails: testing rails for subtask " .. i)
                for _, rail in pairs(candidates) do
                    if rail.valid and not rail.to_be_deconstructed() and checkIfTrainCanGetToRail(self.worker, rail) then
                        
                        self.active_subtask_index = i
                        self.building_spot = rail
                        hightlighRail(rail, {r = 0, g = 1, b = 0})
                        self:log("Found rail for subtask " .. i)
                        return true
                    else
                        hightlighRail(rail, {r = 1, g = 0, b = 0})
                    end
                end
            end
            self:log("Found no suitable rail for subtask " .. i)
        else
            self.subtasks[i] = nil
        end
    end

    if self.building_spot == nil then
        local subtasks_left = table_size(subtasks)
        if subtasks_left > 0 then
            local entities_left = 0
            for _, subtask in pairs(subtasks) do
                for _, entity in pairs(subtask.entities) do
                    if entity.valid then
                        entities_left = entities_left + 1
                    end
                end
            end
            self:log("found no spot, subtasks left: " .. subtasks_left .. ', entities left: ' .. entities_left)
            -- TODO: BLOCKED STATE
            self:changeState(constants.TASK_STATES.ASSIGNED)
        else
            self:log("ASSIGNED, but no more subtasks left, puttin task into TERMINATION due to completion")
            self:changeState(constants.TASK_STATES.TERMINATING)
        end
        return false
    end
    local color = {r = 1, g = 1, b = 0}
    for _, e in pairs(subtasks[self.active_subtask_index].entities) do
        if e.valid then
            rendering.draw_circle({
                radius=2,
                target=e,
                color=color,
                surface=e.surface,
                time_to_live=1500
            })
        end
    end
    return true
end

function Task:dispatchWorkerToNextStop()
    local worker = self.worker
    removeTimePassedConditionFromCurrentStop(worker)
    addStopToSchedule(self.building_spot, worker, true)

    self.timer_tick = game.tick
end

function Task:invalidateTaskEntities()
    -- checking if active subtask has valid ghosts
    local active_subtask_index = self.active_subtask_index
    local subtask = self.subtasks[self.active_subtask_index]
    local subtask_entities = subtask.entities
    hightligtBoundingBox(subtask.bounding_box, {r = 0, g = 0, b = 1})
    local subtask_finished = true
    local task_type = self.type

    if task_type == constants.TASK_TYPES.BUILD then
        
        local start_subbtask_ghosts = table_size(subtask_entities)
        for j, ghost in pairs(subtask_entities) do
            if ghost.valid then
                hightlightEntity(ghost, 2)
                subtask_finished = false
                local is_water_ghost = util.string_starts_with(ghost.ghost_name, constants.dummyPrefix)
                if is_water_ghost then
                    replaceDummyEntityGhost(ghost)
                end
            else
                subtask_entities[j] = nil
            end
        end
        local end_subtask_ghosts = table_size(subtask_entities)
        if start_subbtask_ghosts ~= end_subtask_ghosts then
            self:log("Some ghosts got invalidated for subtask " .. active_subtask_index)
            self:log("Was ghosts: " .. start_subbtask_ghosts .. " | Left ghosts " .. end_subtask_ghosts)
        end

    elseif task_type == constants.TASK_TYPES.DECONSTRUCT then
        local start_subbtask_entities = table_size(subtask_entities)
        for j, entity in pairs(subtask_entities) do
            if entity.valid then
                hightlightEntity(entity, 2)
                subtask_finished = false
            else
                subtask_entities[j] = nil
            end
        end
        local end_subtask_entities = table_size(subtask_entities)
        if start_subbtask_entities ~= end_subtask_entities then
            self:log("Some entities got invalidated for subtask " .. active_subtask_index)
            self:log("Was entities: " .. start_subbtask_entities .. " | Left entities " .. end_subtask_entities)
        end
    end
    return subtask_finished
end

function Task:endTask()
    self:log("ENDING TASK IN STATE " .. self.state)

    -- destroying all entities that are left
    local valid_entities_counter = 0
    for _, entity in pairs(self.entities) do
        if entity.valid then
            entity.destroy()
            valid_entities_counter = valid_entities_counter + 1
        end
    end
    self:log("VALID GHOSTS LEFT: " .. valid_entities_counter)

    --destroying flying textx
    for _, render_id in pairs(self.flying_text) do
        rendering.destroy(render_id)
    end

    local worker = self.worker
    if worker ~= nil then
        --removing all temp stops except current, so worker waits for robots to come back
        removeTimePassedConditionFromCurrentStop(worker)
        local temps_removed = removeAllTempStops(worker, true)
        unregisterTrainAsInAction(worker.id)
        self:log("REMOVED " .. temps_removed .. " TEMP STOPS")
    end

    --makeTrainGoToDepot(task.worker)
    update_task_frame(self, true)
    global.construction_tasks[self.state]:remove(self.id)
end

function Task:callbackWhenTrainCreated(old_train_id, new_train)
    local fits = self:checkTrainFitsTask(new_train)
    if fits then
        self.attempted_to_reaquire_worker = false
        self.worker = new_train
        registerTrainAsInAction(new_train, self)
        unregisterTrainAsInAction(old_train_id)
        self:log("Reaquired worker after someone messed with train")
    elseif self.attempted_to_reaquire_worker then
        self:log("Unable to reaquire worker after someone messed with train, terminating")
        unregisterTrainAsInAction(old_train_id)
        self:forceChangeState(constants.TASK_STATES.TERMINATING)
    else
        self:log("Unable to reaquire worker after someone messed with train, one more attempt left")
        self.attempted_to_reaquire_worker = true
    end
    
end


------------------------------------------------------------------
-----TASK FLOW
------------------------------------------------------------------

function Task:TASK_CREATED()
    self:findBoundingBox()
    if self.type == constants.TASK_TYPES.BUILD then
        self:tileWaterGhosts()
    end
    self:changeState(constants.TASK_STATES.UNASSIGNED)
end

function Task:UNASSIGNED()
    local worker_found = self:assignWorker()

    if not worker_found then
        --loop back
        self:changeState(constants.TASK_STATES.UNASSIGNED)
        return
    end

    self:generateSubtasks()
    self:populateSubtasks()

    self:changeState(constants.TASK_STATES.PREPARING)
end

function Task:PREPARING()
    -- currently nothing to do here
    self:changeState(constants.TASK_STATES.ASSIGNED)
end

function Task:ASSIGNED()
    local building_spot_found = self:findBuildingSpot()
    if building_spot_found then
        self:dispatchWorkerToNextStop()
        self:changeState(constants.TASK_STATES.BUILDING)
        self.timer_tick = game.tick
    end
end

function Task:BUILDING()
    
    local subtask_finished = self:invalidateTaskEntities()

    -- removing subtask and either restarting loop or task is finished
    if subtask_finished then
        self.subtasks[self.active_subtask_index] = nil
        self.active_subtask_index = nil
        self.building_spot = nil --for regular tasks only, may be outdated
        self.timer_tick = nil
        if next(self.subtasks) == nil then
            -- task is finished, sending back to depot
            self:log("Puttin task into TERMINATION due to completion")
            self:changeState(constants.TASK_STATES.TERMINATING)
        else
            -- rerun loop, complete new subtask
            self:log("Subtasks left: " .. table_size(self.subtasks))
            self:log("Looping task back to ASSIGNED")
            self:changeState(constants.TASK_STATES.ASSIGNED)
        end
    else
        self:changeState(constants.TASK_STATES.BUILDING)
    end
end

function Task:TERMINATING()
    self:endTask()
end
