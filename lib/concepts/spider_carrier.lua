require("lib.utils")
local constants = require("constants")

local pathfinder = require("lib.pathfinder")
---@class SpiderCarrier
---@field wagon unknown
---@field id integer
---@field ECU ExpressConstructionUnit
---@field spider unknown
---@field goal_candidates table
---@field navigation_start_tick integer
SpiderCarrier = {}
SpiderCarrier.__index = SpiderCarrier

script.register_metatable("spider_carrier_metatable", SpiderCarrier)

---@return SpiderCarrier
function SpiderCarrier:create(wagon, ECU)
    
    local carrier = {}
    carrier.wagon = wagon
    carrier.id = wagon.unit_number
    carrier.ECU = ECU
    carrier.goal_candidates = {}

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
    local surface = wagon.surface
    local spider_name = spider_stack.prototype.place_result.name
    local spider = surface.create_entity({
        name = spider_name,
        position = wagon.position,
        force = wagon.force,
        item = spider_stack
      })
    surface.create_trivial_smoke({name='smoke-building', position=spider.position})
    return spider
    
end

function SpiderCarrier:getSpiderStack()
    local wagon = self.wagon
    local wagon_inv = wagon.get_inventory(defines.inventory.cargo_wagon)
    local item_name, _ = next(wagon_inv.get_contents())
    if item_name == nil then
        log("Cant give spider stack because no contents in this wagon")
        return
    end
    log("DEBUG: contents of spider wagon: " .. item_name)
    
    local item_stack, _ = wagon_inv.find_item_stack(item_name)
    log("DEBUG: contents of spider_stack: " .. item_stack.prototype.name)
    local place_result = item_stack.prototype.place_result
    if place_result == nil or not item_stack.prototype.place_result.type == 'spider-vehicle' then
        log("Spider Carrier has something that clearly is not spider, spilling it")
        local surface = wagon.surface
        surface.spill_item_stack(
            wagon.position,
            item_stack
        )
        wagon_inv.clear()
        return
    end
    return item_stack
end

function SpiderCarrier:releaseSpider()

    local wagon = self.wagon
    local wagon_inv = wagon.get_inventory(defines.inventory.cargo_wagon)

    local spider_stack = self:getSpiderStack()
    if not spider_stack then
        log("Cant release spider because item inside is not spider!!!")
        return
    end

    local spider = self:spawnSpidertron(spider_stack)
    wagon_inv.clear()
    self.spider = spider
    return spider
end

log("Trying to collect spider")
function SpiderCarrier:startCollectSpider()
    local spider = self.spider
    local wagon = self.wagon
    if not spider then
        log("Spider is nil!")
        return
    end
    if not spider.valid then
        log("Spider is not valid!")
        return
    end
    if not wagon.valid then
        log("Wagon is not valid!")
        return
    end
    local start = self:getSpiderPathStartPosition()
    local goal = wagon.position

    local pathing_request_info = {
        action=constants.spider_carrier_collect_spider_action,
        unit=spider,
        start=start,
        goal=goal,
        attempt=1,
        callback_source=self,
        auto_retry=true,
    }
    pathfinder.request_path(pathing_request_info)
end

function SpiderCarrier:findAndStoreNearestSpider()
    local wagon = self.wagon
    local candidates = wagon.surface.find_entities_filtered{
        type='spider-vehicle', radius=constants.spider_carrier_spider_search_radius, position=wagon.position
    }
    for _, spider in pairs(candidates) do
        if spider.get_driver() == nil then
            log("Spider Carrier found a spider nearby")
            self.spider=spider
            return self:storeSpider()
        end
    end
    log("Spider Carrier found no spiders nearby")
    return false
end

function SpiderCarrier:checkIfSpiderIsReachable()
    log("Checking if spider is reachable")
    local spider = self.spider
    local wagon = self.wagon
    if not spider then
        log("Spider is nil!")
        return
    end
    if not spider.valid then
        log("Spider is not valid!")
        return
    end
    if not wagon.valid then
        log("Wagon is not valid!")
        return
    end

    local proxy = self:spawnProxy()
    local can_reach = proxy.can_reach_entity(spider)
    proxy.destroy()
    if can_reach then
        log("Spider is reachable!!!")
    else
        log("Spider is not reachable yet...")
    end
    return can_reach
    
end

