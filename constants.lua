local constants = {}

-- water ghost stuff
constants.dummyPrefix = "buex-waterGhost-"
constants.vanillaLandfill = "landfill"
constants.paintingWithLandfillLandfillTypes = { "dry-dirt", "dirt-4", "grass-1", "red-desert-1", "sand-3" }
constants.spaceLandfillTypes = { "se-space-platform-scaffold", "se-space-platform-plating", "se-spaceship-floor" }

-- tasks and blueprints
constants.unlabeled_blueprints_placeholder_label = "unlabeled blueprint"
constants.construction_wagon_prototype_name = 'ct-construction-wagon'
constants.deconstruction_blueprint_label_placeholder = "DECONSTRUCTION"
-- worker reach is calculated from construction area, accounting for the fact that locomotive (8 tiles) is first and 2 more for good measure
constants.subtask_coverage_by_construction_area_offset = 10
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

-- spiders
constants.spider_carrier_prototype_name = 'buex-spider-carrier-wagon'
constants.spider_carrier_equipment_category_prototype_name = 'buex-spider-carrier-wagon-equipment'
constants.spider_carrier_grid_prototype_name = 'buex-spider-carrier-wagon-grid'
constants.buex_technology = 'buex-technology'
constants.spider_carrier_proxy_prototype_name = 'buex-spider-carrier-prototype'
-- pathfinding
constants.max_pathfinding_attempts = 5
constants.pathfinding_proxy_name = 'buex-pathfinding-proxy'
constants.spider_carrier_navigate_subtask = 'spider_carrier_navigate_subtask'
constants.spider_carrier_collect_spider = 'spider_carrier_collect_spider'
constants.parking_wait_time = 60*60*10  -- 10 mins

return constants