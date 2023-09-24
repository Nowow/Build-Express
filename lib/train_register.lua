local constants = require("constants")

function initTrainRegister()
    if not global.train_register then
		global.train_register = {
            locomotives={},
            free={},
            busy={}
        }
	end
end

TrainRegister = {}

TrainRegister.checkIfTrainInRegister = function (train_id)
    return global.train_register.free[train_id] ~= nil or global.train_register.busy[train_id] ~= nil
end

TrainRegister.registerTrain = function (train)
    local train_id = train.id
    log("Train Register registers train " .. train_id)
    global.train_register.free[train_id] = train
end

TrainRegister.removeTrainFromRegister = function (train_id)
    log("Train Register removed train from register without any callbacks " .. train_id)
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
    
    if train then
        TrainRegister.registerTrain(train)    
    end
    
    local old_train_1_busy_record = global.train_register.busy[old_train_id_1]
    local old_train_2_busy_record = global.train_register.busy[old_train_id_2]
    TrainRegister.removeTrainFromRegister(old_train_id_1)
    TrainRegister.removeTrainFromRegister(old_train_id_2)

    if old_train_1_busy_record then
        -- if first old train was busy on task, disregard second old train 
        -- because in case you merged two busy Build Express trains one of respective tasks should be terminated
        -- so probably dont do that
        log("Old train 1 was busy")
        TrainRegister.lockTrain(train.id)
        old_train_1_busy_record.callback:trainRegisterCallback(train)

        -- if it is indeed that case, terminating task that was utilizing second old train
        if old_train_2_busy_record then
            log("Terminating task that was utilizing second old train")
            old_train_2_busy_record.callback:trainRegisterCallback(nil)
        end
        return
    end

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

    local front_stock_buex = train.front_stock.prototype.name == constants.buex_locomotive
    if front_stock_buex then
        log("A new Build Express train got created with id " .. train.id)
        TrainRegister.updateRegister(train, old_1, old_2)
        return
    end

    local old_trains_in_register = TrainRegister.checkIfTrainInRegister(old_1) or TrainRegister.checkIfTrainInRegister(old_2)
    local buex_in_train = false
    for _, stock in pairs(train.locomotives) do
        if stock.prototype.name == constants.buex_locomotive then
            buex_in_train = true
            break
        end
    end
    
    
    if old_trains_in_register and then
        log("A new train created that is not Build Express train, but one of the old ones was")
        TrainRegister.updateRegister(nil, old_1, old_2)
    end

end)