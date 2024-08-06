

function extract_component_source_old(file_path, component_name)
    local file = io.open(file_path, "r")
    if not file then
        print("===========> NO SOURCE FILE, FUCK!")
        error("Could not open file: " .. file_path)
    end

    local lines = {}
    local nested_level = 0
    local capturing = false
    local component_pattern = "^%%%s*@component%s+" .. component_name .. "$"
    print("  -> PATTERN: " .. component_pattern)

    for line in file:lines() do
        print("  => SRC: '" .. line .. "'")
        if capturing then
            if nested_level > 0 or not line:match("^%%%s*@end") then
                table.insert(lines, line)
            end
            if line:match("^%%%s*@%w+") and not line:match("^%%%s*@end") then
                nested_level = nested_level + 1
            elseif line:match("^%%%s*@end") then
                if nested_level == 0 then
                    break
                end
                nested_level = nested_level - 1
            end
        elseif line:match(component_pattern) then
            capturing = true
        end
    end

    file:close()

    if #lines == 0 then
        print("===========> NO SOURCE, FUCK!")
        error("Component '" .. component_name .. "' not found in '" .. file_path .. "'")
    end

    print("===========> SRC!")
    return table.concat(lines, "\n")
end
function extract_component_source(file_path, component_name, include_directives)
    local file = io.open(file_path, "r")
    if not file then
        error("Could not open file: " .. file_path)
    end

    local lines = {}
    local nested_level = 0
    local capturing = false
    local component_pattern = "^%%%s*@component%s+" .. component_name .. "$"

    for line in file:lines() do
        if capturing then
            if nested_level > 0 or not line:match("^%%%s*@end") then
                table.insert(lines, line)
            elseif include_directives and nested_level == 0 then
                table.insert(lines, line)
                break
            elseif nested_level == 0 then
                break
            end

            if line:match("^%%%s*@%w+") and not line:match("^%%%s*@end") then
                nested_level = nested_level + 1
            elseif line:match("^%%%s*@end") then
                nested_level = nested_level - 1
            end
        elseif line:match(component_pattern) then
            capturing = true
            if include_directives then
                table.insert(lines, line)
            end
        end
    end

    file:close()

    if #lines == 0 then
        error("Component '" .. component_name .. "' not found in '" .. file_path .. "'")
    end

    return table.concat(lines, "\n")
end