-- dashboard.lua
-- NOTE: We intentionally do NOT require("tmc_plugin.api") at the top level
-- to break the circular dependency (api.lua already requires this module).
-- Instead, api is accessed lazily via require() inside callbacks.
local ui = require("tmc_plugin.ui")
local config = require("tmc_plugin.config")
local system = require("tmc_plugin.system")

local M = {}
local NS_ID = vim.api.nvim_create_namespace("tmc_dashboard")
local BUF_NAME = "TMC_Dashboard"
local dashboard_buf = nil
local previous_win = nil              -- window that was focused before the dashboard opened
local current_course = nil
local exercise_data = {}
local is_loading = false
local keymaps_set = false              -- guard: only register keymaps once per buffer
local spinner_frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local spinner_idx = 1

-- ─── helpers ────────────────────────────────────────────────────────────────

local function get_project_root_for_exercise(exercise_name)
    -- tmc-cli (Rust) layout: <exercises_dir>/<course_name>/<exercise_name>
    return config.exercises_dir .. "/" .. current_course .. "/" .. exercise_name
end

local function create_buffer()
    if dashboard_buf and vim.api.nvim_buf_is_valid(dashboard_buf) then return dashboard_buf end
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, BUF_NAME)
    local opts = {
        buftype   = "nofile",
        bufhidden = "wipe",
        swapfile  = false,
        modifiable = false,
        filetype  = "tmc-dashboard",
    }
    for k, v in pairs(opts) do vim.bo[buf][k] = v end
    dashboard_buf = buf
    keymaps_set = false   -- new buffer → keymaps must be re-registered
    return buf
end

local function update_spinner()
    if not is_loading
        or not dashboard_buf
        or not vim.api.nvim_buf_is_valid(dashboard_buf) then return end
    vim.bo[dashboard_buf].modifiable = true
    local frame = spinner_frames[spinner_idx]
    vim.api.nvim_buf_set_lines(dashboard_buf, 0, 1, false, { " " .. frame .. " REFRESHING DATA..." })
    vim.bo[dashboard_buf].modifiable = false
    spinner_idx = (spinner_idx % #spinner_frames) + 1
    vim.defer_fn(update_spinner, 80)
end

-- Return the exercise entry that the cursor is currently on, or nil.
local function get_selected_exercise()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1] - 1   -- 0-indexed
    for _, ex in ipairs(exercise_data) do
        if ex.line == cursor_line then return ex end
    end
    return nil
end

-- ─── submit from dashboard ──────────────────────────────────────────────────

local function dashboard_submit(ex)
    if not ex then
        ui.notify("Place cursor on an exercise first", "warn")
        return
    end

    local exercise_dir = get_project_root_for_exercise(ex.name)

    -- Verify the directory actually exists before attempting a submit
    if vim.fn.isdirectory(exercise_dir) == 0 then
        ui.notify("Exercise not downloaded: " .. ex.name, "warn")
        return
    end

    ui.notify("Submitting " .. ex.name .. "...", "info")

    local user_env = vim.fn.environ()
    user_env.EDITOR = "cat"

    local log_buf, log_win = ui.create_live_log_window("Submitting: " .. ex.name)
    local output = {}

    -- Helper: given a raw chunk line, resolve \r overwrites and return the
    -- visible text (same as what the terminal would show after rendering).
    local function resolve_cr(raw_line)
        local s = raw_line:gsub("\x1b%[[%d;]*[A-Za-z]", "") -- strip ANSI
        local best = ""
        for seg in (s .. "\r"):gmatch("([^\r]*)\r") do
            local t = seg:gsub("%s+$", "") -- strip trailing whitespace
            if t ~= "" then best = t end
        end
        -- If no \r at all, just trim trailing whitespace
        if best == "" then best = s:gsub("%s+$", "") end
        return best:gsub("^%s+", "") -- strip leading whitespace
    end

    -- Helper: returns true for lines we don't want to show (progress bars, noise)
    local function is_noise(line)
        return line == ""
            or line:match("^No Auto%-Updates")
            or line:match("^%d+%%%[")  -- progress bars: "50%[███░░] [00:00:01]"
    end

    -- Helper: flush cleaned lines into the log buffer and scroll to bottom
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
        cwd = exercise_dir,
        -- No PTY: output is plain text, no ANSI codes, easier to process
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
            -- tmc prints "No Auto-Updates" to stderr; capture but filter same way
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

                -- ── Failure-first detection ───────────────────────────────────
                -- "Failed: TestName: reason" is the explicit failure marker
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
                    passed = false   -- safer default: no false positives
                end

                local label = ex.name .. " — " .. (passed and "All tests passed ✓" or "Tests failed ✗")
                if vim.api.nvim_buf_is_valid(log_buf) then
                    vim.api.nvim_buf_set_option(log_buf, "modifiable", true)
                    vim.api.nvim_buf_set_lines(log_buf, -1, -1, false, { "", label })
                    vim.api.nvim_buf_set_option(log_buf, "modifiable", false)
                end
                ui.notify(label, passed and "info" or "warn")
            end)
        end,
    })
