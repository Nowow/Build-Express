require("lib.concepts.spider_carrier")
local constants = require("constants")

---@class ExpressConstructionUnit
---@field train unknown
---@field spider_carriers SpiderCarrier[]
---@field active_carrier SpiderCarrier
---@field parked boolean
---@field subtask_processing_result boolean
ExpressConstructionUnit = {}
ExpressConstructionUnit.__index = ExpressConstructionUnit

script.register_metatable("ecu_metatable", ExpressConstructionUnit)

---@return ExpressConstructionUnit
function ExpressConstructionUnit:create()
    
    local ecu = {}
    ecu.spider_carriers = {}
    ecu.parked = false

    setmetatable(ecu, ExpressConstructionUnit)
    return ecu
end

function ExpressConstructionUnit:setTrain(train)
    self.train = train
end

function ExpressConstructionUnit:aquireSpiderCarriers()
    log("Looking for Spider Carriers")
    local carriages = self.train.carriages
    log("Found " .. #carriages .. "carriages")
    local spider_carriers = self.spider_carriers

    for _, carriage in pairs(carriages) do
        if carriage.name == constants.spider_carrier_prototype_name then
            local spider_carrier = SpiderCarrier:create(carriage, self)
            table.insert(spider_carriers, spider_carrier)
        end
    end
    if #spider_carriers == 0 then
        log("No spider carriages!")
        return false
    end

    --planning to make more than one spider carrier usable, now only one
    self.active_carrier = self.spider_carriers[1]
    return true
end

function ExpressConstructionUnit:getWorkerConstructionRadius()
    -- currently cant get value because should wait for logistic_cell to set up after spawning
    -- return 15 --lowest possible


    local active_carrier = self.active_carrier
    if not active_carrier.wagon.valid then
        log("Cant get worker_construction_radius from ECU because active carrier wagon is not valid!")
        return
    end
    local spider = active_carrier.spider
    if not spider then
        log("No spider released yet, trying to release now...")
        spider = active_carrier:releaseSpider()
        if not spider then
            log("Cant get worker_construction_radius from ECU because active carrier wagon cant spawn spider")
            return
        end
    end
    local logistic_cell = spider.logistic_cell
    if not logistic_cell then
        -- can happen if spider just spawned (like by code above) and it does not yet have a logistic_cell
        log("Cant get worker_construction_radius from ECU because active carrier wagon has no logistic cell, will circle back bcs how game works, see comments in code!")
        return
    else
        return logistic_cell.construction_radius
    end
    
end

function ExpressConstructionUnit:gotoRail(rail)
    local train = self.train
    local schedule = train.schedule
    local schedule_entry = {
        rail=rail,
        wait_conditions={
            {
                type='time',
                ticks=constants.parking_wait_time,
                compare_type='and'
            }
        },
        temporary=true
    }
    table.insert(schedule.records, schedule_entry)
    schedule.current = #schedule.records
    train.schedule = schedule
end

function ExpressConstructionUnit:goHome(rail)
    log("ECU going back home")
    local train = self.train
    local removed_temps = removeAllTempStops(train)
    log("Temp station removed: " .. removed_temps)
end


function ExpressConstructionUnit:deploy()
    local active_carrier = self.active_carrier
    active_carrier:releaseSpider()
end

function ExpressConstructionUnit:startProcessingSubtask(subtask)
    log("Starting processing subtask in ECU")
    local active_carrier = self.active_carrier
    self.subtask_processing_result = nil
    active_carrier:navigateSpiderToSubtask(subtask)
end

function ExpressConstructionUnit:subtaskProcessingCallback(result)
    self.subtask_processing_result = result
end

