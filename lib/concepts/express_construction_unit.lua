require("lib.concepts.spider_carrier")
local constants = require("constants")

---@class ExpressConstructionUnit
---@field train unknown
---@field spider_carriers SpiderCarrier[]
---@field active_carrier SpiderCarrier
---@field parked boolean
---@field subtask_processing_result boolean
---@field state string
---@field wrapping_up boolean
---@field going_home boolean
ExpressConstructionUnit = {}
ExpressConstructionUnit.__index = ExpressConstructionUnit

script.register_metatable("ecu_metatable", ExpressConstructionUnit)

---@return ExpressConstructionUnit
function ExpressConstructionUnit:create()
    
    local ecu = {}
    ecu.spider_carriers = {}
    ecu.parked = false
    ecu.wrapping_up = false
    ecu.going_home = false

    setmetatable(ecu, ExpressConstructionUnit)
    return ecu
end

function ExpressConstructionUnit:setTrain(train)
    log("Setting train for ECU")
    if train == nil then
        error("Trying to set ECU train, but it is NIL")    
    end
    
    if not train.valid then
        error("Trying to set ECU train, but it is NOT VALID")    
    end
    self.train = train
end

function ExpressConstructionUnit:ensureActiveSpiderCarrierIsStillHere()
    log("Trying to understand whether new assigned train has old active carrier wagon")
    local active_carrier_wagon = self.active_carrier.wagon
    if active_carrier_wagon.valid then
        log("Active carrier wagon still exists and valid!")
    end
    local carriages = self.train.carriages
    for _, carriage in pairs(carriages) do
        if carriage.unit_number == active_carrier_wagon.unit_number then
            log("Found old carrier wagon in this ECU train! All is good")
            return true
        end
    end
    log("This ECU train does not contain old active carrier wagon! Very sad, UB")
    return false
end


