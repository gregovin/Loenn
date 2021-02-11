local ui = require("ui")
local uiElements = require("ui.elements")
local uiUtils = require("ui.utils")

local widgetUtils = require("ui.widgets.utils")
local listWidgets = require("ui.widgets.lists")
local simpleDocks = require("ui.widgets.simple_docks")

local toolHandler = require("tool_handler")

local toolWindow = {}

toolWindow.toolList = false
toolWindow.layerList = false
toolWindow.materialList = false

-- TODO - Use display name for now, otherwise entity variations don't work
-- In the future the "data" should be using a better identifier
local function getMaterialItems(layer, sortItems)
    local materials = toolHandler.getMaterials(nil, layer)
    local materialItems = {}

    for i, material in ipairs(materials or {}) do
        local materialText = material
        local materialData = material
        local materialType = type(material)

        if materialType == "table" then
            materialText = material.displayName or material.name
            materialData = material.name
        end

        table.insert(materialItems, uiElements.listItem({
            text = materialText,
            data = materialData
        }))
    end

    if sortItems or sortItems == nil then
        table.sort(materialItems, function(lhs, rhs)
            return lhs.text < rhs.text
        end)
    end

    return materialItems
end

local function materialCallback(list, material)
    toolHandler.setMaterial(material)
end

local function toolMaterialChangedCallback(self, tool, layer, material)
    listWidgets.setSelection(toolWindow.layerList, layer, true)
    listWidgets.setSelection(toolWindow.materialList, material, true)
end

local function getLayerItems(toolName)
    local layers = toolHandler.getLayers(toolName)
    local layerItems = {}

    for _, layer in ipairs(layers) do
        table.insert(layerItems, uiElements.listItem({
            text = layer,
            data = layer
        }))
    end

    return layerItems
end

local function layerCallback(list, layer)
    toolHandler.setLayer(layer)
end

local function toolLayerChangedCallback(self, tool, layer)
    local materialItems = getMaterialItems(layer)

    listWidgets.setSelection(toolWindow.layerList, layer, true)
    listWidgets.updateItems(toolWindow.materialList, materialItems)
end

-- TODO - Sort/group results
local function getToolItems(sortItems)
    local tools = toolHandler.tools
    local toolItems = {}

    for name, tool in pairs(tools) do
        table.insert(toolItems, uiElements.listItem({
            text = name,
            data = name
        }))
    end

    if sortItems or sortItems == nil then
        table.sort(toolItems, function(lhs, rhs)
            local lhsGroup = tools[lhs.text].group or ""
            local rhsGroup = tools[rhs.text].group or ""

            return lhsGroup < rhsGroup or lhs.text < rhs.text
        end)
    end

    return toolItems
end

local function toolCallback(list, toolName)
    toolHandler.selectTool(toolName)
end

local function toolChangedCallback(self, tool)
    local layerItems = getLayerItems(tool.name)

    listWidgets.setSelection(toolWindow.toolList, tool.name, true)
    listWidgets.updateItems(toolWindow.layerList, layerItems)
end

function toolWindow.getWindow()
    local materialListOptions = {
        searchBarLocation = "below"
    }

    local toolItems = getToolItems()
    local layerItems = getLayerItems()
    local materialItems = getMaterialItems()

    local scrolledMaterialList, materialList = listWidgets.getList(materialCallback, materialItems, materialListOptions)
    local scrolledLayerList, layerList = listWidgets.getList(layerCallback, layerItems)
    local scrolledToolList, toolList = listWidgets.getList(toolCallback, toolItems)

    toolWindow.toolList = toolList
    toolWindow.layerList = layerList
    toolWindow.materialList = materialList

    local row = uiElements.row({
        scrolledToolList,
        scrolledLayerList,
        scrolledMaterialList
    }):with(uiUtils.fillHeight(true))

    local window = uiElements.window("Tools", row):with(uiUtils.fillHeight(false))

    window:with({
        editorToolChanged = toolChangedCallback,
        editorToolLayerChanged = toolLayerChangedCallback,
        editorToolMaterialChanged = toolMaterialChangedCallback,
    })

    widgetUtils.removeWindowTitlebar(window)

    return simpleDocks.pinWidgetToEdge("right", window)
end

return toolWindow