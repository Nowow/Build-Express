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
        rail=rail
    }
    new_schedule = train.schedule
    table.insert(new_schedule.records, schedule_entry)

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
    if train.state == 1 or train.state == 3 then
        game.print('The rail is not accessible')
    else
        game.print('The rail is accessible, state is ' .. TRAIN_STATES[train.state + 1])
    end
    train.schedule = old_schedule
    
end

function FindNearestRails(surface, position, offset)
    local area = {
        {position.x - offset, position.y - offset},
        {position.x + offset, position.y + offset}
    }
    local color = {r = 1, g = 0, b = 1}
    rendering.draw_rectangle({left_top=area[1], right_bottom=area[2], color=color, surface=surface, time_to_live=300})

    local found_rails = surface.find_entities_filtered({
        name={"straight-rail", "curved-rail"},
        area = area,
        limit=4,
    })
    game.print("rails found: " .. #found_rails)
    for _, rail in pairs(found_rails) do
        hightlighRail(rail)
    end
end

