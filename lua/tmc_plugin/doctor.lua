-- doctor.lua
-- Full diagnostics report for :TmcDoctor.
-- 7 checks: 5 sync (instant) + 2 async (update in place).
local M      = {}
local config = require("tmc_plugin.config")
local system = require("tmc_plugin.system")

local PASS = "  \u{2713}  "   -- ✓  (3-byte UTF-8 at byte offset 2)
local FAIL = "  \u{2717}  "   -- ✗
local WARN = "  ~  "
local UNKN = "  ?  "
local INFO = "       "        -- 7 spaces (aligns with PASS text)
local SEP  = "  " .. string.rep("\u{2500}", 54)  -- ─────

-- ─── Sync checks ─────────────────────────────────────────────────────────────

local function chk_neovim()
    local v  = vim.version()
    local ok = (v.major == 0 and v.minor >= 9) or v.major >= 1
    local s  = ("Neovim %d.%d.%d"):format(v.major, v.minor, v.patch)
    return ok and { PASS .. s .. " (supported)" }
              or  { FAIL .. s .. " \u{2014} upgrade to 0.9+" }
end

local function chk_exercises_dir()
    local dir = vim.fn.expand(config.exercises_dir)
    if vim.fn.isdirectory(dir) == 0 then
        return { FAIL .. "Not found: " .. dir,
                 INFO .. "Check exercises_dir in setup()" }
    end
    local n = 0
    for _, e in ipairs(vim.fn.readdir(dir)) do
        if not e:match("^%.") and vim.fn.isdirectory(dir .. "/" .. e) == 1 then
            n = n + 1
        end
    end
    return { PASS .. dir,
             n > 0 and PASS .. n .. " course folder" .. (n ~= 1 and "s" or "") .. " on disk"
                    or WARN .. "No course folders \u{2014} download exercises first" }
end

