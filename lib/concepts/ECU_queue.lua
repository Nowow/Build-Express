---@class ECUQueue
---@field head_tail table
---@field data table
---@field train_id_index table
local ECUQueue = {}
ECUQueue.__index = ECUQueue

script.register_metatable("ECU_queue_metatable", ECUQueue)

---@return ECUQueue
function ECUQueue:create()
    
    local queue = {}
    queue.head_tail = {first = 1, last = 0}
    queue.data = {}
    queue.train_id_index = {}
    setmetatable(queue, ECUQueue)
    return queue
end

function ECUQueue:push(ECU)
    local last = self.head_tail.last + 1
    self.head_tail.last = last
    self.data[last] = ECU
    local id = ECU.id
    if not id then
        error("ECU with no set train made its way into ECUQueue, UB")
    end
    self.train_id_index[id] = last
end

function ECUQueue:pop()
    
    local first = self.head_tail.first
    if first > self.head_tail.last then return nil end
    local ECU = self.data[first]
    self.data[first] = nil
    self.train_id_index[ECU.id] = nil
    self.head_tail.first = first + 1
    return ECU
end

function ECUQueue:lookup(train_id)
    -- log(string.format("TASK_ID %-12s", task_id .. ':') .. 'task looked up in queue ' .. self.name)
    return self.data[self.train_id_index[train_id]]
end


return ECUQueue