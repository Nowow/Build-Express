local dummyGenerator = require("prototypes/dummyGenerator")
local selectionPriorityFix = require("external-lib/SelectionPriorityFix")

dummyGenerator.GenerateDummyPrototypes()
selectionPriorityFix.FixSelectionPriority()