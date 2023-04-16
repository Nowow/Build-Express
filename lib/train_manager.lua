--probably deprecated

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