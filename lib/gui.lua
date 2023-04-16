mod_gui = require("mod-gui")

local player_screens = {}
local cam = {}

-- function create_entity_cam(event)
--     game.print('asdassaasas')
--     local selected_entity = game.players[event.player_index].selected
--     game.print("selected entity " .. selected_entity.prototype.name)w
--     game.print(" at [gps=" .. selected_entity.position.x .. "," .. selected_entity.position.y .. ']')
--     local screen_element = get_player_screen(event.player_index)

--     local cam_frame = screen_element.cam_frame
--     if cam_frame == nil then
--         game.print('CAM FRAME NIL')
--         cam_frame = screen_element.add{type="frame", name="cam_frame", caption='cam_frame'}
--         local cam_frame_flow = cam_frame.add{type="flow", name="cam_frame_flow"}
--         cam_frame_flow.add{type="camera", name='cam_frame_camera', position=selected_entity.position}
--         cam_frame_flow.cam_frame_camera.position = selected_entity.position
--         cam_frame.cam_frame_flow.add{type="label", caption="asdsadsdasd"}
--     else
--         game.print('CAM FRAME ERGO SUM')
--         cam_frame.cam_frame_flow.cam_frame_camera.entity = selected_entity
--         cam_frame.cam_frame_flow.cam_frame_camera.visible = true
--         cam_frame.cam_frame_flow.cam_frame_camera.focus()
--         cam_frame.cam_frame_flow.add{type="label", caption=serpent.block(cam_frame.cam_frame_flow.cam_frame_camera)}
        
--     end
    
    
-- end

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
    main_frame.style.natural_width  = 500
    main_frame.style.natural_height = 400

    main_frame.auto_center = true
    main_frame.visible = false

    -- tabs
    local tabs = main_frame.add{type="tabbed-pane", name="buex_gui_tabs"}
    ---- worker tab
    --local workers_tab = tabs.add{type="tab", name="buex_workers_tab", caption={"buex.workers_tab_caption"}}
    --local workers_scroll_pane = tabs.add{type="scroll-pane", name="buex_workers_scroll_pane", caption={"buex.workers_scroll_pane_caption"}}
    ---- blueprints tab
    local blueprints_tab = tabs.add{type="tab", name="buex_blueprints_tab", caption={"buex.blueprints_tab_caption"}}
    local blueprints_scroll_pane = tabs.add{type="scroll-pane", name="buex_blueprints_scroll_pane", caption={"buex.blueprints_scroll_pane_caption"}}
    ---- tasks tab
    local tasks_tab = tabs.add{type="tab", name="buex_tasks_tab", caption={"buex.tasks_tab_caption"}}
    local tasks_scroll_pane = tabs.add{type="scroll-pane", name="buex_tasks_scroll_pane", caption={"buex.tasks_scroll_pane_caption"}}
    tasks_scroll_pane.add{type="flow", name="buex_tasks_flow", direction="horizontal"}

    --tabs.add_tab(workers_tab, workers_scroll_pane)
    tabs.add_tab(blueprints_tab, blueprints_scroll_pane)
    tabs.add_tab(tasks_tab, tasks_scroll_pane)

end

function createBlueprintFrames(player_index)
    local blueprints_scroll_pane = get_player_screen(player_index).buex_main_frame.buex_gui_tabs.buex_blueprints_scroll_pane
    blueprints_scroll_pane.clear()
    for recipie, stations in pairs(global.worker_station_register) do
       local b_frame = blueprints_scroll_pane.add{type="frame", name="buex_recipies_"..recipie}
       b_frame.style.height = 40
       b_frame.style.width = 500

       b_frame.add{type="label", caption="Recipie: " .. recipie}
       b_frame.add{type="line", direction="vertical"}
       b_frame.add{type="label", caption="count: " .. table_size(stations)}
    end
end

function createTaskFrame(task, task_flow)

    local task_frame = task_flow.add{type="frame", name="buex_task_frame_".. task.id, direction="horizontal"}
    task_frame.style.height = 70
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

    --task worker
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
    
    if task.subtasks ~= nil then
        progress = (1.0 - (table_size(task.subtasks))/task.subtask_count)
        game.print("PROGRESS IS "..progress)
        game.print("#subtasks: " .. table_size(task.subtasks))
        game.print("subtask_count: " .. task.subtask_count)
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
        caption = "Delete task", tags={task_id=task.id}}
    button.style.height = 20
    button.style.width = 150


end

function toggleTestWidget(player_index)
    local element = game.get_player(player_index).gui.screen.buex_main_frame
    element.visible = not element.visible
end

script.on_event(defines.events.on_gui_click, function(event)

    if event.element.name == "buex_open_gui" then

        toggleTestWidget(event.player_index)
        return
    end
    if event.element.name == "buex_task_delete_button" then
        game.print("DELETE BUTTON CALLED, TAGS ".. event.   element.tags.task_id)
    end



end)


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