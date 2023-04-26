---This Module is responsible for updating blueprints and repacle their contents with dummy water ghost entity_prototypes
local blueprints = {}
local Inventory = require('__stdlib__/stdlib/entity/inventory')
local table = require('__stdlib__/stdlib/utils/table')
local util = require('util')

local constants = require('constants')
require('lib.ghosts_on_water_port.common')

--function that replaced BlueprintEntity with respective dummy
-- @tparam BlueprintEntity
blueprints.ReplaceEntityWithDummy = function(entity)
    if (dummyEntityPrototypeExists(entity.name)) then
        --replace entity with dummy entity by renaming it, because it is merely BlueprintEntity
        entity.name = constants.dummyPrefix .. entity.name
    end
    return entity
end

blueprints.getDummyEntities = function(blueprint)
    local blueprintEntities = blueprint.get_blueprint_entities()

    --return if blueprintEntities is empty
    if not blueprintEntities or # blueprintEntities == 0 then return end

    --replace blueprint entities with dummy entities using table.map
    local dummyEntities = table.map(blueprintEntities, blueprints.ReplaceEntityWithDummy)
    return dummyEntities
end


--- Update a single blueprint, applying the replacerFunction to every entity in the blueprint.
-- @tparam LuaItemStack blueprint
-- @tparam func replacerFunction
blueprints.updateSingleBlueprint = function(blueprint)
    --Safety checks: make sure stack is a blueprint and valid
   if not blueprint then return end
   if not blueprint.valid_for_read then return end
   if not blueprint.is_blueprint then return end
   if not blueprint.is_blueprint_setup() then return end

   local dummyEntities = blueprints.getDummyEntities(blueprint)
   blueprint.set_blueprint_entities(dummyEntities)
end


return blueprints