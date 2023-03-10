mod_gui = require("mod-gui")


function createTestWidget(player_index)

    -- main frame
    local screen_element = game.get_player(player_index).gui.screen
    local main_frame = screen_element.add{type="frame", name="buex_main_frame", caption={"buex.hello_world"}}
    main_frame.style.size = {385, 165}
    main_frame.auto_center = true
    main_frame.visible = false

    -- tabs
    local tabs = main_frame.add{type="tabbed-pane", name="buex_gui_tabs", caption={"buex.hello_world"}}
    local tab1 = tabs.add{type="tab", caption="Tab 1"}
    local tab2 = tabs.add{type="tab", caption="Tab 2"}
    local label1 = tabs.add{type="label", caption="Label 1"}
    local label2 = tabs.add{type="label", caption="Label 2"}
    tabs.add_tab(tab1, label1)
    tabs.add_tab(tab2, label2)

    
end

function toggleTestWidget(player_index)
    local element = game.get_player(player_index).gui.screen.buex_main_frame
    element.visible = not element.visible
end

script.on_event(defines.events.on_gui_click, function(event)

    if event.element.name == "buex_open_gui" then

        toggleTestWidget(event.player_index)
    end

end)
