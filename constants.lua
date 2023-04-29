local constants = {}

constants.defaultUpdateDelay = 42
constants.dummyPrefix = "buex-waterGhost-"
constants.defaultMaxWaterGhostUpdatesPerUpdate = 300
constants.settingsUpdateDelay = 60
constants.vanillaLandfill = "landfill"
constants.paintingWithLandfillLandfillTypes = { "dry-dirt", "dirt-4", "grass-1", "red-desert-1", "sand-3" }

constants.spaceLandfillTypes = { "se-space-platform-scaffold", "se-space-platform-plating", "se-spaceship-floor" }

constants.unlabeled_blueprints_placeholder_label = "unlabeled blueprint"
constants.construction_wagon_prototype_name = 'ct-construction-wagon'
constants.deconstruction_blueprint_label_placeholder = "DECONSTRUCTION"
constants.task_flying_text_colors_by_task_type = {
    BUILD = {r=0,g=1,b=0.7},
    DECONSTRUCT = {r=1,g=0,b=1}
}

return constants