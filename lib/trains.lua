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

function addStopToSchedule(rail, train)
    local schedule_entry = {
        rail=rail,
        wait_conditions={
            {
                type='time',
                ticks=300,
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
    table.insert(new_schedule.records, schedule_entry)
    game.print("ADDED STOP")
    train.schedule = new_schedule
end

function makeTrainGoToDepot(train)
    new_schedule = train.schedule
    new_schedule.records = {new_schedule.records[1]}
    new_schedule.current = 1
    train.schedule = new_schedule
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
    if train.state == 1 or train.state == 3 then
        --hightlighRail(rail)
        log('The rail is not accessible, state was: ' .. TRAIN_STATES[train.state + 1])
    else
        log('The rail is accessible, state is ' .. TRAIN_STATES[train.state + 1])
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

