local constants = require('constants')
local prefix_len = string.len(constants.dummyPrefix)

function getOriginalEntityName(dummyEntityName)
    --get the original entity name from the dummy entity name
    if string.sub(dummyEntityName, 1, prefix_len)==constants.dummyPrefix then
        return string.sub(dummyEntityName, string.len(constants.dummyPrefix) + 1)
    end
    return dummyEntityName
end

function dummyEntityPrototypeExists(entityName)
    --check if the dummy entity prototype exists
    -- local dummyEntityPrototype = global.GhostOnWater.WaterGhostNames[constants.dummyPrefix .. entityName]
    -- return dummyEntityPrototype ~= nil

    local dummyEntityPrototype = game.entity_prototypes[constants.dummyPrefix .. entityName]
    return dummyEntityPrototype ~= nil
end

--function that check if the original entity could be placed in the location of the dummy entity
function canPlaceOriginalEntity(originalEntityName, dummyEntity)
    --check if the original entity can be placed in the location and with the same direction of the dummy entity
    local surface = dummyEntity.surface    
    local position = dummyEntity.position
    local direction = dummyEntity.direction
    --check if the original entity can be placed
    if dummyEntity.ghost_type == "offshore-pump" then
        --offshore pump is a special case because it can be placed on water so we use a diffrent build_check_type
        --check if the original entity can be placed on water
        return surface.can_fast_replace { name = originalEntityName, position = position, direction = direction, force = dummyEntity.force }
    end
    return surface.can_place_entity { name = originalEntityName, position = position, direction = direction, build_check_type=defines.build_check_type.manual }
end

--function that replaces all dummy entity ghosts with the original entity ghosts
--use orderUpgrade to upgrade the dummy entity ghosts to the original entity ghosts
function replaceDummyEntityGhost(dummyEntity)
    --get the original entity name from the dummy entity name
    -- local originalEntityName = getOriginalEntityName(dummyEntity.ghost_name)
    local originalEntityName = global.dummy_names_index[dummyEntity.ghost_name] or dummyEntity.ghost_name
    --check if the original entity can be placed in the location and with the same direction of the dummy entity
    if canPlaceOriginalEntity(originalEntityName, dummyEntity) then
        --order upgrade (force, target)
        dummyEntity.order_upgrade({force = dummyEntity.force, target = originalEntityName})
        return true
    end
    return false
end

function fillWaterGhostTypes()
    if global.dummy_names_index == nil then
        global.dummy_names_index = {}
    end
    local prefix_len = string.len(constants.dummyPrefix)
    local original_name
    local cntr = 0
    for name, _ in pairs(game.entity_prototypes) do
        if string.sub(name, 1, prefix_len)==constants.dummyPrefix then
            original_name = string.sub(name, prefix_len + 1)
            global.dummy_names_index[name] = original_name
            cntr = cntr + 1
        end
    end
    log("Filled " .. cntr .. " dummy names")
end