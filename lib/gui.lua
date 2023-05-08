mod_gui = require("mod-gui")
local constants = require("constants")

local player_screens = {}
local cam = {}

function get_player_screen(player_index)
    if player_screens[player_index] ~= nil then
        return player_screens[player_index]
    else
        player_screens[player_index] = game.get_player(player_index).gui.screen
        return player_screens[player_index]
    end
end

function update_task_frame(task, destroy)
    local screen_element = get_player_screen(task.player_index)
    local task_flow = screen_element.buex_main_frame.buex_gui_tabs.buex_tasks_scroll_pane.buex_tasks_flow
    local old_task_frame = task_flow["buex_task_frame_" .. task.id]

    if old_task_frame ~= nil then old_task_frame.destroy() end

    if not destroy then
        createTaskFrame(task, task_flow)
    end

end

function createTestWidget(player_index)


    local screen_element = get_player_screen(player_index)

    -- main frame
    local main_frame = screen_element.add{type="frame", name="buex_main_frame", caption={"buex.gui_caption"}}
    --main_frame.style.size = {600, 300}

    main_frame.style.minimal_width  = 400
    main_frame.style.maximal_width  = 1000
    main_frame.style.minimal_height = 200
    main_frame.style.maximal_height = 600
    main_frame.style.natural_width  = 525
    main_frame.style.natural_height = 400

    main_frame.auto_center = true
    main_frame.visible = false

    -- tabs
    local tabs = main_frame.add{type="tabbed-pane", name="buex_gui_tabs"}
    ---- tasks tab
    local tasks_tab = tabs.add{type="tab", name="buex_tasks_tab", caption={"buex.tasks_tab_caption"}}
    tasks_tab.style.horizontal_align = 'center'
    local tasks_scroll_pane = tabs.add{type="scroll-pane", name="buex_tasks_scroll_pane", caption={"buex.tasks_scroll_pane_caption"}}
    
    tasks_scroll_pane.style.width  = 510
    tasks_scroll_pane.style.height = 400
    tasks_scroll_pane.style.horizontal_align = 'center'

    local tasks_flow = tasks_scroll_pane.add{type="flow", name="buex_tasks_flow", direction="vertical"}

    tasks_flow.style.width  = 510 
    tasks_flow.style.height = 400
    tasks_flow.style.horizontal_align = 'center'
    

    tabs.add_tab(tasks_tab, tasks_scroll_pane)

end

function createTaskFrame(task, task_flow)

    local task_frame = task_flow.add{type="frame", name="buex_task_frame_".. task.id, direction="horizontal"}
    task_frame.style.height = 77
    task_frame.style.width = 500
    

    local task_table = task_frame.add{
        name="buex_task_table_" .. task.id, type="table",
        caption=task.id, column_count=2
    }

    task_table.style.cell_padding = 2
    task_table.style.horizontal_spacing = 1
    task_table.style.vertical_spacing = 1
    

    --task state
    local state_flow = task_table.add{type="flow", direction="horizontal"}
    state_flow.style.height = 28
    state_flow.style.width = 245
    state_flow.style.horizontal_align = 'center'
    


    state_flow.add{type="label", caption="Task state: " .. task.state}
    
    -- recipie name
    local recipie_flow = task_table.add{type="flow", direction="horizontal"}
    recipie_flow.style.height = 28
    recipie_flow.style.width = 245
    recipie_flow.style.horizontal_align = 'center'
    recipie_flow.add{type="label", caption="Blueprint: " .. task.blueprint_label}

    --task workera
    -- local worker_flow = task_table.add{type="flow", direction="horizontal"}
    -- worker_flow.style.height = 28
    -- worker_flow.style.width = 245
    -- worker_flow.style.horizontal_align = 'center'
    -- if task.worker ~= nil then
    --     worker_flow.add{type="label", caption="Task worker: " .. task.worker.id}
    --     local camera = worker_flow.add{type="camera", position=game.get_player(1).character.position}
    --     camera.entity = game.get_player(1).character
    -- else
    --     worker_flow.add{type="label", caption='Task worker: Not assigned'}
    -- end

    --task progress
    local progress = 0.0
    local progress_flow = task_table.add{type="flow", direction='horizontal'}
    progress_flow.style.height = 28
    progress_flow.style.width = 245
    progress_flow.style.horizontal_align = 'center'
    progress_flow.style.vertical_align = 'center'
    
    if task.subtasks ~= nil then
        progress = (1.0 - (table_size(task.subtasks))/task.subtask_count)
    else
        progress = 0.0
    end
    progress_flow.add{type="progressbar", name='progress_bar', value=progress}
    progress_flow.progress_bar.value = progress

    --delete button
    local button_flow = task_table.add{type="flow", direction='horizontal'}
    button_flow.style.height = 28
    button_flow.style.width = 245
    button_flow.style.horizontal_align = 'center'
    
    local button = button_flow.add{
        type="button", name="buex_task_delete_button",
        caption = "End task", tags={task_id=task.id, task_state=task.state}}
    button.style.height = 20
    button.style.width = 150
end

function displayCatchBlueprintOrderMessage(player_index, type, worker_type)

    local player = game.get_player(player_index)
    local center_widget = player.gui.center
    local old_msg_flow = center_widget[constants.catch_blueprint_order_gui_flow_name]
    if old_msg_flow then
        old_msg_flow.destroy()
    end
    local msg_flow = center_widget.add{type="flow", name=constants.catch_blueprint_order_gui_flow_name, direction='vertical'}
    msg_flow.style.height = 800
    msg_flow.style.width = 1200
    msg_flow.style.horizontal_align="center"
    msg_flow.style.vertical_align="top"
    local order_type_prefix, color
    if type == constants.order_type_blueprint then
        order_type_prefix = 'Blueprint'
        color = {r=0,g=1,b=1}
    else
        order_type_prefix = 'Deconsrtuction'
        color = {r=1,g=0,b=0}
    end
    local message_text = order_type_prefix .. " order will be handled by " .. worker_type
    local displayed_message = msg_flow.add{type="label", caption=message_text}
    displayed_message.style.font = constants.catch_blueprint_order_hotkey_font
    displayed_message.style.font_color = color
end

function destroyCatchBlueprintOrderMessage(player_index)
    local player = game.get_player(player_index)
    local center_widget = player.gui.center
    local msg_flow = center_widget[constants.catch_blueprint_order_gui_flow_name]
    if msg_flow then
        msg_flow.destroy()
    end
end


function toggleTestWidget(player_index)
    local element = game.get_player(player_index).gui.screen.buex_main_frame
    element.visible = not element.visible
end

function initPlayersGui()
    if not global.gui_player_info then
        global.gui_player_info = {}
    end
    for i, p in pairs(game.players) do
        if not global.gui_player_info[i] then
            global.gui_player_info[i] = {}
        end

        -- creating gui toggle button if not there
        local button_flow = mod_gui.get_button_flow(p)
        if button_flow.buex_open_gui == nil then
            button_flow.add{type="sprite-button", name="buex_open_gui", sprite="item/locomotive", style=mod_gui.button_style}
        end

        -- creating mod gui if not there
        local screen_element = get_player_screen(i)
        if screen_element.buex_main_frame == nil then
            createTestWidget(i)
        end

    end
end