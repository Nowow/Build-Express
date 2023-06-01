---@class EntitiyQueue
---@field head_tail table
---@field data table
local EntitiyQueue = {}
EntitiyQueue.__index = EntitiyQueue

script.register_metatable("entity_queue_metatable", EntitiyQueue)

---@return EntitiyQueue
function EntitiyQueue:create()
    
    local queue = {}
    queue.head_tail = {first = 1, last = 0}
    queue.data = {}
    setmetatable(queue, EntitiyQueue)
    return queue
end

function EntitiyQueue:push(entity)
    local last = self.head_tail.last + 1
    self.head_tail.last = last
    self.data[last] = entity
end

function EntitiyQueue:pop()
    
    local first = self.head_tail.first
    if first > self.head_tail.last then return nil end
    local entity = self.data[first]
    self.data[first] = nil
    self.head_tail.first = first + 1
    return entity
end


return EntitiyQueue