require("lib.utils")
require("lib.blueprints")

function CheckIfRailsIsAccessible(selected_entity)
    for _, train in pairs(global.registred_trains) do
        checkIfTrainCanGetToRail(train, selected_entity)
    end
end

function PrintEntityCollisionMasks(selected_entity)
    local selected_entity = game.players[event.player_index].selected

    local str_to_print = {""}
    local collision_mask = game.entity_prototypes[selected_entity.name]['collision_mask']
    for e, _ in pairs(collision_mask) do
        table.insert(str_to_print , e)
    end    
    game.print(str_to_print)
end

function PrintSelectedBlueprintName(event)
    local player = game.players[event.player_index]
    if player.is_cursor_blueprint() then
        game.print("This is a blueprint and its type is " .. player.cursor_stack.label)
    end

end

function PrintFirstLastTick(event)
    game.print("First tick is " .. first_tick)
    game.print("Last tick is " .. last_tick)
    first_tick = nil
    last_tick = nil
end
