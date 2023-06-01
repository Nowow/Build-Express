require("lib.ghosts_on_water_port.common")
local EntitiyQueue = require("lib.concepts.entity_queue")

function initWaterGhostReplacerQueue()
    -- if global.water_ghosts == nil then
        global.water_ghosts = EntitiyQueue:create()
    -- end

    fillWaterGhostTypes()
    
end

script.on_nth_tick(2, function(event)
    if next(global.water_ghosts.data) == nil then
        return
    end
    
    local replace_rate = settings.global["water-ghost-replace-rate"].value
    local dummy

    for i=1, replace_rate do
        dummy = global.water_ghosts:pop()
        if dummy == nil then return end
        if dummy.valid then
            local replaced = replaceDummyEntityGhost(dummy)
            if not replaced then
                global.water_ghosts:push(dummy)
            end
        end
    end

end)