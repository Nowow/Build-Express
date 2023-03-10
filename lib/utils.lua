
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

function hightlightEntity(entity, radius, color)

    
    --local color = {r = 0, g = 1, b = 0}
    
    
    rendering.draw_circle({
        radius=radius,
        target=entity,
        color=color,
        surface=entity.surface,
        time_to_live=300
    })   
end

function hightligtBoundingBox(bounding_box, color)

    --local color = {r = math.random(), g = math.random(), b = math.random()}

    rendering.draw_rectangle({
        left_top=bounding_box.left_top,
        right_bottom=bounding_box.right_bottom,
        color=color,
        surface=game.players[1].surface,
        time_to_live=300
    })
end


function rectangleOverlapsRectangle(bb1, bb2)
    if
        (
            bb1.left_top.x < bb2.right_bottom.x
        and bb1.left_top.y < bb2.right_bottom.y
        )
        and
        (
            bb1.right_bottom.x > bb2.left_top.x
        and bb1.right_bottom.y > bb2.left_top.y
        )
    then
        return true
    else
        return false
    end

end


function hightlighRail(rail)
    local color = {r = 0, g = 1, b = 0}
    local rail_box = {
        {rail.position.x - 1, rail.position.y - 1},
        {rail.position.x + 1, rail.position.y + 1}
    }
    local gps = " at [gps=" .. rail.position.x .. "," .. rail.position.y .. ']'
    game.print('Hightlighted rail' .. gps)
    rendering.draw_rectangle({
        left_top=rail_box[1],
        right_bottom=rail_box[2],
        color=color,
        surface=rail.surface,
        time_to_live=300
    })
end
