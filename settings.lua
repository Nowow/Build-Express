data:extend({
    {
        type = "int-setting",
        name = "ecu-parking-spot-search-offset",
        setting_type = "runtime-global",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 100
    },
    {
        type = "double-setting",
        name = "ecu-building-cost-modifier",
        setting_type = "runtime-global",
        default_value = 2.0,
        minimum_value = 1.0,
        maximum_value = 5.0
    },
})
