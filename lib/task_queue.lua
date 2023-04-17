TaskQueue = {}
TaskQueue.__index = TaskQueue

script.register_metatable("queue_metatable", TaskQueue)

script.on_load(function()
	script.register_metatable("queue_metatable", TaskQueue)
end)


function TaskQueue:create()
    local queue = {}
    queue.idx = {first = 1, last = 0}
    queue.data = {}
    setmetatable(queue, TaskQueue)
    return queue
end

function TaskQueue:push(value)
    local last = self.idx.last + 1
    self.idx.last = last
    self.data[last] = value
end

function TaskQueue:pop()
    local first = self.idx.first
    if first > self.idx.last then error("list is empty") end
    local value = self.data[first]
    self.data[first] = nil        -- to allow garbage collection
    self.idx.first = first + 1
    return value
end

function TaskQueue:remove_task(task_id)
    for i, task in pairs(self.data) do
        if task.id == task_id then
            table.remove(self.data, i)
            local last = self.idx.last
            self.idx.last = last - 1
            return true
        end
    end
    return false
end

function TaskQueue:get_task(task_id)
    for _, task in pairs(self.data) do
        if task.id == task_id then
            return task
        end
    end
    return nil
end

function TaskQueue:get_oldest_task()
    local task = self:pop()
    self:push(task)
    return task
end


-- create and use an Account
-- acc = Account:create(1000)
-- acc:withdraw(100)