require("lib.utils")
require("settings")
local constants = require("constants")

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

function getRoboportRange(train)
    local roboport_wagon = train.carriages[2]
    if not roboport_wagon then
        log("Worker has less than 2 pieces wut")
        return
    end
    local logistic_cell = roboport_wagon.logistic_cell
    if not logistic_cell then
        log("No logistic cell")
    end
    return logistic_cell.construction_radius
end


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

function addStopToSchedule(rail, train, replace_next_temp)
    local replace_next_temp = replace_next_temp or replace_next_temp==nil and false
    local schedule_entry = {
        rail=rail,
        wait_conditions={
            {
                type='time',
                ticks=TASK_TIMEOUT_TICKS,
                compare_type='and'
            },
            {
                type='robots_inactive',
                compare_type='and'
            }
        },
        temporary=true
    }
    local new_schedule = train.schedule
    local new_records = new_schedule.records
    local current_index = new_schedule.current
    if not replace_next_temp or current_index == #new_records then
        table.insert(new_records, schedule_entry)
    else
        for i=current_index + 1, #new_records + 1 do
            local stop = new_records[i]
            if stop == nil or stop.temporary == true then
                new_records[i] = schedule_entry
                break
            end
        end
    end
    new_schedule.records = new_records
    game.print("ADDED STOP")
    train.schedule = new_schedule
end

function removeTimePassedConditionFromCurrentStop(train)
    

    local new_schedule = train.schedule
    local current_stop = new_schedule.records[new_schedule.current]
    local temp_flag = current_stop.temporary
    if not temp_flag then return end
    
    current_stop.wait_conditions = {
        {
            type='robots_inactive',
            compare_type='and'
        }
    }
    new_schedule.records[new_schedule.current] = current_stop
    train.schedule = new_schedule
end

function removeAllTempStops(train, leave_current)
    local leave_current = leave_current or leave_current==nil and false
    local old_records = train.schedule.records
    local new_records = {}
    
    local current_index = train.schedule.current


    local cntr = 0
    local stops_n = #old_records
    for i=1,stops_n do
        local stop = old_records[i]
        local temp_flag = stop.temporary
        if temp_flag == true and not (leave_current and i == train.schedule.current) then
            cntr = cntr + 1
            if current_index > i then
                current_index = current_index - 1
            end
        else
            table.insert(new_records, stop)
        end
    end
    local new_records_n = #new_records
    if current_index > new_records_n then
        current_index = new_records_n
    end
    local new_schedule = train.schedule
    new_schedule.records = new_records
    new_schedule.current = current_index
    train.schedule = new_schedule
    return cntr
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
    if not (train.state == 1 or train.state == 3) then
        result = true
        --hightlighRail(rail)
        --log('The rail is not accessible, state was: ' .. TRAIN_STATES[train.state + 1])

        --log('The rail is accessible, state is ' .. TRAIN_STATES[train.state + 1])
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

