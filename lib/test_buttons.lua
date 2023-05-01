require("lib.utils")
require("lib.blueprints")
local bl = require("lib.ghosts_on_water_port.blueprints")

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

function convertHeldBlueprintToWaterGhosts(player_index)
    --get the player
    local player = game.players[player_index]
    --saftey check: check if cursor stack is valid
    local cursor_stack = player.cursor_stack
    if not cursor_stack then return end
    --check if player is holding a single blueprint or a book
    if cursor_stack.is_blueprint then
        game.print("IS BLUEPRINT")
        bl.updateSingleBlueprint(cursor_stack)
    end
    --otherwise, do nothing
end


function replaceEntityWithSchmentity(e)
    local entity = game.get_player(e.player_index).selected
    local prototype_name = 'substation'
    
    local position = entity.position
    local force = entity.force

    entity.order_upgrade({force = force, target = prototype_name})
    
end

function getLogisticCell(e)
    local entity = game.get_player(e.player_index).selected
    local cell = entity.logistic_cell
    game.print(cell.construction_radius)
end


-- user triggered keyboard shortcut
script.on_event("test-custom-hotkey", function(event)
    if event then

        local gui_main_frame = get_player_screen(event.player_index).buex_main_frame

        if gui_main_frame ~= nil then
            gui_main_frame.destroy()
        end

        global.construction_tasks = nil
        
        initGlobal()

    end
end)

    -- user triggered keyboard shortcut
script.on_event("test-custom-hotkey-a", function(event)
    game.print("CUSTOM HOTKEY A TRIGGERED")
    local player_index = event.player_index
    global.entity_selected = game.get_player(player_index).selected
end)