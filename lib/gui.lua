mod_gui = require("mod-gui")

local player_screens = {}
local cam = {}


function update_cam_position()
    if #cam > 0 then
        cam.cam.position = cam.entity.position
    end
end

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
    main_frame.style.size = {1000, 300}
    main_frame.auto_center = true
    main_frame.visible = false

    -- tabs
    local tabs = main_frame.add{type="tabbed-pane", name="buex_gui_tabs"}
    ---- worker tab
    local workers_tab = tabs.add{type="tab", name="buex_workers_tab", caption={"buex.workers_tab_caption"}}
    local workers_scroll_pane = tabs.add{type="scroll-pane", name="buex_workers_scroll_pane", caption={"buex.workers_scroll_pane_caption"}}
    ---- blueprints tab
    local blueprints_tab = tabs.add{type="tab", name="buex_blueprints_tab", caption={"buex.blueprints_tab_caption"}}
    local blueprints_scroll_pane = tabs.add{type="scroll-pane", name="buex_blueprints_scroll_pane", caption={"buex.blueprints_scroll_pane_caption"}}
    ---- tasks tab
    local tasks_tab = tabs.add{type="tab", name="buex_tasks_tab", caption={"buex.tasks_tab_caption"}}
    local tasks_scroll_pane = tabs.add{type="scroll-pane", name="buex_tasks_scroll_pane", caption={"buex.tasks_scroll_pane_caption"}}
    tasks_scroll_pane.add{type="flow", name="buex_tasks_flow", direction="horizontal"}

    tabs.add_tab(workers_tab, workers_scroll_pane)
    tabs.add_tab(blueprints_tab, blueprints_scroll_pane)
    tabs.add_tab(tasks_tab, tasks_scroll_pane)

    for j = 1, 10 do
        workers_scroll_pane.add{
            type="frame", caption=j
        }
    end

end

function createTaskFrame(task, task_flow)

    local task_frame = task_flow.add{name="buex_task_frame_" .. task.id, type="frame", caption=task.id, direction="horizontal"}

    task_frame.style.height = 100
    task_frame.style.width = 900

    --task state
    task_frame.add{type="label", caption={"buex.task_state_caption"}}
    task_frame.add{type="label", caption={task.state}}
    task_frame.add{type="line", direction="vertical"}

    --task worker
    
        task_frame.add{type="label", caption={"buex.task_worker_caption"}}
    if task.worker ~= nil then
        task_frame.add{type="label", caption=task.worker.id}
    else
        task_frame.add{type="label", caption='NONE'}
    end
    task_frame.add{type="line", direction="vertical"}

    --task progress
    task_frame.add{type="label", caption="Task progress:"}
    if task.subtasks ~= nil then
        local progress = (1.0 - (#task.subtasks)/task.subtask_count)
        game.print("PROGRESS IS "..progress)
        game.print("#subtasks: " .. #task.subtasks)
        game.print("subtask_count: " .. task.subtask_count)
    else
        local progress = 0.5
    end
    task_frame.add{type="progressbar", name='sdfdsfdsdfs', value=progress}

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
