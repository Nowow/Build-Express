require("lib.concepts.spider_carrier")
local constants = require("constants")

---@class ExpressConstructionUnit
---@field train unknown
---@field spider_carriers table
ExpressConstructionUnit = {}
ExpressConstructionUnit.__index = ExpressConstructionUnit

script.register_metatable("ecu_metatable", ExpressConstructionUnit)

---@return ExpressConstructionUnit
function ExpressConstructionUnit:create()
    
    local ecu = {}
    ecu.spider_carriers = {}

    setmetatable(ecu, ExpressConstructionUnit)
    return ecu
end

function ExpressConstructionUnit:setTrain(train)
    self.train = train
end

function ExpressConstructionUnit:aquireSpiderCarrier(wagon)
    log("Trying to create Spider Carrier")
    if not wagon.valid then return end
    local train = self.train
    if not train or not train.valid then 
        log("No train set yet")
        return 
    end
    local id = wagon.unit_number
    if self.spider_carriers[id] ~= nil then
        log("Express Construction Unit already has this wagon as Spider Carrier")
    end
    if wagon.name == constants.spider_carrier_prototype_name then
        self.spider_carriers[id] = SpiderCarrier:create(wagon)
        log("Created Spider Carrier")
    end
end


