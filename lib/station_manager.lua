
function initWorkerStationRegister()
    if not global.worker_station_register then
		global.worker_station_register = {}
	end
end

function registerWorkerStation(station)
    if global.worker_station_register[station.backer_name] == nil then
        global.worker_station_register[station.backer_name] = {}
    end
    global.worker_station_register[station.backer_name][station.unit_number] = station    
end

function unregisterWorkerStation(old_name, station)
    global.worker_station_register[old_name][station.unit_number] = nil
    
    if table_size(global.worker_station_register[old_name]) == 0 then
        global.worker_station_register[old_name] = nil
    end
end

function getWorker(blueprint_label)
    if global.worker_station_register[blueprint_label] == nil then
        return nil
    end
    for i, station in pairs(global.worker_station_register[blueprint_label]) do
        local worker = station.get_stopped_train()
        if worker ~= nil then
            return worker
        end
    end
end