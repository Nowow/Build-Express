require("lib.trains")


function initGlobal()
	if not global.registred_trains then
		global.registred_trains = {}
	end
end

script.on_configuration_changed(function(data)
	initGlobal()
end)

script.on_init(function()
	initGlobal()
end)

function Round(v)
    return v and math.floor(v + 0.5)
  end

function PrintTrainWhereabouts(train)
    local train_id = train.id
    local train_state = train.state
    local front_stock = train.front_stock
    local train_position = front_stock.position
    local gps = " at [gps=" .. train_position.x .. "," .. train_position.y .. ']'
    game.print('Train ' .. train_id .. ' at a position ' .. gps .. ' is now in a state: ' .. train_state)
end


-- registring trains to a dispatch system
-- TODO: unregistrer trains, check if .valid

script.on_event(defines.events.on_train_changed_state,
function(event)
    --local player = game.player
    --local player_position = player.position
    local train = event.train
    PrintTrainWhereabouts(event.train)

    local station = event.train.station
    if station ~= nil then
        game.print('Station name: ' .. station.name)
    end
    if station ~= nil and station.name == 'test-train-stop' and global.registred_trains[train.id] == nil then
        global.registred_trains[train.id] = train
        game.print('Registred train ' .. train.id)
    end

    local registred_train_ids = {"", 'Registed trains count: '}

    for unit, _ in pairs(global.registred_trains) do
        table.insert(registred_train_ids, unit)
    end

    game.print(registred_train_ids)
end
)

function hightlighRail(rail)
    local color = {r = 0, g = 1, b = 0}
    local rail_box = {
        {rail.position.x - 1, rail.position.y - 1},
        {rail.position.x + 1, rail.position.y + 1}
    }
    rendering.draw_rectangle({
        left_top=rail_box[1],
        right_bottom=rail_box[2],
        color=color,
        surface=rail.surface,
        time_to_live=300
    })
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


-- user triggered keyboard shortcut
script.on_event("test-custom-hotkey", function(event)
if event then
    local selected_entity = game.players[event.player_index].selected
    local surface = game.players[event.player_index].surface
    game.print(selected_entity.position.x .. ' ' .. selected_entity.position.y)
    FindNearestRails(surface, selected_entity.position, 10)
end
end)