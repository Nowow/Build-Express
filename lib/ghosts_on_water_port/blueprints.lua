---This Module is responsible for updating blueprints and repacle their contents with dummy water ghost entity_prototypes
local blueprints = {}
local Inventory = require('__stdlib__/stdlib/entity/inventory')
local table = require('__stdlib__/stdlib/utils/table')
local util = require('util')

local constants = require('constants')
require('lib.ghosts_on_water_port.common')

--- Update a single blueprint, applying the replacerFunction to every entity in the blueprint.
-- @tparam LuaItemStack blueprint
-- @tparam func replacerFunction
blueprints.updateSingleBlueprint = function(blueprint, replacerFunction)
    --Safety checks: make sure stack is a blueprint and valid
   if not blueprint then return end
   if not blueprint.valid_for_read then return end
   if not blueprint.is_blueprint then return end
   if not blueprint.is_blueprint_setup() then return end

   --get blueprint entities
   local blueprintEntities = blueprint.get_blueprint_entities()
   --return if blueprintEntities is empty
   if not blueprintEntities or # blueprintEntities == 0 then return end

   --replace blueprint entities with dummy entities using table.map
   local dummyEntities = table.map(blueprintEntities, replacerFunction)

   --set the blueprint entities
   blueprint.set_blueprint_entities(dummyEntities)
end

--- Update blueprints in a book, applying the replacerFunction to entities.
--
-- If the 'UpdateAllBlueprintsInBooks' runtime-global setting is enabled (which
-- is the default) then this updates all blueprints in the book, and recurs into
-- books inside. If not, it only updates the active blueprint in the book.
--
-- @tparam LuaItemStack stack
-- @tparam func replacerFunction

blueprints.bpReplacerToDummy = function(entity)
    if (dummyEntityPrototypeExists(entity.name)) then
        --replace entity with dummy entity
        entity.name = constants.dummyPrefix .. entity.name
    end
    return entity
end

return blueprints