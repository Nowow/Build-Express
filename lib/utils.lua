
function Round(v)
    return v and math.floor(v + 0.5)
  end

function PrintTrainWhereabouts(train)
    local train_id = train.id
    local train_state = train.state
    local front_stock = train.front_stock
    local train_position = front_stock.position
    local gps = " at [gps=" .. train_position.x .. "," .. train_position.y .. ']'
    game.print('Train ' .. train_id .. ' at a position ' .. gps .. ' is now in a state: ' .. TRAIN_STATES[train_state + 1])
end

function hightlightEntity(entity, radius)

    local color = {r = 0, g = 1, b = 0}
    
    
    rendering.draw_circle({
        radius=radius,
        target=entity,
        color=color,
        surface=entity.surface,
        time_to_live=300
    })   
end