function ExpressConstructionUnit:findSpiderCarriers(train)
    log("Looking for Spider Carriers")
    local carriages = train.carriages
    log("Found " .. #carriages .. "carriages")
    local spider_carriers = {}
    for _, carriage in pairs(carriages) do
        if carriage.name == constants.spider_carrier_prototype_name then
            local spider_carrier = SpiderCarrier:create(carriage, self)
            table.insert(spider_carriers, spider_carrier)
        end
    end
        return spider_carriers
    end

function ExpressConstructionUnit:aquireSpiderCarriers()
    log("Trying to aquire Spider Carriers")
    local spider_carriers = self:findSpiderCarriers(self.train)
    if #spider_carriers == 0 then
        log("No spider carriages!")
        return false
    end

    self.spider_carriers = spider_carriers

    --planning to make more than one spider carrier usable, now only one
    self.active_carrier = spider_carriers[1]
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

function ExpressConstructionUnit:goHome()
    log("ECU going back home")
    local train = self.train
    local removed_temps = removeAllTempStops(train)
    self.going_home = true
    log("Temp station removed: " .. removed_temps)
end

function ExpressConstructionUnit:orderFindSpiders()
    if next(self.spider_carriers) == nil then
        error("ECU was ordered to find spiders, but has no spider carriers!")
        return
    end
    local spider_carriers = self.spider_carriers
    local already_has_spider
    local spider_stored
    local at_least_one_spider_stored = false
    for _, carrier in pairs(spider_carriers) do
        already_has_spider = carrier:checkIfSpiderStored() or at_least_one_spider_stored
        at_least_one_spider_stored = already_has_spider or at_least_one_spider_stored
        if already_has_spider then
            log("SpiderCarrier already has a spider stored")
        else
            spider_stored = carrier:findNearestSpider() or at_least_one_spider_stored
            at_least_one_spider_stored = spider_stored or at_least_one_spider_stored
            if spider_stored then
                log("Spider Carrier found and stored a spider!")
            end
        end
    end
    return at_least_one_spider_stored
end


function ExpressConstructionUnit:attemptInsertInSpider(train, spider, item, count)
    log("Inserting item " .. item .. " in amount " .. count)
    local available_in_train = train.get_item_count(item)
    if available_in_train > 0 then
        if available_in_train < count then
            log("There was not enough, required: " .. count .. ', available: ' .. available_in_train)
            count=available_in_train
        end
        local actually_inserted = spider.insert({name=item, count=count})
        train.remove_item({name=item, count=math.min(count, actually_inserted)})
        if actually_inserted ~= count then
            log("Inserted less than was planning, " .. count .. ' ' .. actually_inserted)
        end
    else
        log("There is no such item in ECU!")
    end
end

function ExpressConstructionUnit:supplyInventory()
    local train = self.train
    local spider = self.active_carrier.spider

    local spider_grid = spider.grid
    local total_robot_limit = 0
    for name, limit in pairs(global.roboport_prototypes) do
        total_robot_limit = total_robot_limit + (spider_grid.count(name) * limit)
    end
    local robot_cost = math.min(train.get_item_count("construction-robot") or 0, total_robot_limit)
    if robot_cost == 0 then
        log("ECU has no robots to supply!")
    end
    local explosives_cost = constants.cliff_explosives_cost
    self:attemptInsertInSpider(train, spider, 'construction-robot', robot_cost)
    self:attemptInsertInSpider(train, spider, 'cliff-explosives', explosives_cost)

end

function ExpressConstructionUnit:supplyResources(resource_cost)
    local cost_modifier = settings.global["ecu-building-cost-modifier"].value
    log("Cost modifier is: " .. cost_modifier)

    local train = self.train
    local spider = self.active_carrier.spider

    for item, count in pairs(resource_cost) do
        count = math.floor(count*cost_modifier)
        self:attemptInsertInSpider(train, spider, item, count)
    end
end

function ExpressConstructionUnit:emptySpiderInventory()
    local train = self.train
    local spider = self.active_carrier.spider
    local spider_inv = spider.get_inventory(defines.inventory.spider_trunk)

    local spider_inv_contents = spider_inv.get_contents()
    spider_inv_contents['construction-robot'] = nil
    spider_inv_contents['cliff-explosives'] = nil

    for item, count in pairs(spider_inv_contents) do
        spider_inv.remove({name=item, count=count})
        train.insert({name=item, count=count})
    end
end

function ExpressConstructionUnit:deploy(resource_cost)
    local active_carrier = self.active_carrier
    active_carrier:releaseSpider()
    if not resource_cost then
        return
    end
    local train = self.train
    local spider = active_carrier.spider

    self:supplyInventory()
    self:supplyResources(resource_cost)
end

function ExpressConstructionUnit:resupply(args)
    local empty_spider = args.empty_spider
    empty_spider = true and empty_spider == nil or empty_spider

    local resource_cost = args.resource_cost
    if resource_cost == nil then
        log("Resupplying, but no resource cost provided")
        resource_cost = {}
    end

    if empty_spider then
        log("Emptying spider during resupply")
        self:emptySpiderInventory()
    end
    self:supplyResources(resource_cost)

end

function ExpressConstructionUnit:startProcessingSubtask(subtask)
    log("Starting processing subtask in ECU")
    local active_carrier = self.active_carrier
    self.subtask_processing_result = nil
    --subtask.cost_to_build = calculateActualCostToBuild(subtask.entities)
    active_carrier:navigateSpiderToSubtask(subtask)
end

function ExpressConstructionUnit:subtaskProcessingCallback(result)
    self.subtask_processing_result = result
end

function ExpressConstructionUnit:moveSpiderToCarrier()
    log("ECU got order to move spider to active carrier")
    local active_carrier = self.active_carrier
    active_carrier:startCollectSpider()
end

function ExpressConstructionUnit:orderRetractSpider()
    local active_carrier = self.active_carrier
    self.wrapping_up = true
    local spider = active_carrier.spider
    if spider then
        active_carrier:startCollectSpider()
    end
end

function ExpressConstructionUnit:pollRetractSpider()
    local active_carrier = self.active_carrier
    local spider = active_carrier.spider
    local spider_outside = (spider and spider.valid)
    local spider_inside = active_carrier:checkIfSpiderStored()
    if spider_inside and not spider_outside then
        log("Spider is back stored in wagon")
        return true
    elseif not spider_inside and spider_outside then
        log("Spider Carrier is empty, but spider still present, trying to store it")
        return active_carrier:storeSpider()
    elseif not spider_inside and not spider_outside then
        log("Someone stole the spider!")
        return true
    else
        log("Unhandled behavior while calling pollRetractSpider")
        return true
    end

end

function ExpressConstructionUnit:checkIfBackHome()
    local train = self.train
    local schedule = train.schedule
    local is_current_stop_tmp = schedule.records[schedule.current].temporary or false
    -- 7 is 'station_wait'
    -- checking for tmp just for some player freedom
    return train.state == 7 and not is_current_stop_tmp
end