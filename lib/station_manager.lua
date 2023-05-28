
function initWorkerStationRegister()
    if not global.worker_register then
		global.worker_register = {
            -- to have an index of trains that are taking part in tasks, because if you add or remove a carriage train ceases to exist and has to be replaced
            trains_in_action = {}, 
            -- to register modded stations so dont have to scan surface every time you need a worker
            stations = {}
        }
	end
end

function registerWorkerStation(station)
    if not station.valid then return end
    log("register station called")
    local unit_number = station.unit_number
    if global.worker_register.stations[unit_number] == nil then
        global.worker_register.stations[unit_number] = {
            entity=station, locked=false
        }
    end
end

function iterateStations()
    local i
    local prev_i
    local station_entry
    local station
    local n = table_size(global.worker_register.stations)
    log("Going to iterate over station registry, station count before invalidation: " .. n)
    local iter_f
    iter_f = function ()
        prev_i = i
        i, station_entry = next(global.worker_register.stations, i)
        if not i then return end
        station = station_entry.entity
        if not station.valid then
            log("Removed invalid station from worker register")
            global.worker_register.stations[i] = nil
            i = prev_i
            return iter_f()
        else
            return station
        end
    end
    return iter_f
end

function unlockStation(station)
    log("Unlocking station")
    local unit_number = station.unit_number
    local station_entry = global.worker_register.stations[unit_number]
    if station_entry == nil then
        log("Cant lock, station is not in register")
        return
    elseif not station_entry.locked then
        station_entry.locked = true
    else
        log("Cant lock, station alread locked")
    end
end

function registerTrainAsInAction(train, callback_source)
    local id = train.id
    if global.worker_register.trains_in_action[id] ~= nil then
        log("Trying to reregister train " .. id)
        return
    else
        global.worker_register.trains_in_action[id] = {train=train, callback_source=callback_source}
    end
end

function unregisterTrainAsInAction(train_id)
    global.worker_register.trains_in_action[train_id] = nil
end

function trainCreatedCallback(old_train_id, new_train)
    local train_entry = global.worker_register.trains_in_action[old_train_id]
    if train_entry then
        log("Train that was created into new train was in train registry, calling callback")
        local callback_source = train_entry.callback_source
        callback_source:callbackWhenTrainCreated(old_train_id, new_train)
    end
end

script.on_event(defines.events.on_train_created, function(event)

    local train = event.train
    local old_1 = event.old_train_id_1
    local old_2 = event.old_train_id_2
    if old_1 then
        trainCreatedCallback(old_1, train)
    end
    if old_2 then
        trainCreatedCallback(old_2, train)    
    end
    
end)