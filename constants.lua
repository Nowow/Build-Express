local constants = {}

-- water ghost stuff
constants.dummyPrefix = "buex-waterGhost-"
constants.vanillaLandfill = "landfill"
constants.paintingWithLandfillLandfillTypes = { "dry-dirt", "dirt-4", "grass-1", "red-desert-1", "sand-3" }
constants.spaceLandfillTypes = { "se-space-platform-scaffold", "se-space-platform-plating", "se-spaceship-floor" }

-- tasks and blueprints
constants.unlabeled_blueprints_placeholder_label = "unlabeled blueprint"
constants.deconstruction_blueprint_label_placeholder = "DECONSTRUCTION"
constants.task_timeout_ticks = 7200*10
constants.construction_robot_fixed_cost = 50
constants.cliff_explosives_cost = 40
-- worker reach is calculated from construction area, accounting for the fact that locomotive (8 tiles) is first and 2 more for good measure
constants.task_flying_text_colors_by_task_type = {
    BUILD = {r=0,g=1,b=0.7},
    DECONSTRUCT = {r=1,g=0,b=1}
}
constants.TASK_STATES = {
    TASK_CREATED = 'TASK_CREATED',
    UNASSIGNED = 'UNASSIGNED',
    PARKING = 'PARKING',
    PREPARING = 'PREPARING',
    ASSIGNED = 'ASSIGNED',
    BUILDING = 'BUILDING',
    TERMINATING = 'TERMINATING'
}
constants.TASK_TYPES = {
    BUILD = "BUILD",
    DECONSTRUCT = "DECONSTRUCT"
}
constants.CAPTURE_MODES = {
    ADDITIVE = "ADDITIVE",
    REGULAR = "REGULAR"
}

--trains
constants.ct_construction_wagon_name = "ct-construction-wagon"
constants.buex_depot_name = "buex-depot"

-- spiders
constants.spider_carrier_prototype_name = 'buex-spider-carrier-wagon'
constants.spider_carrier_equipment_category_prototype_name = 'buex-spider-carrier-wagon-equipment'
constants.spider_carrier_grid_prototype_name = 'buex-spider-carrier-wagon-grid'
constants.buex_construction_train_technology = 'buex-construction-train-technology'
constants.buex_express_construction_unit_technology = 'buex-express-construction-unit-technology'
constants.spider_carrier_proxy_prototype_name = 'buex-spider-carrier-prototype'
-- pathfinding
constants.max_pathfinding_attempts = 5
constants.pathfinding_proxy_name = 'buex-pathfinding-proxy'
constants.spider_carrier_navigate_subtask_action = 'spider_carrier_navigate_subtask'
constants.spider_carrier_collect_spider_action = 'spider_carrier_collect_spider'
constants.parking_wait_time = 60*60*10  -- 10 mins

constants.subtask_construction_area_coverage_construction_train_offset = 25
constants.subtask_construction_area_coverage_ecu_offset = 5

--gui
constants.order_type_blueprint = 'order_type_blueprint'
constants.order_type_deconstruction = 'order_type_deconstruction'
constants.order_worker_type_construcion_train = 'Construction Train'
constants.order_worker_type_express_construction_unit = 'Express Construction Unit'
constants.catch_blueprint_order_naming_key = "catch_blueprint_order"
constants.catch_blueprint_order_hotkey_font = constants.catch_blueprint_order_naming_key .. '_hotkey_font'
constants.catch_blueprint_order_gui_flow_name = constants.catch_blueprint_order_naming_key .. '_flow'
--constants.catch_blueprint_order_gui_msg_name = constants.catch_blueprint_order_naming_key .. '_msg'

return constants