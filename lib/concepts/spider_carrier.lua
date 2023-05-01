local constants = require("constants")

---@class SpiderCarrier
---@field wagon unknown
---@field id integer
---@field spider unknown

SpiderCarrier = {}
SpiderCarrier.__index = SpiderCarrier

script.register_metatable("spider_carrier_metatable", SpiderCarrier)

---@return SpiderCarrier
function SpiderCarrier:create(wagon)
    
    local carrier = {}
    carrier.wagon = wagon
    carrier.id = wagon.unit_number

    setmetatable(carrier, SpiderCarrier)
    return carrier
end

function SpiderCarrier:spawnProxy()
    local wagon = self.wagon
    return self.wagon.surface.create_entity({
        name = constants.spider_carrier_proxy_prototype_name,
        position = wagon.position,
        force = wagon.force,
      })
end

function SpiderCarrier:spawnSpidertron(spider_stack)
    local wagon = self.wagon
    local spider_name = spider_stack.prototype.place_result.name
    return wagon.surface.create_entity({
        name = spider_name,
        position = wagon.position,
        force = wagon.force,
        item = spider_stack
      })
end

function SpiderCarrier:releaseSpider()

    local wagon = self.wagon
    local wagon_inv = wagon.get_inventory(defines.inventory.cargo_wagon)
    local spider_name, _ = next(wagon_inv.get_contents())
    if spider_name == nil then
        log("Cant release spider bcs no contents in this wagon")
        return
    end
    local spider_stack, _ = wagon_inv.find_item_stack(spider_name)
    if spider_stack.prototype.place_result.type ~= 'spider-vehicle' then
        log("Cant release spider because item inside is not spider!!!")
    end
    
    local spider self:spawnSpidertron(spider_stack)
    wagon_inv.clear()
    self.spider = spider
    return spider
    
end

function SpiderCarrier:storeSpidertron(spider)
    log("Trying to store spider")
    if not spider.valid then
        log("Spider is not valid!!!")
        return false
    end

    local spider_name = spider.name
    local wagon = self.wagon

    if not wagon.can_reach_entity(spider) then
        log("Spider is out of reach")
        return false
    end
    local proxy = self:spawnProxy()
    local spider_mined = proxy.mine_entity(spider)
    if not spider_mined then
        log("Spider was not mined :(")
        return false
    end
    
    local proxy_inv = proxy.get_inventory(defines.inventory.character_main)
    local spider_stack, _ = proxy_inv.find_item_stack(spider_name)
    local wagon_inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
    if not wagon.can_insert(spider_stack) then
        log("Cant insert spider from proxy!!!!")
        self:spawnSpidertron(spider_stack)
        return false
    end
    wagon_inventory.insert(spider_stack)
    proxy.destroy()
    return true

end