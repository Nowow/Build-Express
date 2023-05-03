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
    if not spider_stack.prototype.place_result.type == 'spider-vehicle' then
        log("Cant release spider because item inside is not spider!!!")
        return
    end
    
    local spider = self:spawnSpidertron(spider_stack)
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
    local proxy = self:spawnProxy()

    if not proxy.can_reach_entity(spider) then
        log("Spider is out of reach")
        return false
    end
    
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

function SpiderCarrier:getSpiderPathStartPosition()
    local spider = self.spider
    local start_area = {
        left_top={
            x=spider.position.x-3,
            y=spider.position.y-3
        },
        right_bottom={
            x=spider.position.x+3,
            y=spider.position.y+3
        }
    }
    return pathfinder.find_non_colliding_spot(spider.surface, start_area)
end

function SpiderCarrier:callback(path, pathing_request_info)
    if pathing_request_info.action == constants.spider_carrier_navigate_subtask then
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
            log(#self.goal_candidates)
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
                self.ECU:subtaskProcessingCallback(true)
            end
        end
        return
    end
    if pathing_request_info.action == constants.spider_carrier_collect_spider then
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
            action=constants.spider_carrier_navigate_subtask,
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

function SpiderCarrier:startCollectSpidertron()
    log("Trying to collect spider")
    local spider = self.spider
    local wagon = self.wagon
    if not spider.valid then
        log("Spider is not valid!")
    end
    if not wagon.valid then
        log("Wagon is not valid!")
    end
    local start = self:getSpiderPathStartPosition()
    local goal = wagon.position

    local pathing_request_info = {
        unit=spider,
        start=start,
        goal=goal,
        attempt=1,
        callback_source=self,
        auto_retry=true,
    }
    pathfinder.request_path(pathing_request_info)
end
