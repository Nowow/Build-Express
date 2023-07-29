require("lib.concepts.task")
require("lib.concepts.express_construction_unit")
require("lib.trains")
local constants = require("constants")

---@class EcuTask: Task
---@field parking_spot unknown
---@field subtask_processing_index integer
EcuTask = {}

EcuTask.__index = EcuTask
script.register_metatable("ecutask_metatable", EcuTask)
EcuTask = setmetatable(EcuTask, Task)

---@return EcuTask
function EcuTask:new()
    local task = {}
    setmetatable(task, EcuTask)
    return task
end

function EcuTask:assignWorker()
    self:log("Looking for workers")
    for station in iterateStations() do
        local control = station.get_control_behavior()
        if not control or (control and control.valid and not control.disabled) then
            self:log("Station ok!")
            local train = station.get_stopped_train()
            if train ~= nil then
                self:log("Train found!")
                local ECU = ExpressConstructionUnit:create()
                ECU:setTrain(train)
                local has_spider_carriages = ECU:aquireSpiderCarriers()
                if has_spider_carriages then
                    local enough_resources = self:checkTrainHasEnoughResources(train)
                    if enough_resources then
                        self:log("Express Construction Unit found!")
                        self.worker = ECU
                        registerTrainAsInAction(train, self)
                        return true
                    end
                end
            end
        end
    end
    self:log('No workers available for ECU')
    return false
end

function EcuTask:startEndTask()
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

    local ECU = self.worker
    if ECU ~= nil then
        ECU:orderRetractSpider()
    end
    update_task_frame(self)
end

function EcuTask:callbackWhenTrainCreated(old_train_id, new_train)
    local ECU = self.worker
    ECU:setTrain(new_train)
    local fits = ECU:aquireSpiderCarriers()
    if fits then
        self.attempted_to_reaquire_worker = false
        self.worker = ECU
        registerTrainAsInAction(new_train, self)
        unregisterTrainAsInAction(old_train_id)
        self:log("Reaquired worker after someone messed with train")
    elseif self.attempted_to_reaquire_worker then
        self:log("Unable to reaquire worker after someone messed with train, terminating")
        unregisterTrainAsInAction(old_train_id)
        self.worker = nil
        self:forceChangeState(constants.TASK_STATES.TERMINATING)
    else
        self:log("Unable to reaquire worker after someone messed with train, one more attempt left")
        self.attempted_to_reaquire_worker = true
    end
end

function EcuTask:ensureHasValidEntities(subtask)
    --making sure there is at least one valid entity in subtask
    for _, e in pairs(subtask.entities) do
        if e.valid then
            return true
        end
    end
    return false
end


------------------------------------------------------------------
-----TASK FLOW
------------------------------------------------------------------

function EcuTask:UNASSIGNED()
    local worker_found = self:assignWorker()
    if not worker_found then
        --loop back
        self:changeState(constants.TASK_STATES.UNASSIGNED)
        return
    end
    self:changeState(constants.TASK_STATES.PARKING)
end

