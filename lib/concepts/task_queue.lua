TaskQueue = {}
TaskQueue.__index = TaskQueue

script.register_metatable("queue_metatable", TaskQueue)

function TaskQueue:create(name)
    local queue = {}
    queue.name = name
    queue.head_tail = {first = 1, last = 0}
    queue.data = {}
    queue.task_id_index = {}
    setmetatable(queue, TaskQueue)
    return queue
end

function TaskQueue:push(task)
    -- log(string.format("TASK_ID %-12s", task.id .. ':') .. 'task pushed in queue ' .. self.name)
    -- log(string.format("TASK_ID %-12s", task.id .. ':') .. 'the queue now has ' .. table_size(self.data) .. ' items')
    local last = self.head_tail.last + 1
    self.head_tail.last = last
    self.data[last] = task
    self.task_id_index[task.id] = last
end

function TaskQueue:pop()
    
    local first = self.head_tail.first
    if first > self.head_tail.last then error("list is empty") end
    local task = self.data[first]
    self.data[first] = nil
    self.task_id_index[task.id] = nil
    self.head_tail.first = first + 1
    -- log(string.format("TASK_ID %-12s", task.id .. ':') .. 'task popped from queue ' .. self.name)
    -- log(string.format("TASK_ID %-12s", task.id .. ':') .. 'the queue now has ' .. table_size(self.data) .. ' items')
    return task
end

function TaskQueue:remove(task_id)

    -- checking if task in queue
    local task_queue_index = self.task_id_index[task_id]
    if task_queue_index == nil then
        return false
    end
    
    -- removing task from queue and 
    self.data[task_queue_index] = nil
    local last = self.head_tail.last

    -- reindexing everything was further from release from queue than provided task
    -- to remove a gap, task.remove does not work due to data not being a list indexing from 1 to n
    if task_queue_index < last then
        for i = task_queue_index + 1, last do
            self.data[i - 1] = self.data[i]
        end
    end
    self.head_tail.last = last - 1
    -- log(string.format("TASK_ID %-12s", task_id .. ':') .. 'task removed from queue ' .. self.name)
    -- log(string.format("TASK_ID %-12s", task_id .. ':') .. 'the queue now has ' .. table_size(self.data) .. ' items')
    return true
    
end

function TaskQueue:lookup(task_id)
    -- log(string.format("TASK_ID %-12s", task_id .. ':') .. 'task looked up in queue ' .. self.name)
    return self.data[self.task_id_index[task_id]]
end

function TaskQueue:cycle()
    local task = self:pop()
    self:push(task)
    return task
end


-- create and use an Account
-- acc = Account:create(1000)
-- acc:withdraw(100)