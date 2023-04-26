local constants = require('constants')


getOriginalEntityName = function(dummyEntityName)
    --get the original entity name from the dummy entity name
    local originalEntityName = string.sub(dummyEntityName, string.len(constants.dummyPrefix) + 1)
    return originalEntityName
end


dummyEntityPrototypeExists = function(entityName)
    --check if the dummy entity prototype exists
    -- local dummyEntityPrototype = global.GhostOnWater.WaterGhostNames[constants.dummyPrefix .. entityName]
    -- return dummyEntityPrototype ~= nil

    local dummyEntityPrototype = game.entity_prototypes[constants.dummyPrefix .. entityName]
    return dummyEntityPrototype ~= nil
end