local function chk_cache()
    local path = vim.fn.stdpath("cache") .. "/tmc_cache.json"
    if vim.fn.filereadable(path) == 0 then
        return { WARN .. "No cache \u{2014} run :TmcDashboard to fetch" }
    end
    local f = io.open(path, "r"); if not f then return { FAIL .. "Cache unreadable" } end
    local raw = f:read("*all"); f:close()
    local ok, data = pcall(vim.fn.json_decode, raw)
    if not ok or type(data) ~= "table" then
        return { FAIL .. "Cache corrupt \u{2014} delete and re-run :TmcDashboard" }
    end
    if #data == 0 then return { WARN .. "Cache empty \u{2014} run :TmcDashboard" } end
    local ex = 0
    for _, c in ipairs(data) do if c.raw_exercises then ex = ex + #c.raw_exercises end end
    return { PASS .. #data .. " courses \u{00b7} " .. ex .. " exercises cached" }
end

local function chk_context()
    local path = vim.fn.expand("%:p")
    local base = vim.fn.expand(config.exercises_dir)
    if base:sub(-1) == "/" then base = base:sub(1, -2) end
    if path == "" or path:sub(1, #base) ~= base then
        return { WARN .. "Not inside an exercise directory", "" }
    end
    local rest = path:sub(#base + 2)
    local course, exercise = rest:match("^([^/\\]+)[/\\]([^/\\]+)")
    if not course or not exercise then
        return { WARN .. "Cannot parse course/exercise from path", "" }
    end
    local on_disk  = vim.fn.isdirectory(base .. "/" .. course .. "/" .. exercise) == 1
    local in_cache = false
    local cp = vim.fn.stdpath("cache") .. "/tmc_cache.json"
    if vim.fn.filereadable(cp) == 1 then
        local f = io.open(cp, "r")
        if f then
            local ok, data = pcall(vim.fn.json_decode, f:read("*all")); f:close()
            if ok and type(data) == "table" then
                for _, c in ipairs(data) do
                    if c.name == course then
                        for _, e in ipairs(c.raw_exercises or {}) do
                            if e.name == exercise then in_cache = true end
                        end
                    end
                end
            end
        end
    end
    local sym = (on_disk and in_cache) and PASS or WARN
    return {
        INFO .. "Course:   " .. course,
        INFO .. "Exercise: " .. exercise,
        sym  .. (on_disk  and "On disk"     or "NOT on disk")
             .. "  \u{00b7}  "
             .. (in_cache and "In cache" or "NOT in cache"),
    }
end

local function chk_config()
    local bp = config.bin or "tmc";  local bx = vim.fn.expand(bp)
    local dp = config.exercises_dir; local dx = vim.fn.expand(dp)
    local out = {}
    if bp ~= bx then
        table.insert(out, INFO .. "bin (configured): " .. bp)
        table.insert(out, INFO .. "bin (resolved):   " .. bx)
    else
        table.insert(out, INFO .. "bin:           " .. bx)
    end
    if dp ~= dx then
        table.insert(out, INFO .. "exercises_dir (configured): " .. dp)
        table.insert(out, INFO .. "exercises_dir (resolved):   " .. dx)
    else
        table.insert(out, INFO .. "exercises_dir: " .. dx)
    end
    return out
end

-- ─── Async checks ─────────────────────────────────────────────────────────────

local function chk_binary_async(cb)
    local bin = config.bin or "tmc"
    if vim.fn.executable(vim.fn.expand(bin)) == 0 then
        cb({ FAIL .. "Binary not found: " .. bin,
             INFO .. "Pass the full path via setup({ bin = '...' })" })
        return
    end
    system.run({ "--version" }, function(obj)
        local ver = vim.trim((obj.stdout .. obj.stderr):gsub("[\r\n]+", " "))
        vim.schedule(function()
            cb(obj.code == 0 and ver ~= ""
                and { PASS .. "Found:   " .. bin, PASS .. "Version: " .. ver }
                or  { PASS .. "Found:   " .. bin, WARN .. "Could not determine version" })
        end)
    end)
end

local function chk_auth_async(cb)
    system.run({ "courses" }, function(obj)
        local out = (obj.stdout .. obj.stderr):lower()
        vim.schedule(function()
            if obj.code == 0 and not out:match("login") and not out:match("error") then
                cb({ PASS .. "Connected to TMC server" })
            elseif out:match("login") then
                cb({ FAIL .. "Not authenticated \u{2014} run :TmcLogin" })
            else
                cb({ UNKN .. "Could not reach TMC server \u{2014} check network" })
            end
        end)
    end)
end

-- ─── Render ───────────────────────────────────────────────────────────────────

function M.run()
    local title    = "TMC Doctor \u{2014} " .. os.date("%Y-%m-%d %H:%M")
    -- Async sections need fixed placeholder line counts matching max result lines
    local BIN_PH  = { WARN .. "Checking...", "" }   -- Binary:  2 lines
    local AUTH_PH = { WARN .. "Checking..." }        -- Auth:    1 line

    local buf_lines  = { title, string.rep("=", vim.api.nvim_strwidth(title)), "" }
    local async_info = {}   -- [section_num] = { start, count }

    local function add_section(num, label, result_lines)
        table.insert(buf_lines, ("  [%d] %s"):format(num, label))
        table.insert(buf_lines, SEP)
        local start = #buf_lines   -- 0-based index of first result line
        for _, l in ipairs(result_lines) do table.insert(buf_lines, l) end
        async_info[num] = { start = start, count = #result_lines }
        table.insert(buf_lines, "")
    end

    add_section(1, "Binary",             BIN_PH)
    add_section(2, "Neovim",             chk_neovim())
    add_section(3, "Authentication",     AUTH_PH)
    add_section(4, "Exercises Directory",chk_exercises_dir())
    add_section(5, "Cache",              chk_cache())
    add_section(6, "Current Context",    chk_context())
    add_section(7, "Configuration",      chk_config())

    -- Create buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, buf_lines)
    vim.bo[buf].modifiable = false; vim.bo[buf].buftype  = "nofile"
    vim.bo[buf].bufhidden  = "wipe"; vim.bo[buf].swapfile = false

    vim.cmd("botright 20split")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    for k, v in pairs({ wrap = false, number = false, relativenumber = false,
                         signcolumn = "no", cursorline = false }) do
        vim.wo[win][k] = v
    end
    vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, silent = true })

    -- Highlights
    local ns = vim.api.nvim_create_namespace("tmc_doctor")
    local function apply_hl()
        vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
        vim.api.nvim_buf_add_highlight(buf, ns, "TmcMenuTitle", 0, 0, -1)
        for i, l in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            local li = i - 1
            if     l:match("^  %[%d%]")   then vim.api.nvim_buf_add_highlight(buf, ns, "TmcMenuGroup", li, 0, -1)
            elseif l:match("^  \u{2713}") then vim.api.nvim_buf_add_highlight(buf, ns, "TmcSuccess",   li, 2, 5)
            elseif l:match("^  \u{2717}") then vim.api.nvim_buf_add_highlight(buf, ns, "TmcFailure",   li, 2, 5)
            elseif l:match("^  [~?]")     then vim.api.nvim_buf_add_highlight(buf, ns, "TmcMenuHint",  li, 2, 3)
            end
        end
    end
    apply_hl()

    -- Async updater — pads/trims to original placeholder count so line numbers stay stable
    local function update(num, new_lines)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then return end
            local info = async_info[num]
            local padded = {}
            for i = 1, info.count do padded[i] = new_lines[i] or "" end
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, info.start, info.start + info.count, false, padded)
            vim.bo[buf].modifiable = false
            apply_hl()
        end)
    end

    chk_binary_async(function(l) update(1, l) end)
    chk_auth_async(  function(l) update(3, l) end)
end

return M
