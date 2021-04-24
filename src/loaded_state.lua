local viewportHandler = require("viewport_handler")
local tasks = require("task")
local mapcoder = require("mapcoder")
local celesteRender = require("celeste_render")
local sceneHandler = require("scene_handler")
local filesystem = require("filesystem")
local fileLocations = require("file_locations")
local utils = require("utils")
local history = require("history")

local sideStruct = require("structs.side")

local state = {}

local function updateSideState(side, filename, eventName)
    eventName = eventName or "editorMapLoaded"

    celesteRender.invalidateRoomCache()
    celesteRender.clearBatchingTasks()

    state.filename = filename
    state.side = side
    state.map = state.side.map

    celesteRender.loadCustomTilesetAutotiler(state)

    history.reset()

    state.selectItem(state.map and state.map.rooms[1])

    sceneHandler.changeScene("Editor")

    sceneHandler.sendEvent(eventName, filename)
end

function state.loadFile(filename)
    if not filename then
        return
    end

    if history.madeChanges then
        sceneHandler.sendEvent("editorLoadWithChanges", state.filename, filename)

        return
    end

    sceneHandler.changeScene("Loading")

    tasks.newTask(
        (-> filename and mapcoder.decodeFile(filename)),
        function(binTask)
            if binTask.result then
                tasks.newTask(
                    (-> sideStruct.decodeTaskable(binTask.result)),
                    function(decodeTask)
                        updateSideState(decodeTask.result, filename, "editorMapLoaded")
                    end
                )

            else
                sceneHandler.changeScene("Editor")

                sceneHandler.sendEvent("editorMapLoadFailed", filename)
            end
        end
    )
end

function state.saveFile(filename, addExtIfMissing)
    if filename and state.side then
        if addExtIfMissing ~= false and filesystem.fileExtension(filename) ~= "bin" then
            filename ..= ".bin"
        end

        tasks.newTask(
            (-> sideStruct.encodeTaskable(state.side)),
            function(encodeTask)
                if encodeTask.result then
                    tasks.newTask(
                        (-> mapcoder.encodeFile(filename, encodeTask.result)),
                        function(binTask)
                            if binTask.done and binTask.success then
                                state.filename = filename
                                history.madeChanges = false

                                sceneHandler.sendEvent("editorMapSaved", filename)

                            else
                                sceneHandler.sendEvent("editorMapSaveFailed", filename)
                            end
                        end
                    )

                else
                    sceneHandler.sendEvent("editorMapSaveFailed", filename)
                end
            end
        )
    end
end

function state.selectItem(item, add)
    if add then
        if state.selectedItemType ~= "table" then
            state.selectedItem = {
                [state.selectedItem] = state.selectedItemType
            }

            state.selectedItemType = "table"
        end

        if not state.selectedItem[item] then
            state.selectedItem[item] = utils.typeof(item)

            sceneHandler.sendEvent("editorMapTargetChanged", state.selectedItem, state.selectedItemType, add)
        end

    else
        state.selectedItem = item
        state.selectedItemType = utils.typeof(item)

        sceneHandler.sendEvent("editorMapTargetChanged", state.selectedItem, state.selectedItemType, add)
    end
end

function state.getSelectedRoom()
    return state.selectedItemType == "room" and state.selectedItem or false
end

function state.getSelectedFiller()
    return state.selectedItemType == "filler" and state.selectedItem or false
end

function state.getSelectedItem()
    return state.selectedItem, state.selectedItemType
end

function state.openMap()
    filesystem.openDialog(fileLocations.getCelesteDir(), "bin", state.loadFile)
end

function state.newMap()
    if history.madeChanges then
        sceneHandler.sendEvent("editorNewMapWithChanges")

        return
    end

    local newSide = sideStruct.decode({})

    updateSideState(newSide, nil, "editorMapNew")
end

function state.saveAsCurrentMap()
    if state.side then
        filesystem.saveDialog(state.filename, "bin", state.saveFile)
    end
end

function state.saveCurrentMap()
    if state.side then
        if state.filename then
            state.saveFile(state.filename)

        else
            state.saveAsCurrentMap()
        end
    end
end

function state.getRoomByName(name)
    local rooms = state.map and state.map.rooms or {}
    local nameWithLvl = "lvl_" .. name

    for i, room in ipairs(rooms) do
        if room.name == name or room.name == nameWithLvl then
            return room, i
        end
    end
end

-- The currently loaded map
state.map = nil

-- The currently selected item (room or filler)
state.selectedItem = nil
state.selectedItemType = nil
state.selectedRooms = {}

-- The viewport for the map renderer
state.viewport = viewportHandler.viewport

return state