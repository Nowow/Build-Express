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

end

function Task:log(message)
    log(string.format("TASK_ID %-12s", self.id .. ':') .. message)
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
    local worker = getWorker(self.blueprint_label)
    self:log("Looking for workers")
    if not worker then
        self:log('No workers available')
        return false
    end
    self:log("Worker found!")
    self.worker = worker
    -- calculating construction area reach , but accounting for the fact that locomotive (8 tiles) is first and 2 more for good measure
    local worker_construction_radius = getRoboportRange(worker) - 10
    self:log("worker_construction_radius: " .. worker_construction_radius)
    self.worker_construction_radius = worker_construction_radius
    return true
end

function Task:tileWaterGhosts()
    for _, subtask in pairs(self.subtasks) do
        for __, ghost in pairs(subtask.entities) do
            if ghost.valid then
                
                local dummy_replaced = replaceDummyEntityGhost(ghost)
                -- if ghost still valid then replacement didnt take place
                if not dummy_replaced then
                    local landfill_ghosts = landfill.placeGhostLandfill(ghost)
                    hightlightEntity(ghost, 3, {r=1,g=1,b=0})
                    for _, t in pairs(landfill_ghosts) do
                        table.insert(subtask.tiles, t)
                    end
                end
            end
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

    if subtask_finished then
        self.subtasks[active_subtask_index] = nil
        self.active_subtask_index = nil
        self.building_spot = nil
        self.timer_tick = nil
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
        self:log("REMOVED " .. temps_removed .. " TEMP STOPS")
    end

    --makeTrainGoToDepot(task.worker)
    update_task_frame(self, true)
    global.construction_tasks[self.state]:remove(self.id)
end



------------------------------------------------------------------
-----TASK FLOW
------------------------------------------------------------------

function Task:TASK_CREATED()
    self:findBoundingBox()
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
    -- skipping tileing if deconstruct
    if self.type == constants.TASK_TYPES.DECONSTRUCT then
        self:changeState(constants.TASK_STATES.ASSIGNED)
        return
    end
    self:tileWaterGhosts()
    self:changeState(constants.TASK_STATES.ASSIGNED)
end

function Task:ASSIGNED()
    local building_spot_found = self:findBuildingSpot()
    if building_spot_found then
        self:dispatchWorkerToNextStop()
        self:changeState(constants.TASK_STATES.BUILDING)
    end
end

function Task:BUILDING()
    
    local subtask_finished = self:invalidateTaskEntities()

    -- removing subtask and either restarting loop or task is finished
    if subtask_finished then

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