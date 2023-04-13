require("lib.utils")

TRAIN_STATES = {
    'on_the_path',
    'path_lost',
    'no_schedule',
    'no_path',
    'arrive_signal',
    'wait_signal',
    'arrive_station',
    'wait_station',
    'manual_control_stop',
    'manual_control',
    'destination_full'
}


function getWorker(blueprint_name)
    if blueprint_name ~= nil then
        local i, station = next(global.worker_station_register[blueprint_name])
        if station and station.valid then
            table.remove(global.train_register.available, i)
            local train = station.get_stopped_train()
            if train ~= nil then
                game.print("TRAIN IS NOT NIL")
                local control = station.get_control_behavior()
                if control and control.valid and not control.disabled then
                    game.print("STATION ENABLED")
                    return train
                end
            end
            
        else
            return nil
        end
    end
end 


function registerTrain(train)
    global.train_register.available[train.id] = train
end

function getFreeTrain()
    local i, train = next(global.train_register.available)
    if train then
        table.remove(global.train_register.available, i)
        global.train_register.busy[train.id] = train
        return train
    else
        return nil
    end
end

function releaseTrain(train)
    global.train_register.busy[train.id] = nil
    global.train_register.available[train.id] = train
end

function checkIfRailIsInSameRailroad(rail)
    local rail_gps_text = "at [gps=" .. rail.position.x .. "," .. rail.position.y .. ']'
    for _, train in pairs(global.registred_trains) do
        
        local rail_under_train = train.front_rail
        local rail_under_train_gps_text = "at [gps=" .. rail_under_train.position.x .. "," .. rail_under_train.position.y .. ']'

        if rail.is_rail_in_same_rail_segment_as(rail_under_train) then
            game.print('Rail ' .. rail_gps_text .. ' is in the same segment as train ' .. train.id .. rail_under_train_gps_text)
        else
            game.print('Rail ' .. rail_gps_text .. ' is NOT the same segment as train ' .. train.id .. rail_under_train_gps_text)
        end

        if rail.is_rail_in_same_rail_block_as(rail_under_train) then
            game.print('Rail ' .. rail_gps_text .. ' is in the same block as train ' .. train.id .. rail_under_train_gps_text)
        else
            game.print('Rail ' .. rail_gps_text .. ' is NOT the same block as train ' .. train.id .. rail_under_train_gps_text)
        end
        
    end
end


function makeTrainGoToRail(rail, train)
    schedule_entry = {
        rail=rail,
        wait_conditions={
            {
                type='time',
                ticks=36000,
                compare_type='and'
            }
        }
    }
    new_schedule = train.schedule
    new_schedule.records = {new_schedule.records[1], schedule_entry}
    new_schedule.current = 2  -- may be bugs

    train.schedule = new_schedule
end

function makeTrainGoToDepot(train)
    new_schedule = train.schedule
    table.remove(new_schedule.records, 2)
    new_schedule.current = 1
    train.schedule = new_schedule
end

function makeRegistredTrainsGoToRail(rail)
    local rail_gps_text = " at [gps=" .. rail.position.x .. "," .. rail.position.y .. ']'
    for _, train in pairs(global.registred_trains) do
        
        local front_loco = train.front_stock
        local front_loco_gps_text = "at [gps=" .. front_loco.position.x .. "," .. front_loco.position.y .. ']'
        game.print('Sending ' .. train.id .. front_loco_gps_text .. ' to a rail ' .. rail_gps_text)
        makeTrainGoToRail(rail, train)
    end
end

function checkIfTrainCanGetToRail(train, rail)
    local schedule_entry = {
        rail=rail
    }
    old_schedule = train.schedule
    new_schedule = train.schedule
    new_schedule.records = {schedule_entry}
    new_schedule.current = 1

    train.schedule = new_schedule
    train.recalculate_path(true)
    local result = false
    local gps = " at [gps=" .. rail.position.x .. "," .. rail.position.y .. ']'
    if train.state == 1 or train.state == 3 then
        game.print('The rail is not accessible')
    else
        game.print('The rail is accessible, state is ' .. TRAIN_STATES[train.state + 1])
        result = true
    end
    train.schedule = old_schedule
    train.recalculate_path(true)
    return result
    
end

function findNearestRails(surface, bounding_box, search_offset)
    local search_area = {
        {bounding_box.left_top.x - search_offset, bounding_box.left_top.y - search_offset},
        {bounding_box.right_bottom.x + search_offset, bounding_box.right_bottom.y + search_offset},
    }
    --local color = {r = 1, g = 0, b = 1}
    --rendering.draw_rectangle({left_top=search_area[1], right_bottom=search_area[2], color=color, surface=surface, time_to_live=300})


    local found_rails = surface.find_entities_filtered({
        name={"straight-rail", "curved-rail"},
        area = search_area,
    })
    --game.print("rails found: " .. #found_rails)
    return found_rails
end