end

-- ─── test from dashboard ────────────────────────────────────────────────────

local function dashboard_test(ex)
    if not ex then
        ui.notify("Place cursor on an exercise first", "warn")
        return
    end

    local exercise_dir = get_project_root_for_exercise(ex.name)

    if vim.fn.isdirectory(exercise_dir) == 0 then
        ui.notify("Exercise not downloaded: " .. ex.name, "warn")
        return
    end

    ui.notify("Testing " .. ex.name .. "...", "info")

    system.run({ "test" }, function(obj)
        vim.schedule(function()
            local raw = (obj.stdout .. obj.stderr):lower()
            -- tmc test prints "Failed 'TestName'" on failure (space, not colon)
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
            local label = ex.name .. " — " .. (passed and "Tests Passed ✓" or "Tests Failed ✗")
            ui.notify(label, passed and "info" or "warn")
            if not passed then
                ui.show_log_window(obj.stdout .. obj.stderr)
            end
        end)
    end, exercise_dir)
end

-- ─── public API ─────────────────────────────────────────────────────────────

function M.render(course_name, exercises)
    is_loading = false
    local buf = create_buffer()
    current_course = course_name
    exercise_data = {}

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_clear_namespace(buf, NS_ID, 0, -1)

    local done = 0
    for _, ex in ipairs(exercises) do if ex.completed then done = done + 1 end end
    local pct = #exercises > 0 and math.floor((done / #exercises) * 100) or 0

    local lines = {
        " " .. course_name:upper(),
        " " .. string.rep("═", #course_name),
        "",
        " Progress: " .. ui.make_progress_bar(pct),
        "",
        " Exercises:",
        " " .. string.rep("─", 30),
    }

    local offset = #lines
    for i, ex in ipairs(exercises) do
        local status = ex.completed and "[x]" or "[ ]"
        table.insert(lines, string.format(" %s %s", status, ex.name))
        table.insert(exercise_data, { name = ex.name, completed = ex.completed, line = offset + i - 1 })
    end

    table.insert(lines, "")
    table.insert(lines, " [Enter] Open  [t] Test  [d] Download  [s] Submit  [r] Refresh  [q] Close")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

    for _, ex in ipairs(exercise_data) do
        local hl = ex.completed and "TmcSuccess" or "TmcFailure"
        vim.api.nvim_buf_add_highlight(buf, NS_ID, hl, ex.line, 1, 4)
    end

    vim.bo[buf].modifiable = false

    if vim.fn.bufwinid(buf) == -1 then
        previous_win = vim.api.nvim_get_current_win()  -- remember the caller's window
        vim.cmd("vsplit")
        vim.api.nvim_win_set_buf(0, buf)
    end

    -- Only register keymaps once per buffer lifetime to avoid stacking
    if not keymaps_set then
        M.setup_keymaps(buf)
        keymaps_set = true
    end
end

function M.setup_keymaps(buf)
    local opts = { buffer = buf, noremap = true, silent = true }

    -- [Enter] → open the exercise source file in the previous (main) window
    vim.keymap.set("n", "<CR>", function()
        local ex = get_selected_exercise()
        if not ex then
            ui.notify("Place cursor on an exercise first", "warn")
            return
        end
        local exercise_dir = get_project_root_for_exercise(ex.name)

        -- Helper: find first editable source file under a directory
        local skip = { pyc=true, class=true, o=true, beam=true, hi=true }
        local function find_src(dir)
            local src_sub = dir .. "/src"
            local search = vim.fn.isdirectory(src_sub) == 1 and src_sub or dir
            for _, f in ipairs(vim.fn.glob(search .. "/**/*", false, true)) do
                local ext = f:match("%.(%a+)$")
                if ext and not skip[ext] and vim.fn.isdirectory(f) == 0 then
                    return f
                end
            end
        end

        local function open_in_prev_win(src)
            local target = (previous_win and vim.api.nvim_win_is_valid(previous_win))
                and previous_win or vim.api.nvim_get_current_win()
            
            local dash_win = vim.fn.bufwinid(dashboard_buf)
            local is_dash_win_target = (dash_win ~= -1 and target == dash_win)

            if not is_dash_win_target then
                vim.api.nvim_set_current_win(target)
            end
            
            vim.cmd("edit " .. vim.fn.fnameescape(src))
            
            -- Explicitly close the dashboard window if it's a split
            if dash_win ~= -1 and #vim.api.nvim_list_wins() > 1 then
                pcall(vim.api.nvim_win_close, dash_win, true)
            end
            
            dashboard_buf = nil
            keymaps_set = false
            ui.notify("Opened " .. ex.name, "info")
        end

        if vim.fn.isdirectory(exercise_dir) == 0 then
            -- Not downloaded — download then open
            require("tmc_plugin.api").download_exercise(current_course, ex.name, function()
                local src = find_src(exercise_dir)
                if src then
                    vim.schedule(function() open_in_prev_win(src) end)
                else
                    ui.notify("No source file found in " .. ex.name, "warn")
                end
            end)
            return
        end

        local src = find_src(exercise_dir)
        if src then
            vim.schedule(function() open_in_prev_win(src) end)
        else
            ui.notify("No source file found in " .. ex.name, "warn")
        end
    end, opts)

    -- [t] → test the exercise under the cursor
    vim.keymap.set("n", "t", function()
        dashboard_test(get_selected_exercise())
    end, opts)

    -- [d] → download the exercise under the cursor
    vim.keymap.set("n", "d", function()
        local ex = get_selected_exercise()
        if ex and current_course then
            require("tmc_plugin.api").download_exercise(current_course, ex.name)
        else
            ui.notify("Place cursor on an exercise first", "warn")
        end
    end, opts)

    -- [s] → submit the exercise under the cursor
    vim.keymap.set("n", "s", function()
        dashboard_submit(get_selected_exercise())
    end, opts)

    -- [r] → refresh course data
    vim.keymap.set("n", "r", function()
        if is_loading then return end
        is_loading = true
        update_spinner()
        local api = require("tmc_plugin.api")
        api.get_courses(function()
            api.get_exercises(current_course, nil, true)
        end, true)
    end, opts)

    -- [q] → close the dashboard
    vim.keymap.set("n", "q", function()
        if dashboard_buf and vim.api.nvim_buf_is_valid(dashboard_buf) then
            vim.api.nvim_buf_delete(dashboard_buf, { force = true })
        end
        dashboard_buf = nil
        keymaps_set = false
    end, opts)
end

-- Separate namespace so the nav flash doesn't disturb dashboard render highlights
local NS_NAV = vim.api.nvim_create_namespace("tmc_dashboard_nav")

-- Called by :TmcNext / :TmcPrev after opening a new exercise.
-- Scrolls the dashboard (if open) to the exercise line and flashes a highlight.
function M.scroll_to_exercise(exercise_name)
    if not dashboard_buf or not vim.api.nvim_buf_is_valid(dashboard_buf) then return end
    local win = vim.fn.bufwinid(dashboard_buf)
    if win == -1 then return end  -- dashboard buffer exists but no window is showing it
    for _, ex in ipairs(exercise_data) do
        if ex.name == exercise_name then
            -- ex.line is 0-based; nvim_win_set_cursor wants 1-based
            pcall(vim.api.nvim_win_set_cursor, win, { ex.line + 1, 0 })
            -- Flash highlight on the exercise row
            vim.api.nvim_buf_clear_namespace(dashboard_buf, NS_NAV, 0, -1)
            vim.api.nvim_buf_add_highlight(dashboard_buf, NS_NAV, "CursorLine", ex.line, 0, -1)
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(dashboard_buf) then
                    vim.api.nvim_buf_clear_namespace(dashboard_buf, NS_NAV, 0, -1)
                end
            end, 1500)
            return
        end
    end
end

return M
