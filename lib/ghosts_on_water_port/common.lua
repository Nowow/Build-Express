local constants = require('constants')


getOriginalEntityName = function(dummyEntityName)
    --get the original entity name from the dummy entity name
    local originalEntityName = string.sub(dummyEntityName, string.len(constants.dummyPrefix) + 1)
    return originalEntityName
end