function SpiderCarrier:storeSpider()
    log("Trying to store spider")
    local spider = self.spider
    if not spider.valid then
        log("Spider is not valid!!!")
        return false
    end

    local wagon = self.wagon
    local wagon_inventory = wagon.get_inventory(defines.inventory.cargo_wagon)
    if not wagon_inventory.is_empty() then
        log("Spider Carrier inventory is not empty, cant collect spider!!!")
        return false
    end

    local spider_name = spider.name
    local proxy = self:spawnProxy()

    if not proxy.can_reach_entity(spider) then
        log("Spider is out of reach")
        proxy.destroy()
        return false
    end
    
    local spider_mined = proxy.mine_entity(spider)
    if not spider_mined then
        log("Spider was not mined :(")
        proxy.destroy()
        return false
    end
    
    local proxy_inv = proxy.get_inventory(defines.inventory.character_main)
    local spider_stack, _ = proxy_inv.find_item_stack(spider_name)
    
    if not wagon.can_insert(spider_stack) then
        log("Cant insert spider from proxy!!!!")
        game.print("Something went very wrong during attemt to collect spider, spider wagon inventory was supposed to be empty, but it wasnt! Please report to mod author")
        self:spawnSpidertron(spider_stack)
        proxy.destroy()
        return false
    end
    wagon_inventory.insert(spider_stack)
    proxy_inv.remove(spider_stack)
    local resources_left = proxy_inv.get_contents()
    local train = self.ECU.train
    for item, count in pairs(resources_left) do
        train.insert({name=item, count=count})
    end
    proxy.destroy()
    return true
end

function SpiderCarrier:checkIfSpiderStored()
    return self:getSpiderStack() and true or false
end

function SpiderCarrier:getSpiderPathStartPosition()
    local spider = self.spider
    local start_area = {
        left_top={
            x=spider.position.x-6,
            y=spider.position.y-6
        },
        right_bottom={
            x=spider.position.x+6,
            y=spider.position.y+6
        }
    }
    return pathfinder.find_non_colliding_spot(spider.surface, start_area)
end

function SpiderCarrier:callback(path, pathing_request_info)
    if pathing_request_info.action == constants.spider_carrier_navigate_subtask_action then
        if path then
            local ticks_took = game.tick - self.navigation_start_tick

            log("Path found! Pathing took " .. ticks_took .. " ticks, or " .. ticks_took/60 .. 'seconds' )
            local goal = pathing_request_info.goal
            local bb = getTileBoundingBox(goal)
            hightligtBoundingBox(bb, {r=0, g=1, b=0})
            for i=1,#self.goal_candidates do
                self.goal_candidates[i] = nil
            end
            self.ECU:subtaskProcessingCallback(true)
            pathfinder.set_autopilot(self.spider, path)
        else
            local candidate_index = pathing_request_info.candidate_index
            log("Path not found for path n0 " .. candidate_index)
            local next_candidate = self.goal_candidates[candidate_index + 1]
            if next_candidate then
                log("Trying next candidate")
                local goal = next_candidate.goal
                local bb = getTileBoundingBox(goal)
                hightligtBoundingBox(bb, {r=0, g=1, b=0}, 3)
                pathfinder.request_path(next_candidate)
            else
                log("All canidates tried, no path found!")
                self.ECU:subtaskProcessingCallback(false)
            end
        end
        return
    end
    if pathing_request_info.action == constants.spider_carrier_collect_spider_action then
        if path then
            local spider = self.spider
            log("PATH BACK TO TRAIN FOUND")
            pathfinder.set_autopilot(spider, path)
        else
            log("Path back to train was not found :(")
        end
        return
    end
end

function SpiderCarrier:navigateSpiderToSubtask(subtask)

    self.navigation_start_tick = game.tick
    local spider = self.spider
    local surface = spider.surface
    local start = self:getSpiderPathStartPosition()
    if not start then
        log('Start was not found')
        --self.ECU:subtaskProcessingCallback(false)
        return
    end
    local bounding_box = subtask.bounding_box
    hightligtBoundingBox(bounding_box, {r=0, g=1, b=0})
    local possible_building_spots = pathfinder.find_route_point_candidates(surface, bounding_box)
    local spots_n = #possible_building_spots
    if spots_n > 0 then
        log("Found " .. #possible_building_spots .. " goal candidates")
    else
        log("No goal candidates found")
        self.ECU:subtaskProcessingCallback(false)
        return
    end

    for i=1,#self.goal_candidates do
        self.goal_candidates[i] = nil
    end
    local goal_candidates = self.goal_candidates
    local pathing_request_info
    local middle_index = math.ceil(spots_n/2)
    log('middle_index ' .. middle_index)
    for i=1, spots_n do
        local increment = math.ceil(i/2) - 1
        local sign = (-1)^(i-1)
        local spot_index = middle_index + increment*sign
        local spot = possible_building_spots[spot_index]
        pathing_request_info = {
            action=constants.spider_carrier_navigate_subtask_action,
            unit=spider,
            --start={start.position.x + 0.5, start.position.y + 0.5}, -- because tile position is its left_top corner
            start=start,
            goal=spot.position,
            attempt=1,
            candidate_index = i,
            callback_source=self,
            auto_retry=true,
        }
        goal_candidates[i] = pathing_request_info
    end

    --start pathing feedback loop
    pathfinder.request_path(goal_candidates[1])
end
