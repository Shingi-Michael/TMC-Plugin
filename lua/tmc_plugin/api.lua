local system = require("tmc_plugin.system")
local ui = require("tmc_plugin.ui")
local config = require("tmc_plugin.config")

local M = {}
local _course_cache = {}
local CACHE_PATH = vim.fn.stdpath("cache") .. "/tmc_cache.json"

-- Thread-safe Disk Persistence
local function save_to_disk()
    vim.schedule(function()
        local ok, encoded = pcall(vim.fn.json_encode, _course_cache)
        if not ok then return end
        local f = io.open(CACHE_PATH, "w")
        if f then
            f:write(encoded)
            f:close()
        end
    end)
end

local function load_from_disk()
    if vim.fn.filereadable(CACHE_PATH) == 1 then
        local f = io.open(CACHE_PATH, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local ok, data = pcall(vim.fn.json_decode, content)
            if ok then _course_cache = data end
        end
    end
end

load_from_disk()

local function get_project_root()
    local current_dir = vim.fn.expand("%:p:h")
    if current_dir:match("src$") then return vim.fn.fnamemodify(current_dir, ":h") end
    return current_dir
end

local function parse_exercises(raw_lines)
    local cleaned = {}
    for _, line in ipairs(raw_lines) do
        if line ~= "" and not line:match("Auto%-") and not line:match("Fetching") then
            local is_completed = line:match("Completed:") ~= nil
            local name = line:gsub("Completed:%s*", ""):gsub("^%s*[%[%]%sx]*%s*", "")
            name = vim.trim(name)
            if #name > 0 then table.insert(cleaned, { name = name, completed = is_completed }) end
        end
    end
    return cleaned
end

function M.get_courses(on_select, force_refresh)
    if not force_refresh and #_course_cache > 0 then
        on_select(_course_cache)
        return
    end

    ui.notify("Deep syncing TMC data...", "info")
    system.run({ "courses" }, function(obj)
        local names = {}
        for _, line in ipairs(vim.split(obj.stdout .. obj.stderr, "\n")) do
            if line ~= "" and not line:match("Auto%-") and not line:match("Organization") then
                table.insert(names, vim.trim(line))
            end
        end

        -- Guard: no courses means the user is probably not logged in
        if #names == 0 then
            vim.schedule(function()
                ui.notify("No courses found. Run :TmcLogin to authenticate.", "warn")
                on_select({})
            end)
            return
        end

        local results = {}
        local completed_count = 0
        for _, name in ipairs(names) do
            system.run({ "exercises", name }, function(ex_obj)
                local exs = parse_exercises(vim.split(ex_obj.stdout .. ex_obj.stderr, "\n"))
                local done = 0
                for _, e in ipairs(exs) do if e.completed then done = done + 1 end end
                local pct = #exs > 0 and math.floor((done / #exs) * 100) or 0

                table.insert(results, {
                    name = name,
                    progress_str = ui.make_progress_bar(pct),
                    raw_exercises = exs
                })
                completed_count = completed_count + 1

                if completed_count == #names then
                    _course_cache = results
                    save_to_disk()
                    vim.schedule(function() on_select(results) end)
                end
            end)
        end
    end)
end

function M.get_exercises(course_name, on_select, use_dashboard)
    for _, c in ipairs(_course_cache) do
        if c.name == course_name and c.raw_exercises then
            if use_dashboard then
                require("tmc_plugin.dashboard").render(course_name, c.raw_exercises)
            elseif on_select then
                on_select(c.raw_exercises)
            end
            return
        end
    end

    system.run({ "exercises", course_name }, function(obj)
        local cleaned = parse_exercises(vim.split(obj.stdout .. obj.stderr, "\n"))
        vim.schedule(function()
            if use_dashboard then
                require("tmc_plugin.dashboard").render(course_name, cleaned)
            elseif on_select then
                on_select(cleaned)
            end
        end)
    end)
end

function M.open_dashboard()
    M.get_courses(function(data)
        local max_len = 0
        for _, c in ipairs(data) do if #c.name > max_len then max_len = #c.name end end
        ui.show_menu(data, "Select Course", "course", function(choice)
            M.get_exercises(choice.name, nil, true)
        end, max_len)
    end)
end

function M.test()
    local bufnr = vim.api.nvim_get_current_buf()
    ui.clear_status(bufnr)
    ui.notify("Testing...", "info")
    system.run({ "test" }, function(obj)
        vim.schedule(function()
            local raw = (obj.stdout .. obj.stderr):lower()
            -- tmc test prints "Failed 'TestName'" on failure (note: space not colon)
            local has_failure = raw:match("failed '") ~= nil
                or raw:match("compilation failed") ~= nil
            -- Parse "Test results: X/Y tests passed"
            local p_str, t_str = raw:match("test results: (%d+)/(%d+)")
            local p, t = tonumber(p_str), tonumber(t_str)
            local test_ratio_ok = p and t and t > 0 and p == t
            local passed
            if has_failure then
                passed = false
            elseif raw:match("all tests passed") or test_ratio_ok then
                passed = true
            else
                passed = false
            end
            ui.show_virtual_status(bufnr, passed and "Tests Passed" or "Tests Failed", passed)
            if not passed then ui.show_log_window(obj.stdout .. obj.stderr) end
        end)
    end, get_project_root())
end

function M.submit()
    local bufnr = vim.api.nvim_get_current_buf()
    ui.clear_status(bufnr)
    ui.notify("Submitting...", "info")

    local user_env = vim.fn.environ()
    user_env.EDITOR = "cat"

    local log_buf, log_win = ui.create_live_log_window("Submitting to TMC...")
    local output = {}

    -- Resolve \r overwrites: split on \r, keep the last non-empty segment
    local function resolve_cr(raw_line)
        local s = raw_line:gsub("\x1b%[[%d;]*[A-Za-z]", "") -- strip ANSI
        local best = ""
        for seg in (s .. "\r"):gmatch("([^\r]*)\r") do
            local t = seg:gsub("%s+$", "")
            if t ~= "" then best = t end
        end
        if best == "" then best = s:gsub("%s+$", "") end
        return best:gsub("^%s+", "")
    end

    local function is_noise(line)
        return line == ""
            or line:match("^No Auto%-Updates")
            or line:match("^%d+%%%[")  -- progress bars: "50%[███░░] [00:00:01]"
    end

    local function flush(cleans)
        if #cleans == 0 then return end
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(log_buf) then
                vim.api.nvim_buf_set_lines(log_buf, -1, -1, false, cleans)
                if vim.api.nvim_win_is_valid(log_win) then
                    vim.api.nvim_win_set_cursor(log_win,
                        { vim.api.nvim_buf_line_count(log_buf), 0 })
                end
            end
        end)
    end

    vim.fn.jobstart({ config.bin or "tmc", "submit" }, {
        cwd = get_project_root(),
        -- No PTY: plain text output, no ANSI codes to deal with
        env = user_env,
        on_stdout = function(_, data)
            if not data then return end
            local cleans = {}
            for _, line in ipairs(data) do
                local clean = resolve_cr(line)
                if not is_noise(clean) then
                    table.insert(cleans, clean)
                    table.insert(output, clean)
                end
            end
            flush(cleans)
        end,
        on_stderr = function(_, data)
            if not data then return end
            local cleans = {}
            for _, line in ipairs(data) do
                local clean = resolve_cr(line)
                if not is_noise(clean) then
                    table.insert(cleans, clean)
                    table.insert(output, clean)
                end
            end
            flush(cleans)
        end,
        on_exit = function(_, _)
            vim.schedule(function()
                local raw = table.concat(output, "\n"):lower()

                -- Failure-first: "Failed: TestName: ..." is the explicit marker
                local has_failure = raw:match("failed:") ~= nil
                    or raw:match("compilation failed") ~= nil

                -- Parse "Test results: X/Y tests passed"
                local p_str, t_str = raw:match("test results: (%d+)/(%d+)")
                local p, t = tonumber(p_str), tonumber(t_str)
                local test_ratio_ok = p and t and t > 0 and p == t

                local passed
                if has_failure then
                    passed = false
                elseif raw:match("all tests passed") or test_ratio_ok then
                    passed = true
                else
                    passed = false
                end

                ui.show_virtual_status(bufnr, passed and "Submit Passed" or "Submit Failed", passed)
            end)
        end
    })
end

function M.login()
    vim.cmd("split | term export EDITOR=cat && " .. config.bin .. " login")
end

function M.doctor()
    -- Use `tmc courses` — it is non-interactive and fails with a clear message
    -- when the user is not logged in. `tmc organization` opens an interactive
    -- picker that blocks indefinitely in a non-TTY context.
    system.run({ "courses" }, function(obj)
        local output = (obj.stdout .. obj.stderr):lower()
        local logged = obj.code == 0
            and not output:match("login")
            and not output:match("error")
        vim.schedule(function()
            ui.notify(logged and "✓ Connected to TMC" or "✗ Auth Required — run :TmcLogin",
                logged and "info" or "warn")
        end)
    end)
end

function M.download_exercise(course, name)
    local target = config.exercises_dir .. "/" .. course
    if vim.fn.isdirectory(target) == 0 then vim.fn.mkdir(target, "p") end
    ui.notify("Downloading " .. name)
    system.run({ "download", "--course", course, "--currentdir" }, function(obj)
        vim.schedule(function() ui.notify(obj.code == 0 and "Download Done" or "Download Failed") end)
    end, target)
end

return M
