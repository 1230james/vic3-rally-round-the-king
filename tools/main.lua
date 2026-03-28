-- Monarchy Law Auto Replacer for the Rally Round the Kind mod for Victoria 3 by 1230james
-- Parses all Victoria 3 game files for any instances of `has_law = law_type:law_monarchy` and replaces it with a
-- suitable alternative to work with RRK's mechanics

-- Recommended to run with LuaBinaries: https://luabinaries.sourceforge.net/download.html
-- A binary + runner script for Windows users should already be included with this mod / repository.
-- You can probably use LuaJIT in a pinch if you're so inclined and are able to compile it for yourself.

-- Python and JS fans can go cope and seethe 😎

-- ================================================================================================================== --

local LOG_FILE -- Defined below
local GAME_DIR

local PLATFORM
local PLATFORM_TYPE = {
    UNIX = 1,
    WIN  = 2
}

-- Replace all `has_law = law_type:law_monarchy` with this string
local NEW_MONARCHY_TRIGGER = "RRK_st_has_monarchy = yes"
local NEW_MONARCHY_OR_VARIANT_TRIGGER = "RRK_st_has_monarchy_or_variant = yes"

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

-- https://stackoverflow.com/a/7615129
local function split_string(str, delim)
    if delim == nil then
        delim = "%s"
    end
    local t = {}
    for str in string.gmatch(str, "([^"..delim.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function count_braces(str)
    local opening, closing = 0, 0
    for i = 1, #str, 1 do
        local c = str:sub(i, i)
        if c == "#" then
            break
        elseif c == "{" then
            opening = opening + 1
        elseif c == "}" then
            closing = closing + 1
        end
    end
    return opening, closing
end

local function is_commented_line(str)
    local char_LU = {
        [' ']    = false,
        ['\t']   = false,
        ['\239'] = false, -- ï -- BOM-related char
        ['\187'] = false, -- » -- BOM-related char
        ['\191'] = false, -- ¿ -- BOM-related char
        ['#']    = true
    }
    
    for i = 1, #str, 1 do
        local c = str:sub(i, i)
        if char_LU[c] == false then
            -- NOP
        elseif char_LU[c] then
            return true
        else
            return false
        end
    end
    return false
end

local function set_platform()
    if package.config:sub(1,1) == "\\" then
        PLATFORM = PLATFORM_TYPE.WIN
    else
        PLATFORM = PLATFORM_TYPE.UNIX
    end
end

local function find_files(path)
    local t = {}
    if PLATFORM == PLATFORM_TYPE.UNIX then
        local STREAM = io.popen("find \"" .. path .. "\" -name '*.txt'")
        while true do
            local line = STREAM:read("l")
            if not line then
                break
            end
            line = line:gsub(path,".")
            table.insert(t, line)
            print_log("  Found file: " .. line)
        end
        
    elseif PLATFORM == PLATFORM_TYPE.WIN then
        local STREAM = io.popen("forfiles /P \"" .. path:gsub("/","\\") .. "\" /S /M *.txt /C \"cmd /C echo @relpath\"")
        while true do
            local line = STREAM:read("l")
            if not line then
                break
            end
            if line ~= "" then
                line = line:gsub("\\","/"):gsub('"',"")
                table.insert(t, line)
                print_log("  Found file: " .. line)
            end
        end
        
    else
        error("find_files: Platform type not set")
    end
    return t
end

local DIR_DELIM = package.config:sub(1,1)
local function mkdir(path)
    -- Strip leading ./ if it exists
    if path:sub(1,2) == "./" or path:sub(1,2) == ".\\" then
        path = path:sub(3)
    end
    
    path = path:gsub("\\", DIR_DELIM):gsub("/", DIR_DELIM) -- Fix dir delimiters
    os.execute("mkdir " .. path)
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
        
        if line:find("{") and (not is_commented_line(line)) then
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

-- Logic calling this function is responsible for setting up the output path directories
local function parse_script_file(in_filepath, out_filepath)
    local IN_FILE  = io.open(in_filepath, "rb")
    local OUT_FILE
    
    print_log("Parsing " .. in_filepath:gsub(GAME_DIR, "") .. "...")
    while true do
        local block, eof = read_next_block(IN_FILE)
        for i, line in pairs(block) do
            if line:find("has_law") and line:find("law_monarchy") then
                local block_name = block[1]:sub(1, block[1]:find("=") - 1) -- sorta kinda; weird formatting notwithstanding
                print_log("  Found Monarchy check in block: " .. block_name)
                
                if not OUT_FILE then
                    OUT_FILE = io.open(out_filepath, "w+b")
                    OUT_FILE:write(
                        "\239\187\191" ..  -- Byte Order Mark for UTF-8-BOM
                        "# DO NOT EDIT THIS FILE - It is automatically generated\n" ..
                        "# See the `tools` folder in the mod's root directory\n\n"
                    )
                end
                
                for j, w_line in pairs(block) do
                    -- Substitute law check
                    w_line = w_line:gsub("has_law_or_variant.*=.*law_monarchy", NEW_MONARCHY_OR_VARIANT_TRIGGER)
                    w_line = w_line:gsub("has_law.*=.*law_monarchy", NEW_MONARCHY_TRIGGER)
                    OUT_FILE:write(w_line)
                end
                OUT_FILE:write("\n") -- spacing newline
                print_log("    Substituted & exported " .. block_name)
                
                break
            end
        end
        if eof then
            break
        end
    end
    
    if OUT_FILE then
        OUT_FILE:close()
    end
end

local OUT_DIR_FILE_COUNT = {}
local function parse_game_dir(dirpath, out_dirpath, out_prefix)
    local files     = find_files(dirpath)
    local gen_count = 0
    
    if not out_prefix then
        out_prefix = ""
    end
    
    if not OUT_DIR_FILE_COUNT[dirpath] then
        OUT_DIR_FILE_COUNT[dirpath] = {}
    end
    
    for i, filepath in pairs(files) do
        -- Set up output directories
        local out_dir     = out_dirpath
        local path_chunks = split_string(filepath, "/")
        local num_chunks  = #path_chunks
        for j, path_chunk in pairs(path_chunks) do
            if j > 1 and j < num_chunks then -- skip the `.` & the actual filename
                out_dir = out_dir .. "/" .. path_chunk
                if not filesys_exists(out_dir) then
                    print_log("Creating " .. out_dir .. " because it does not exist")
                    mkdir(out_dir)
                end
            end
        end
        
        -- Parse file
        local in_path, out_path = filepath:gsub(".",dirpath,1), out_dir .. "/" .. out_prefix .. path_chunks[num_chunks]
        parse_script_file(in_path, out_path)
        
        -- Count results (used to delete unneeded output subdirs)
        if not OUT_DIR_FILE_COUNT[dirpath][out_dir] then
            OUT_DIR_FILE_COUNT[dirpath][out_dir] = 0
        end
        if filesys_exists(out_path) then
            gen_count = gen_count + 1
            OUT_DIR_FILE_COUNT[dirpath][out_dir] = OUT_DIR_FILE_COUNT[dirpath][out_dir] + 1
        end
    end
    
    for out_dir, count in pairs(OUT_DIR_FILE_COUNT[dirpath]) do
        if count == 0 then
            local success = os.execute("rmdir " .. out_dir:gsub("./","",1):gsub("\\", DIR_DELIM):gsub("/", DIR_DELIM))
            if not success then
                print_log("  Failed to delete: " .. out_dir)
            end
        end
    end
    
    return gen_count
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

-- Platform check
set_platform()

-- Create output folder if it doesn't exist
if not filesys_exists("./generated") then
    print_log("Creating output directory...")
    mkdir("generated")
    print_log("Output directory created\n")
end

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

GAME_DIR = arg[1] .. "/game/"

-- Do the stuff
print_log("Parsing " .. GAME_DIR .. "common")
parse_game_dir(GAME_DIR .. "common", "./generated/common", "RRK_")

-- Cleanup
print_log('\nFinished!\nCheck the "generated" folder for the files.')
if LOG_FILE then
    LOG_FILE:close()
end
