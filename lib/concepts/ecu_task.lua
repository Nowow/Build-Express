require("lib.concepts.task")
require("lib.concepts.express_construction_unit")
require("lib.trains")

local constants = require("constants")
local fleet_manager = require("lib.fleet_manager")

---@class EcuTask: Task
---@field parking_spot unknown
---@field subtask_processing_index integer
---@field building_spot_candidates table
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

function EcuTask:setWorker(ECU)
    -- here worker is ECU
    self.worker = ECU
    if ECU then
        self.cargo_size = getCargoSize(ECU.train)    
    end    
end

function EcuTask:assignWorker()
    self:log("Looking for workers")

    local bounding_box = self.bounding_box
    local task_coords = getBoundingBoxCenter(bounding_box)

    local available_trains = fleet_manager.getFreeDronesSortedByDistance(task_coords, constants.spider_carrier_prototype_name)

    self:log("Found " .. #available_trains .. " available candidates!")

    local train, wagon

    for _, candidate in pairs(available_trains) do
        wagon = candidate.wagon
        train = candidate.train
        local ECU = ExpressConstructionUnit:create()
        ECU:setTrain(train)
        local has_spider_carriages = ECU:aquireSpiderCarriers()
        if has_spider_carriages then
            self:log("Train does have at least one spider carriage!")
            local enough_resources = self:checkTrainHasEnoughResources(train)
            if enough_resources then
                self:log("Train does have enough resources!")
                self:log("Express Construction Unit found!")
                self:setWorker(ECU)
                fleet_manager.registerTrainAsInAction(train, wagon, self)
                return true
            end
        end
    end

    self:log('No workers available for ECU')
    return false
end


function EcuTask:cleanupBeforeEndTask()
    self:log("ENDING TASK IN STATE " .. self.state)
    local task_type = self.type

    -- destroying all entities that are left
    local valid_entities_counter = 0
    if task_type == constants.TASK_TYPES.BUILD then
        
        for _, entity in pairs(self.entities) do
            if entity.valid then
                entity.destroy()
                valid_entities_counter = valid_entities_counter + 1
            end    
        end
        self:log("VALID GHOSTS LEFT: " .. valid_entities_counter)

    elseif task_type == constants.TASK_TYPES.DECONSTRUCT then
        -- unmarking for deconstruction 
        local force = game.get_player(self.player_index).force
        for _, entity in pairs(self.entities) do
            if entity.valid then
                entity.cancel_deconstruction(force)
                valid_entities_counter = valid_entities_counter + 1
            end
        
        end
        self:log("UNMARKED ENTITIES COUNT: " .. valid_entities_counter)
    end


    --destroying flying text
    for _, render_id in pairs(self.flying_text) do
        rendering.destroy(render_id)
    end

    update_task_frame(self, true)
end

function EcuTask:callbackWhenTrainCreated(new_train)
    self:log("callbackWhenTrainCreated called")
    if new_train == nil then
        self:log("No new train provided")
        self:log("Unable to reaquire worker after someone messed with train, terminating")
        self:setWorker(nil)
        self:forceChangeState(constants.TASK_STATES.TERMINATING)
    end
    local ECU = self.worker
    ECU:setTrain(new_train)
    local fits = ECU:ensureActiveSpiderCarrierIsStillHere()
    if fits then
        self:setWorker(ECU)
        self:log("Reaquired worker after someone messed with train")
    else
        self:log("ECU from provided new train does not fit for some reason, UB")
        self:log("Unable to reaquire worker after someone messed with train, restarting task")
        self:setWorker(nil)
        self:restartTask()
        --self:forceChangeState(constants.TASK_STATES.TERMINATING)
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

function EcuTask:restartTask(invalidate_and_recalculate_cost)
    invalidate_and_recalculate_cost = invalidate_and_recalculate_cost == nil and true or invalidate_and_recalculate_cost
    self:log("Restarting task...")
    local ECU = self.worker
    if ECU and ECU.train and ECU.train.valid then
        self:log("ECU is present and has a valid train, relieving it of its duties")
        fleet_manager.ECUfinishedTask(ECU)
    else
        self:log("Task did not have an ECU with valid train")
    end

    self:setWorker(nil)
    self.subtasks = nil
    self.subtask_count = nil
    self.subtask_processing_index = nil
    self.active_subtask = nil
    self.active_subtask_index = nil
    self.bounding_box = nil
    self.building_spot = nil
    self.building_spot_candidates = nil
    self.parking_spot = nil
    self.timer_tick = nil

    if invalidate_and_recalculate_cost then
        local new_entities, new_cost_to_build = self:invalidateEntitiesAndCalculateCostToBuild(self.entities)
        self.entities = new_entities
        self.cost_to_build = new_cost_to_build
    end
    
    self:log("Changing task state back to TASK_CREATED to walk path again")
    self:changeState(constants.TASK_STATES.TASK_CREATED)
end

function EcuTask:sortSubtasksByDistance(train_coords, subtasks)
    local distances = {}
    local sorter = {}
    local result = {}

    local subtask_coords, distance

    for _, subtask in pairs(subtasks) do
        
        subtask_coords = subtask.subtask_coords
        distance = DistanceBetweenTwoPoints(train_coords, subtask_coords)
        distances[distance] = subtask
        table.insert(sorter, distance)

    end

    table.sort(sorter)

    for _, distance in pairs(sorter) do
        table.insert(result, distances[distance])
    end
    return result
end


------------------------------------------------------------------
-----TASK FLOW
------------------------------------------------------------------

function EcuTask:UNASSIGNED()

    local search_offset = settings.global["ecu-parking-spot-search-offset"].value
    local candidates = findNearestRails(self.surface, self.bounding_box, search_offset)

    if #candidates < 1 then
        self:log("No possible parking spot available, waiting for options to appear")
        self:changeState(constants.TASK_STATES.UNASSIGNED)
        return
    end

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
        
        local building_spot_candidates = self.building_spot_candidates or {}
        local candidates_cnt = table_size(building_spot_candidates)
        

        if candidates_cnt == 0 then
            building_spot_candidates = findNearestRails(self.surface, self.bounding_box, search_offset) or {}
            self:log("Was 0 candidates, starting new iteration, collected " .. table_size(building_spot_candidates))
            self.building_spot_candidates = building_spot_candidates
            if table_size(building_spot_candidates) == 0 then
                self:log("No candidates available right now, looping back")
            else
                self:log("Collected pool of possible candidates for building spot, looping back")
            end
            self:changeState(constants.TASK_STATES.PARKING)
            return
        end

        self:log("Parking spot candidates left to check: " .. candidates_cnt )

        local cycle_counter = 0
        local checks_per_cycle = math.min(constants.ecu_max_building_spots_checked_per_cycle, candidates_cnt)

        while cycle_counter < checks_per_cycle do

            local i, rail = next(building_spot_candidates)

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
                building_spot_candidates[i] = nil
            end
            cycle_counter = cycle_counter + 1
        end
        

        if not parking_spot then
            self:log("No parking spot found yet :(")
        end
        self:changeState(constants.TASK_STATES.PARKING)
        return
    end
    local current_rail = train.front_rail
    local path_end_rail = train.path_end_rail
    if parking_spot and path_end_rail then
        --self:log("CHUGA CHUGA,")
        self:changeState(constants.TASK_STATES.PARKING)
        return
    end
    if parking_spot and not path_end_rail then
        self:log("CHOOOO CHOOOOOOO!")
        self:log("Arrived at parking_spot!")
        if parking_spot ~= current_rail then
            self:log("For some reason its a different rail, well whatever, logging for probable UB")
        end
        local cost_to_build_spaced = spreadBuildingCostIntoCyclicalChunks(self.cost_to_build)
        ECU:deploy(cost_to_build_spaced)
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
    
    local subtask_finished = self:invalidateSubtaskEntities()

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
        if spider == nil or not spider.valid then
            self:log("No spider present during BUILDING, probably killed/stolen/abudcted by aliens")
            error("HERE SHOULD BE LOGIC TO RESTART TASK")
        elseif self.type == constants.TASK_TYPES.BUILD and worker:checkRobotsAreBack() then
            local spider_contents = spider.get_inventory(defines.inventory.spider_trunk).get_contents()
            local subtask = self.subtasks[self.active_subtask_index]
            local spider_available_count
            for item, count in pairs(subtask.cost_to_build) do
                self:log("Assessing if spider has enought of: " .. item)
                spider_available_count = spider_contents[item] or 0
                self:log("Spider has: " .. spider_available_count .. ", current cost: " .. count)
                if count > spider_available_count then
                    self:log("RESUPPLY IS IN ORDER!")
                    self:log("Invalidating left ghost tiles...")
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
    if not ECU or not ECU.train or not ECU.train.valid then
        self:log("Cant resupply because no ECU, ALARM!")
        self:restartTask()
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
    self:log("Checking this train has resources to finish task")

    ECU:emptySpiderBuildingMaterials()
    local new_entities, new_cost_to_build = self:invalidateEntitiesAndCalculateCostToBuild(self.entities)
    self.entities = new_entities
    self.cost_to_build = new_cost_to_build

    -- probable point of failure, not checking train
    local train_still_has_resources = self:checkTrainHasEnoughResources(ECU.train)
    if not train_still_has_resources then
        self:log("Current train does not have resources to finish the task, restarting it!")
        self:restartTask(false)
        return
    end
    local cost_to_build_spaced = spreadBuildingCostIntoCyclicalChunks(self.cost_to_build)
    ECU:resupply({
        resource_cost=cost_to_build_spaced,
        empty_spider=false
    })
    local current_subtask = self.subtasks[self.active_subtask_index]
    spider_carrier:navigateSpiderToSubtask(current_subtask)
    self:log("Resupply finished, sending spider back to subtask")
    self:changeState(constants.TASK_STATES.BUILDING)
    
end


function EcuTask:TERMINATING()

    self:cleanupBeforeEndTask()

    local ECU = self.worker
    if not ECU or not ECU.train or not ECU.train.valid then
        self:log("During termination task had no ECU, ECU had no train or train was not valid, anyway task wrapped up!")
        return
    end

    fleet_manager.ECUfinishedTask(ECU)
end