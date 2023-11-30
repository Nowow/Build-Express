require("lib.utils")

local constants = require("constants")
local ECUQueue = require("lib.concepts.ECU_queue")


function initFleetRegister(surface)
    if not global.fleet_register then
        global.fleet_register = {}

        global.fleet_register[constants.ct_construction_wagon_name] = {}
        global.fleet_register[constants.spider_carrier_prototype_name] = {}
        global.fleet_register.trains_in_action = {}
        global.fleet_register.ECU_handling_queue = ECUQueue:create()
        FleetRegister.reregisterAllWagons()
	end
    
end


FleetRegister = {}

FleetRegister.registerNewDrone = function (wagon)
    log("registerNewDrone got called")
    if not wagon.valid then
        error("Wagon could not be registred because it it not .valid")
        return false
    end

    local wagon_type = wagon.name
    log("Wagon type is " .. wagon_type)
    if global.fleet_register[wagon_type] == nil then
        error("Wagon of type " .. wagon_type .. " cant be registred")
        return
    end

    global.fleet_register[wagon_type][wagon.unit_number] = wagon
    script.register_on_entity_destroyed(wagon)
end


FleetRegister.getFreeDronesSortedByDistance = function (task_coords, drone_type)
    log("getFreeDronesSortedByDistance got called for type " .. drone_type)
    local drone_fleet = global.fleet_register[drone_type]
    local trains_in_action = global.fleet_register.trains_in_action
    local distances = {}
    local sorter = {}
    local result = {}

    local drone_pos, drone_train, drone_train_id, locomotives, distance

    for unit_number, wagon in pairs(drone_fleet) do
        log("Checking wagon " .. unit_number .."...")
        if wagon.valid then
            log("Wagon " .. unit_number .." is valid")
            drone_train = wagon.train
            if drone_train ~= nil then
                drone_train_id = drone_train.id
                log("Wagon " .. unit_number .." has a train! Train number: " .. drone_train_id)
                if trains_in_action[drone_train_id] == nil then
                    log("Train " .. drone_train_id .. " is not busy!")
                    locomotives = drone_train.locomotives
                    if next(locomotives) ~= nil then
                        log("Train " .. drone_train_id .." train has locomotives! Calculating distance...")
                        drone_pos = wagon.position
                        distance = DistanceBetweenTwoPoints(drone_pos, task_coords)
                        log("Wagon " .. unit_number .." is " .. distance .. " units away from task!")
                        distances[distance] = {train=drone_train, wagon=wagon}
                        table.insert(sorter, distance)
                    end
                end
            end
        end
    end
    if next(distances) == nil then
        log("No eligible trains were found")
        return {}
    end

    table.sort(sorter)

    for _, distance in pairs(sorter) do
        table.insert(result, distances[distance])
    end
    return result
    
end

FleetRegister.registerTrainAsInAction = function (train, wagon, task)
    
    local train_id = train.id
    log("Registring train " .. train_id .. " as in action for task " .. task.id)
    global.fleet_register.trains_in_action[train_id] = {train=train, wagon=wagon, task=task}
end

FleetRegister.unregisterTrainAsInAction = function (train_id)
    global.fleet_register.trains_in_action[train_id] = nil
end

script.on_event(defines.events.on_entity_destroyed, function(event)
    local unit_number = event.unit_number
    global.fleet_register[constants.ct_construction_wagon_name][unit_number] = nil
    global.fleet_register[constants.spider_carrier_prototype_name][unit_number] = nil
end)

