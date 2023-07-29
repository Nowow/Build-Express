local constants = require("constants")

function initTrainRegister(surface)
    if not global.train_register then
		global.train_register = {
            free={},
            busy={}
        }
	end
end

TrainRegister = {}

TrainRegister.registerTrain = function (train)
    local train_id = train.id
    log("Train Register registers train " .. train_id)
    global.train_register.free[train_id] = train
end

TrainRegister.unregisterTrain = function (train)
    local train_id = train.id
    log("Train Register unregisters train " .. train_id)
    global.train_register.free[train_id] = nil
    global.train_register.free[train_id] = nil
end

TrainRegister.getNextFreeTrain = function ()
    local _, next_train = next(global.train_register.free)
    if next_train == nil then
        log("Free construnction train requested, but there was none")
        return nil
    end
    return next_train
end

TrainRegister.lockTrain = function (train_id)
    log("Train Register ordered to lock train " .. train_id)
    local train = global.train_register.free[train_id]
    if train == nil then
        log("But it is not found amongst free!")
        return false
    end
    log("Locking!")
    global.train_register.free[train_id] = nil
    global.train_register.busy[train_id] = train
    return true
end

TrainRegister.unlockTrain = function (train_id)
    log("Train Register ordered to unlock train " .. train_id)
    local train = global.train_register.busy[train_id]
    if train == nil then
        log("But it is not found amongst busy!")
        return false
    end
    log("Unlocking!")
    global.train_register.busy[train_id] = nil
    global.train_register.free[train_id] = train
    return true
end