function EcuTask:PARKING()
    local ECU = self.worker
    local train = self.worker.train

    local parking_spot = self.parking_spot
    if not parking_spot then
        self:log("Going to find a parking spot")
        -- find and send to parking_spot
        local search_offset = settings.global["ecu-parking-spot-search-offset"].value
        local candidates = findNearestRails(self.surface, self.bounding_box, search_offset)
        if #candidates > 0 then
            self:log("Parking spot candidates found: " .. #candidates )
            for _, rail in pairs(candidates) do
                if rail.valid and not rail.to_be_deconstructed() and checkIfTrainCanGetToRail(train, rail) then
                    hightlighRail(rail, {r = 0, g = 1, b = 0})
                    self:log("Found parking spot")
                    local has_at_least_one_spider = ECU:orderFindSpiders()
                    if has_at_least_one_spider then
                        self:log("ECU has at least one spider, dispatching!")
                        parking_spot = rail
                        self.parking_spot = parking_spot
                        ECU:gotoRail(parking_spot)
                        break
                    else
                        self:log("ECU has no spiders, looping back to PARKING")
                        self:changeState(constants.TASK_STATES.PARKING)
                        return
                    end
                    
                else
                    hightlighRail(rail, {r = 1, g = 0, b = 0})
                end
            end
        end
        if not parking_spot then
            self:log("No parking spot found :(")
        end
        self:changeState(constants.TASK_STATES.PARKING)
        return
    end
    local current_rail = train.front_rail
    local path_end_rail = train.path_end_rail
    if parking_spot and path_end_rail then
        self:log("CHUGA CHUGA,")
        self:changeState(constants.TASK_STATES.PARKING)
        return
    end
    if parking_spot and not path_end_rail then
        self:log("CHOOOO CHOOOOOOO!")
        self:log("Arrived at parking_spot!")
        if parking_spot ~= current_rail then
            self:log("For some reason its a different rail, well whatever, logging for probable UB")
        end
        ECU:deploy(self.cost_to_build)
        self:changeState(constants.TASK_STATES.PREPARING)
        return
    end
    log("UB in EcuTask PARKING handler!")

end

function EcuTask:PREPARING()
    local ECU = self.worker
    -- minus 5 to allow for spidertron unpredictable wiggling around destination
    local worker_construction_radius = ECU:getWorkerConstructionRadius()
    if not worker_construction_radius then
        self:log("Couldnt get construction radius, looping back to PREPARED")
        self:changeState(constants.TASK_STATES.PREPARING)
        return
    end
    self.worker_construction_radius = math.max(worker_construction_radius - constants.subtask_construction_area_coverage_ecu_offset, 15)
    self:generateSubtasks()
    self:populateSubtasks()
    -- skipping tileing if deconstruct
    if self.type == constants.TASK_TYPES.DECONSTRUCT then
        self:changeState(constants.TASK_STATES.ASSIGNED)
        return
    end
    self:changeState(constants.TASK_STATES.ASSIGNED)
end


function EcuTask:ASSIGNED()
    local ECU = self.worker
    local subtasks = self.subtasks
    local subtask_processing_index = self.subtask_processing_index
    local subtasks_left = table_size(self.subtasks)
    local next_subtask_processing_index, subtask_to_process, has_valid_entities

    if subtasks_left == 0 then
        self:log("ASSIGNED, but no more subtasks left, puttin task into TERMINATION due to completion")
        self:changeState(constants.TASK_STATES.TERMINATING)
        return
    end

    if not subtask_processing_index then --assign a new subtasks to be processed
        next_subtask_processing_index, subtask_to_process = next(subtasks)
        has_valid_entities = self:ensureHasValidEntities(subtask_to_process)
        if not has_valid_entities then
            self:log("Subtask " .. next_subtask_processing_index .. "has no valid entities, deleting it")
            subtasks[next_subtask_processing_index] = nil
            self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
            return
        end
        self.subtask_processing_index = next_subtask_processing_index
        self:log("Starting task processing, next subtask is " .. next_subtask_processing_index)
        ECU:startProcessingSubtask(subtask_to_process)
        self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
        return
    else -- subtask processing loop
        self:log("Currently processing subtask is " .. subtask_processing_index)
        local processing_result = ECU.subtask_processing_result
        ECU.subtask_processing_result = nil --invalidate result after reading
        if processing_result == nil then
            self:log("Processing result for subtask " .. subtask_processing_index .. "is yet to be determined")
            self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
            return
        elseif processing_result == false then
            self:log("Processing result for subtask " .. subtask_processing_index .. "is false")
            --subtasks[subtask_processing_index] = nil
            self:log("Skipping subtask " .. subtask_processing_index)

            next_subtask_processing_index, subtask_to_process = next(subtasks, subtask_processing_index)

            -- should circle back to prevoiusly skipped subtasks if any
            if next_subtask_processing_index == nil then
                self.subtask_processing_index = nil
                self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
                return
            end

            has_valid_entities = self:ensureHasValidEntities(subtask_to_process)
            if not has_valid_entities then
                self:log("Subtask " .. next_subtask_processing_index .. "has no valid entities, deleting it")
                subtasks[next_subtask_processing_index] = nil
                self.subtask_processing_index = nil
                self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
                return
            end
            self.subtask_processing_index = next_subtask_processing_index
            self:log("Now processing subtaks " .. next_subtask_processing_index)
            ECU:startProcessingSubtask(subtask_to_process)
            self:changeState(constants.TASK_STATES.ASSIGNED) -- looping back
            return
        else
            self:log("Processing result for subtask " .. subtask_processing_index .. "is true, moving to building phase")
            self.active_subtask_index = subtask_processing_index
            self.subtask_processing_index = nil
            self.timer_tick = game.tick
            self:changeState(constants.TASK_STATES.BUILDING)
            return
        end
    end
end

function EcuTask:BUILDING()
    
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
        local worker = self.worker
        
        -- determining whether resupply is necessary
        local spider = worker.active_carrier.spider
        if spider == nil then
            self:log("No spider present during BUILDING, wtf")
        else
            local spider_contents = spider.get_inventory(defines.inventory.spider_trunk).get_contents()
            local subtask = self.subtasks[self.active_subtask_index]
            local spider_available_count
            for item, count in pairs(subtask.cost_to_build) do
                self:log("Assessing if spider has enought of: " .. item)
                spider_available_count = spider_contents[item] or 0
                self:log("Spider has: " .. spider_available_count .. ", current cost: " .. count)
                if count > spider_available_count then
                    self:log("RESUPPLY IS IN ORDER!")
                    worker:moveSpiderToCarrier()
                    self:changeState(constants.TASK_STATES.RESUPPLYING)
                    return
                end
            end
        end
        
        local building_spot = self.building_spot
        if building_spot ~= nil then
            local building_spot_scheduled = isBuildingSpotInSchedule(worker, building_spot)
            if not building_spot_scheduled then
                self:log("Worker had no stop at building spot, redispatching it")
                self:dispatchWorkerToNextStop()
            end
        end
        self:changeState(constants.TASK_STATES.BUILDING)
    end
end

function EcuTask:RESUPPLYING()
    local ECU = self.worker
    if not ECU then
        self:log("Cant resupply because no ECU, ALARM!")
        self:changeState(constants.TASK_STATES.RESUPPLYING)
        return
    end
    local spider_carrier = ECU.active_carrier
    local spider_is_near = spider_carrier:checkIfSpiderIsReachable()
    if not spider_is_near then
        self:log("Resupplying, but spider is not yet near")
        self:changeState(constants.TASK_STATES.RESUPPLYING)
        return
    end
    self:log("Spider is near carrier, trying to insert whats left of subtask")
    ECU:resupply()
    spider_carrier:navigateSpiderToSubtask()
    self:log("Resupply finished, sending spider back to subtask")
    self:changeState(constants.TASK_STATES.BUILDING)
    
end

function EcuTask:TERMINATING()
    local ECU = self.worker
    if not ECU then
        update_task_frame(self, true)
        self:log("Task wrapped up!")
        return
    end
    if not ECU.wrapping_up then
        self:startEndTask()
        self:changeState(constants.TASK_STATES.TERMINATING)
        return
    else
        local spider_is_back = ECU:pollRetractSpider()
        if not spider_is_back then
            self:log("Spider not back yet")
            self:changeState(constants.TASK_STATES.TERMINATING)
            return
        end

        local going_home = ECU.going_home
        if spider_is_back and not going_home then
            self:log("Sent ECU back home!")
            ECU:goHome()
            self:changeState(constants.TASK_STATES.TERMINATING)
            return
        end

        local home = ECU:checkIfBackHome()
        if home then
            ECU:deploy()
            unregisterTrainAsInAction(ECU.train.id)
            update_task_frame(self, true)
            self:log("Task wrapped up!")
            return
        end
        self:changeState(constants.TASK_STATES.TERMINATING)
    end
end