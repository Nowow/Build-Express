
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
    log(table_size(global.worker_register.stations))
    local unit_number = station.unit_number
    if global.worker_register.stations[unit_number] == nil then
        global.worker_register.stations[unit_number] = {
            entity=station
        }
    end
    log(table_size(global.worker_register.stations))
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

function registerTrainAsInAction(train, callback_source)
    local id = train.id
    if global.worker_register.trains_in_action[id] ~= nil then
        return
    else
        global.worker_register.trains_in_action[id] = {train=train, callback_source=callback_source}
    end
end

function unregisterTrainAsInAction(train)
    local id = train.id
    if global.worker_register.trains_in_action[id] == nil then
        return
    else
        global.worker_register.trains_in_action[id] = ni
    end
end

function trainCreatedCallback(old_train_id, new_train)
    local train_entry = global.worker_register.trains_in_action[old_train_id]
    if train_entry then
        log("Train that was created into new train was in train registry, calling callback")
        local callback_source = train_entry.callback_source
        global.worker_register.trains_in_action[old_train_id] = nil
        global.worker_register.trains_in_action[new_train.id] = {train=new_train, callback_source=callback_source}
        callback_source:callbackWhenTrainCreated(new_train)
        
    end
end