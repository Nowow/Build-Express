require("lib.utils")
require("lib.blueprints")
require("lib.concepts.spider_carrier")
local pathfinder = require("lib.pathfinder")


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


function navigateSpiderCarrier(selected_entity, cursor_position)
    if selected_entity then
        global.test_spider_carrier = SpiderCarrier:create(selected_entity)
        game.print("CREATED SPIDER CARRIER")
        return
    end
    if cursor_position then
        game.print("NAVIGATING SPIDER")
        local bb = {
            left_top={cursor_position.x-20, cursor_position.y-20},
            right_bottom={cursor_position.x+20, cursor_position.y+20},
        }
        local carrier = global.test_spider_carrier
        carrier:releaseSpider()
        carrier:navigateSpiderToSubtask({bounding_box=bb})
    end

end

function printSpiderLogisticCell(selected_entity, cursor_position)
    if selected_entity then
        global.test_spider_carrier = SpiderCarrier:create(selected_entity)
        game.print("CREATED SPIDER CARRIER")
        return
    end
    if cursor_position then
        game.print("NAVIGATING SPIDER")
        local carrier = global.test_spider_carrier
        carrier:releaseSpider()
        game.print(carrier.spider.logistic_cell())
        
    end

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

        local player_index = event.player_index
        global.entity_selected = game.get_player(player_index).selected
        

    end
end)

    -- user triggered keyboard shortcut
script.on_event("test-custom-hotkey-a", function(event)
    game.print("CUSTOM HOTKEY A TRIGGERED")
    -- local goal = event.cursor_position
    -- pathfinder.request_path(global.entity_selected, goal)

    local player = game.get_player(event.player_index)
    local cursor_position = event.cursor_position
    local surface = player.surface
    local bb = {
        left_top={cursor_position.x-20, cursor_position.y-20},
        right_bottom={cursor_position.x+20, cursor_position.y+20},
    }

    printSpiderLogisticCell(player.selected, cursor_position)

    -- local tiles = player.surface.find_tiles_filtered{
    --     area = bb,
    --     collision_mask="water-tile",
    --     invert=true
    -- } 
    -- for _, tile in pairs(tiles) do
    --     rendering.draw_rectangle({
    --         left_top={tile.position.x-0.5, tile.position.y-0.5},
    --         right_bottom={tile.position.x+0.5, tile.position.y+0.5},
    --         color={r=0,g=1,b=1},
    --         surface=surface,
    --         time_to_live=700
    --     })
    -- end
end
)