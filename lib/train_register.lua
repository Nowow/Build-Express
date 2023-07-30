local constants = require("constants")

function initTrainRegister()
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

TrainRegister.unregisterTrain = function (train_id)
    log("Train Register unregisters train " .. train_id)
    global.train_register.free[train_id] = nil

    local busy_record = global.train_register.busy[train_id]
    if busy_record ~= nil then
        log("Train " .. train_id .. " was found in busy register, calling empty callback to terminate task")
        busy_record.callback:trainRegisterCallback(nil)
    end
    
end

TrainRegister.getNextFreeTrain = function ()
    local _, next_train = next(global.train_register.free)
    if next_train == nil then
        log("Free construnction train requested, but there was none")
        return nil
    end
    return next_train
end

TrainRegister.lockTrain = function (train_id, callback)
    log("Train Register ordered to lock train " .. train_id)
    local train = global.train_register.free[train_id]
    if train == nil then
        log("But it is not found amongst free!")
        return false
    end
    log("Locking!")
    global.train_register.free[train_id] = nil
    global.train_register.busy[train_id] = {train=train, callback=callback}
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

TrainRegister.updateRegister = function (train, old_train_id_1, old_train_id_2)
    
    log("Brand new Build Express construnction train was registred")
    TrainRegister.registerTrain(train)

    local old_train_1_busy_record = global.train_register.busy[old_train_id_1]
    if old_train_1_busy_record then
        log("Old train 1 was busy")
        local callback = old_train_1_busy_record.callback
        TrainRegister.lockTrain(train.id)
        callback:trainRegisterCallback(train)
        return
    end

    local old_train_2_busy_record = global.train_register.busy[old_train_id_2]
    if old_train_2_busy_record then
        log("Old train 2 was busy")
        local callback = old_train_2_busy_record.callback
        TrainRegister.lockTrain(train.id)
        callback:trainRegisterCallback(train)
        return
    end

end


script.on_event(defines.events.on_train_created, function(event)

    local train = event.train
    local old_1 = event.old_train_id_1
    local old_2 = event.old_train_id_2

    local front_stock = train.front_stock
    if not front_stock.prototype.name == constants.buex_locomotive then
        return
    end

    log("A new Build Express train got created")
    TrainRegister.updateRegister(train, old_1, old_2)

    
end)