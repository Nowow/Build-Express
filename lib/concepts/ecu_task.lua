require("lib.concepts.task")
require("lib.concepts.express_construction_unit")
require("lib.trains")

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
    local blueprint_name = self.blueprint_label
    for _, station in pairs(global.worker_station_register[blueprint_name]) do
        if station and station.valid then
            local train = station.get_stopped_train()
            if train ~= nil then
                self:log("Train found!")
                local control = station.get_control_behavior()
                if not control or (control and control.valid and not control.disabled) then
                    self:log("Station ok!")
                    local ECU = ExpressConstructionUnit:create()
                    ECU:setTrain(train)
                    local has_spider_carriages = ECU:aquireSpiderCarriers()
                    if has_spider_carriages then
                        self:log("Express Construction Unit found!")
                        self.worker = ECU
                        return true
                    end
                end
            end
        end
    end
    self:log('No workers available for ECU')
    return false
end

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
        local candidates = findNearestRails(self.bounding_box, 10)
        if #candidates > 0 then
            self:log("Parking spot candidates found: " .. #candidates )
            for _, rail in pairs(candidates) do
                if rail.valid and not rail.to_be_deconstructed() and checkIfTrainCanGetToRail(train, rail) then
                    hightlighRail(rail, {r = 0, g = 1, b = 0})
                    self:log("Found parking spot")
                    parking_spot = rail
                    self.parking_spot = parking_spot
                    ECU.gotoRail(parking_spot)
                    break
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
    if parking_spot and current_rail == parking_spot and not path_end_rail then
        self:log("Arrived at parking_spot!")
        ECU:deploy()
        self:changeState(constants.TASK_STATES.PREPARING)
    end
end

function EcuTask:PREPARING()
    local ECU = self.worker
    local worker_construction_radius = ECU:getWorkerConstructionRadius()
    if not worker_construction_radius then
        self:log("Couldnt get construction radius, looping back to PREPARED")
        self:changeState(constants.TASK_STATES.PREPARING)
    end
    self:generateSubtasks()
    self:populateSubtasks()
    -- skipping tileing if deconstruct
    if self.type == constants.TASK_TYPES.DECONSTRUCT then
        self:changeState(constants.TASK_STATES.ASSIGNED)
        return
    end
    self:tileWaterGhosts()
    self:changeState(constants.TASK_STATES.ASSIGNED)
end


function EcuTask:ASSIGNED()
    local ECU = self.worker
    local subtasks = self.subtasks
    local subtask_processing_index = self.subtask_processing_index
    local subtasks_left = table_size(self.subtasks)

    if subtasks_left == 0 then
        self:log("ASSIGNED, but no more subtasks left, puttin task into TERMINATION due to completion")
        self:changeState(constants.TASK_STATES.TERMINATING)
    end
    if subtask_processing_index then
        self:log("Currently processing subtask is " .. subtask_processing_index)
        local processing_result = ECU.subtask_processing_result
        if not processing_result then
            self:log("Processing result for subtask " .. subtask_processing_index .. "is false")
            local subtask, next_subtask_processing_index
            next_subtask_processing_index, subtask = next(subtasks)
            

        end
    end
    if not subtask_processed_index then    
        subtask_processed_index = 1
        ECU:processSubtask(self.subtasks[subtask_processed_index])
        -- looping back
        self:changeState(constants.TASK_STATES.ASSIGNED)
        return
    else
        

    end
end