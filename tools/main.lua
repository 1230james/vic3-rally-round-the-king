-- Monarchy Law Auto Replacer for the Rally Round the Kind mod for Victoria 3 by 1230james
-- Parses all Victoria 3 game files for any instances of `has_law = law_type:law_monarchy` and replaces it with a
-- suitable alternative to work with RRK's mechanics

-- Recommended to run with LuaBinaries: https://luabinaries.sourceforge.net/download.html
-- A binary + runner script for Windows users should already be included with this mod / repository.
-- You can probably use LuaJIT in a pinch if you're so inclined and are able to compile it for yourself.

-- Python and JS fans can go cope and seethe 😎

-- ================================================================================================================== --

local LOG_FILE -- Defined below

-- Replace all `has_law = law_type:law_monarchy` with this string
local NEW_MONARCHY_TRIGGER = "RRK_st_has_monarchy = yes"

-- ================================================================================================================== --

local function print_log(msg)
    if LOG_FILE then
        LOG_FILE:write(msg .. "\n")
    end
    print(msg)
end

-- https://stackoverflow.com/questions/1340230/check-if-directory-exists-in-lua
local function filesys_exists(path)
    local ok, err, code = os.rename(path, path)
    if not ok then
        if code == 13 then
            -- Permission denied, but it exists
            return true
        end
    end
    return ok, err
end

-- https://stackoverflow.com/questions/5243179/what-is-the-neatest-way-to-split-out-a-path-name-into-its-components-in-lua
local function get_filename(filepath)
    local a,b,c = string.match(filepath, "(.-)([^\\/]-%.?([^%.\\/]*))$")
    return b
end

local function count_braces(str)
    local opening, closing = 0, 0
    for i = 1, #str, 1 do
        local c = str:sub(i, i)
        if c == "{" then
            opening = opening + 1
        elseif c == "}" then
            closing = closing + 1
        end
    end
    return opening, closing
end

-- ================================================================================================================== --

-- Returns:
--     - Array of strings containing the block, line by line
--     - Bool indicating EOF
local function read_next_block(file)
    local arr = {}
    local run, eof = true, false
    
    while run do
        -- Wait for opening brace
        local line = file:read("L")
        if not line then
            run, eof = false, true
            break
        end
        if line:find("{") then
            table.insert(arr, line)
            
            -- Insert lines until closing brace
            local closed = false
            local braces = 1
            while run do
                line = file:read("L")
                if not line then
                    print_log("!!! ERR !!! - Malformed file")
                    run, eof = false, true
                    break
                end
                
                table.insert(arr, line)
                local opening, closing = count_braces(line)
                braces = braces + opening - closing
                if closing > 0 and braces <= 0 then
                    run = false
                end
            end
        end
    end
    
    return arr, eof
end

local function parse_script_file(filepath)
   -- TODO 
end

-- ================================================================================================================== --

-- Set up log file
do
    LOG_FILE = io.open("generator_log.log", "a+")
    local success
    if LOG_FILE then
        success = LOG_FILE:seek("end")
    end
    if success then
        if LOG_FILE:seek() > 0 then
            LOG_FILE:write("\n\n\n")
        end
        LOG_FILE:write("=== Execution start: " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n\n")
    else
        print("! WARN ! - Unable to create or open file 'generator_log.log' for logging - no log will be saved.\n")
        if LOG_FILE then
            LOG_FILE:close()
            LOG_FILE = nil
        end
    end
end

-- Create output folder if it doesn't exist
if not filesys_exists("./generated") then
    print_log("Creating output directory...")
    os.execute("mkdir generated")
    print_log("Output directory created\n")
end

-- Do the stuff

-- Args check
if not arg[1] then
    print_log("Missing path to Victoria 3 directory - exiting")
    if LOG_FILE then
        LOG_FILE:close()
    end
    os.exit()
end

if not filesys_exists(arg[1]) then
    print_log("Specified path does not appear to lead anywhere - exiting")
    if LOG_FILE then
        LOG_FILE:close()
    end
    os.exit()
end

if not filesys_exists(arg[1] .. "/game") then
    print_log("Specified path does not appear to be a Victoria 3 directory - exiting")
    if LOG_FILE then
        LOG_FILE:close()
    end
    os.exit()
end

local game_dir = arg[1] .. "/game/"

-- TEMP
local THE_FILE_PATH = game_dir .. "common/scripted_triggers/00_coa_triggers.txt"

local THE_FILE = io.open(THE_FILE_PATH, "r")

do
    local OUT_FILE = io.open("./generated/RRK_00_coa_triggers.txt", "w+b")
    
    while true do
        local block, eof = read_next_block(THE_FILE)
        for i, line in pairs(block) do
            if line:find("has_law") and line:find("law_monarchy") then
                for j, w_line in pairs(block) do
                    -- Substitute law check
                    w_line = w_line:gsub("has_law.*=.*law_monarchy", NEW_MONARCHY_TRIGGER)
                    print_log(w_line)
                    OUT_FILE:write(w_line)
                end
                break
            end
        end
        if eof then
            break
        end
    end
    
    OUT_FILE:close()
end

-- Cleanup
print_log('\nFinished!\nCheck the "generated" folder for the files.')
if LOG_FILE then
    LOG_FILE:close()
end