function FleetRegister.reregisterAllWagons()
    global.fleet_register.trains_in_action = {}
    for _, surface in pairs(game.surfaces) do
        game.print(surface.name)
        local wagons = surface.find_entities_filtered{
            name= {constants.spider_carrier_prototype_name, constants.ct_construction_wagon_name}
        }
        game.print("Found " .. #wagons .. " wagons to register!")
        for __, wagon in pairs(wagons) do
            FleetRegister.registerNewDrone(wagon)
        end
    end
end


function FleetRegister.ECUfinishedTask(ECU)
    log("ECUfinishedTask got called...")
    if not ECU then
        log("But no ECU provided, UB")
        return
    end
    local train = ECU.train
    if not train or not train.valid then
        log("There is no train in ECU to handle, aborting")
        return
    end
    
    -- issuing initial order to retract spider
    local retract_order = ECU:orderRetractSpider()
    if retract_order then
        log("Successfully ordered to retract spider, waiting...")
        global.fleet_register.ECU_handling_queue:push(ECU)
        return
    else
        log("Spider will not be retracted because it does not exist, ordering goHome")
        ECU:goHome()
        FleetRegister.unregisterTrainAsInAction(train)
        return
    end
    
end


script.on_event(defines.events.on_train_created, function(event)

    --- SOOOO MESSYYY

    local train = event.train
    local old_1 = event.old_train_id_1
    local old_2 = event.old_train_id_2

    local old_record_1, old_record_2, carriages, wagon, task
    local lookup_old_1, lookup_old_2

    if old_1 ~= nil then
        lookup_old_1 = global.fleet_register.ECU_handling_queue:lookup(old_1)
        old_record_1 = global.fleet_register.trains_in_action[old_1]
        if old_record_1 ~= nil then
            log("Old train 1 had an active train record, unregistring")
            FleetRegister.unregisterTrainAsInAction(old_1)
        end
    end

    if old_2 ~= nil then
        lookup_old_2 = global.fleet_register.ECU_handling_queue:lookup(old_2)
        old_record_2 = global.fleet_register.trains_in_action[old_2]
        if old_record_2 ~= nil then
            log("Old train 2 had an active train record, unregistring")
            FleetRegister.unregisterTrainAsInAction(old_2)
        end
    end
    



    if old_record_2 ~= nil then
        log("Old train 2 had an active train record")
        task = old_record_2.task
        wagon = old_record_2.wagon
        carriages = train.carriages
        for _, carriage in pairs(carriages) do
            if carriage.unit_number == wagon.unit_number then
                log("Found the wagon from old train 2!")

                -- regular tasks unregister workers in termination, this check is for ECUs that have not finished handling
                if task.state ~= constants.TASK_STATES.TERMINATING then
                    task:callbackWhenTrainCreated(train)
                    
                else
                    log("Not calling task callback because it is in TERMINATING state")
                end
                -- registring anyway, because old_2 was registred, "callback" hotswap comes later
                FleetRegister.registerTrainAsInAction(train, wagon, task)
                -- instead of return
                old_record_1 = nil
            end
        end
    end



    if old_record_1 ~= nil then
        log("Old train 1 had an active train record")
        task = old_record_1.task
        wagon = old_record_1.wagon
        carriages = train.carriages
        for _, carriage in pairs(carriages) do
            if carriage.unit_number == wagon.unit_number then
                log("Found the wagon in old train 1!")

                -- regular tasks unregister workers in termination, this check is for ECUs that have not finished handling
                if task.state ~= constants.TASK_STATES.TERMINATING then
                    task:callbackWhenTrainCreated(train)
                    
                else
                    log("Not calling task callback because it is in TERMINATING state")
                end
                -- registring anyway, because old_2 was registred, "callback" hotswap comes later
                FleetRegister.registerTrainAsInAction(train, wagon, task)
            end
        end
    end

    
    if lookup_old_2 then
        -- hot swap
        local index = global.fleet_register.ECU_handling_queue.train_id_index[old_2]
        global.fleet_register.ECU_handling_queue.train_id_index[old_2] = nil
        lookup_old_2:setTrain(train)
        global.fleet_register.ECU_handling_queue.train_id_index[train.id] = index
        lookup_old_1 = nil
    end

    if lookup_old_1 then
        -- hot swap
        local index = global.fleet_register.ECU_handling_queue.train_id_index[old_1]
        global.fleet_register.ECU_handling_queue.train_id_index[old_1] = nil
        lookup_old_1:setTrain(train)
        global.fleet_register.ECU_handling_queue.train_id_index[train.id] = index
    end

end)


script.on_nth_tick(61, function(event)
    if next(global.fleet_register.ECU_handling_queue.data) == nil then
        return
    end

    log("Fleet Manager processes something")
    local ECU = global.fleet_register.ECU_handling_queue:pop()
    if not ECU then
        error("Something has gone horribly wrong with ECU_handling_queue, pop() produced null instead of ECU")
    end

    local train = ECU.train

    if not train.valid then
        log("This ECU train is no valid train, aborting")
        return
    end

    log("All good, Fleet Manager processes train " .. train.id)
    local ECU_status = ECU.status

    if ECU_status == constants.ECU_STATUS.RETRACTING_SPIDER then
        local spider_is_back = ECU:pollRetractSpider()
        if not spider_is_back then
            log("Spider not back yet")
            global.fleet_register.ECU_handling_queue:push(ECU)
            return
        else
            log("Spider is back, sending ECU back home!")
            ECU:goHome()
            global.fleet_register.ECU_handling_queue:push(ECU)
            -- unregistring here, so while train is going home it can be assigned to another task
            FleetRegister.unregisterTrainAsInAction(train.id)
            return
        end
        
    elseif ECU_status == constants.ECU_STATUS.GOING_HOME then
        local is_train_again_in_action = global.fleet_register.trains_in_action[train.id]
        if is_train_again_in_action then
            log("Train " .. train.id .. " has been asssigned to some new task, stopping handling")
            return
        end
        local is_home = ECU:checkIfBackHome()
        if is_home then
            ECU:deploy()
            log("Fleet manager finished handling of train " .. train.id)
            return
        else
            log("Train " .. train.id .. " is not home yet")
            global.fleet_register.ECU_handling_queue:push(ECU)
            return
        end
    end

end)

return FleetRegister

