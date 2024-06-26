local utils = require("utils")
local reader = require("lib.yaml.reader")

local writer = {}

function writer.write(filename, data, options)
    local validationSuccess, serialized

    if not options or options.validate ~= false then
        -- Make sure our writer doesn't discard any data

        validationSuccess, serialized = writer.validateSerializiation(data)

        if not validationSuccess then
            return false, false
        end
    end

    local fh = io.open(filename, "wb")
    local serialized = serialized or writer.serialize(data, options)

    if fh then
        fh:write(serialized)
        fh:close()

        return true, serialized
    end

    return false, serialized
end

local indicators = "[-?:,%[%]{}#&*!|>'\"%%@`]" --A pattern that matches all yaml characters listed as indicators in the most recent standard, which could cause problems if simply blindly written in strings
function writer.serialize(data, options, depth, firstDepth)
    options = options or {}
    depth = depth or 0
    firstDepth = firstDepth or depth
    local indentationStep = options.indentationStep or 2
    local sortKeys = options.sortKeys ~= false

    local dataType = type(data)

    if dataType == "string" then
        --use quotes as needed
        if string.match(data, indicators) then
            local out = string.gsub(data, "\\", "\\\\") --escape backslashes
            out = string.gsub(out, "\"", "\\\"") --escape quotes. Not sure if the reader can correctly deal with escape sequences
            return "\"" .. out .. "\""
        end
        return data

    elseif dataType == "boolean" then
        return tostring(data)

    elseif dataType == "number" then
        -- TODO - Does this handle floats/integers sanely?
        return tostring(data)

    elseif dataType == "table" then
        local lines = {}
        local isList = #data > 0
        local spacingPrefix = string.rep(" ", depth * indentationStep)
        local firstSpacingPrefix = string.rep(" ", firstDepth * indentationStep)

        if isList then
            for _, v in ipairs(data) do
                table.insert(lines, string.format("- %s", writer.serialize(v, options, depth + 1, 0)))
            end

        elseif sortKeys then
            -- Scalars sorted alphabetically followed by tables sorted alphabetically
            local sortedScalars = {}
            local sortedTables = {}

            for k, v in pairs(data) do
                local sorted = type(v) == "table" and sortedTables or sortedScalars
                local pos = #sorted + 1

                for i, sv in ipairs(sorted) do
                    if k < sv[1] then
                        pos = i

                        break
                    end
                end

                table.insert(sorted, pos, {k, v})
            end

            for _, v in ipairs(sortedScalars) do
                table.insert(lines, string.format("%s: %s", v[1], writer.serialize(v[2], options, depth + 1)))
            end

            for _, v in ipairs(sortedTables) do
                if not utils.isEmpty(v[2]) then
                    table.insert(lines, string.format("%s:\n%s", v[1], writer.serialize(v[2], options, depth + 1)))
                end
            end

        else
            for k, v in pairs(data) do
                if type(v) ~= "table" then
                    table.insert(lines, string.format("%s: %s", k, writer.serialize(v, options, depth + 1)))
                elseif not utils.isEmpty(v) then
                    table.insert(lines, string.format("%s:\n%s", k, writer.serialize(v, options, depth + 1)))
                end
            end
        end

        for i, line in ipairs(lines) do
            local spacing = i == 1 and firstSpacingPrefix or spacingPrefix

            lines[i] = spacing .. line
        end

        return table.concat(lines, "\n")

    else
        print("Unknown type " .. dataType)
    end
end

-- Since our writer is not completely up to spec make sure we can read the data back
function writer.validateSerializiation(data)
    local serialized = writer.serialize(data)
    local unserializeSuccess, unserialized = pcall(reader.eval, serialized)

    if not unserializeSuccess then
        return false
    end

    return utils.serialize(data) == utils.serialize(unserialized), serialized, unserialized
end

return writer