local system = require("tmc_plugin.system")
local ui = require("tmc_plugin.ui")
local config = require("tmc_plugin.config")

local M = {}

-- Helper: Find project root
local function get_project_root()
    local current_dir = vim.fn.expand("%:p:h")
    if current_dir:match("src$") then
        return vim.fn.fnamemodify(current_dir, ":h")
    end
    return current_dir
end

-- Helper: Robust parsing of the CLI output
local function parse_exercises(raw_lines)
    local cleaned = {}
    for _, line in ipairs(raw_lines) do
        if line ~= ""
            and not line:match("Auto%-Updates")
            and not line:match("Fetching")
            and not line:match("Organization")
            and not line:match("exercises for course") then
            local is_completed = line:match("Completed:") ~= nil
            local name = line:gsub("Completed:%s*", "")
            name = name:gsub("^%s*[%[%]%sx]*%s*", "")
            name = vim.trim(name)

            if #name > 0 then
                table.insert(cleaned, { name = name, completed = is_completed })
            end
        end
    end
    return cleaned
end

--- === CORE API FUNCTIONS === ---

function M.doctor()
    print("Checking TMC Environment...")
    local report = { "\n=== TMC Doctor Report ===" }

    local bin_path = config.bin or "tmc"
    if vim.fn.executable(bin_path) == 1 then
        table.insert(report, "✓ Binary: Found (" .. bin_path .. ")")
    else
        table.insert(report, "✗ Binary: NOT FOUND.")
    end

    system.run({ "organization" }, function(obj)
        vim.schedule(function()
            local output = (obj.stdout .. obj.stderr)
            local lower_out = output:lower()
            local is_logged_in = obj.code == 0
                and not lower_out:match("login")
                and not lower_out:match("unauthorized")
                and #output > 5

            if is_logged_in then
                table.insert(report, "✓ Auth: Logged in (Session active).")
            else
                table.insert(report, "✗ Auth: Not logged in.")
                table.insert(report, "  (Run :TmcLogin to authenticate)")
            end
            print(table.concat(report, "\n"))
        end)
    end)
end

M.is_online = true
local health_timer = vim.uv.new_timer()

function M.init_health_watcher()
    if config.bin == nil then return end
    if health_timer:is_active() then health_timer:stop() end

    health_timer:start(0, 90000, function()
        local handle
        handle = vim.uv.spawn(config.bin, { args = { "organization" } }, function(code)
            if code == 0 then
                vim.schedule(function() M.is_online = true end)
            else
                vim.schedule(function() M.is_online = false end)
            end
            if handle then handle:close() end
        end)

        if not handle then M.is_online = false end
    end)
end

function M.get_courses()
    system.run({ "courses" }, function(obj)
        local raw_combined = vim.split(obj.stdout .. obj.stderr, "\n")
        local clean_courses = {}
        for _, line in ipairs(raw_combined) do
            if line ~= "" and not line:match("Auto%-Updates") and not line:match("Organization") then
                table.insert(clean_courses, vim.trim(line))
            end
        end
        vim.schedule(function()
            if #clean_courses == 0 then
                vim.notify("No courses found. Check :TmcDoctor", vim.log.levels.WARN)
                return
            end
            ui.show_menu(clean_courses, "Select Course", "course", function(choice)
                if choice then M.get_exercises(choice) end
            end)
        end)
    end)
end

function M.get_exercises(course_name)
    system.run({ "exercises", course_name }, function(obj)
        local raw_lines = vim.split(obj.stdout .. obj.stderr, "\n")
        local cleaned_data = parse_exercises(raw_lines)

        local exercise_names = {}
        for _, ex in ipairs(cleaned_data) do
            table.insert(exercise_names, ex.name)
        end

        vim.schedule(function()
            if #exercise_names == 0 then
                vim.notify("No exercises found for: " .. course_name, vim.log.levels.WARN)
                return
            end
            ui.show_menu(exercise_names, "Select Exercise", "exercise", function(exercise_name)
                if exercise_name then M.download_exercise(course_name, exercise_name) end
            end)
        end)
    end)
end

function M.show_local_exercises()
    local base_path = vim.fn.expand("$HOME/tmc_exercises")
    if vim.fn.isdirectory(base_path) == 0 then
        vim.notify("No exercises downloaded yet.", vim.log.levels.WARN)
        return
    end

    local courses = vim.fn.readdir(base_path)

    ui.show_menu(courses, "Pick Course", "course", function(course)
        if not course then return end
        local course_path = base_path .. "/" .. course
        local local_exercises = vim.fn.readdir(course_path)

        ui.show_menu(local_exercises, "Go to Exercise", "exercise", function(exercise)
            if not exercise then return end
            local target = course_path .. "/" .. exercise

            vim.schedule(function()
                -- Move the editor to the target directory
                vim.api.nvim_set_current_dir(target)

                -- Find and open source files WITHOUT spawning new terminals
                local src_files = vim.fn.glob(target .. "/src/**/*.*", false, true)
                if #src_files > 0 then
                    vim.cmd("edit " .. vim.fn.fnameescape(src_files[1]))
                else
                    vim.cmd("Explore")
                end

                vim.notify("Focus shifted to: " .. exercise)
            end)
        end)
    end)
end

function M.download_exercise(course_name, exercise_name)
    local base_path = vim.fn.expand("$HOME/tmc_exercises")
    local target_path = base_path .. "/" .. course_name

    if vim.fn.isdirectory(target_path) == 0 then
        vim.fn.mkdir(target_path, "p")
    end

    vim.notify("TMC: Downloading...", vim.log.levels.INFO)

    local args = { "download", "--course", course_name, "--currentdir" }

    system.run(args, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                vim.notify("󰄬 Download Complete", vim.log.levels.INFO)
                -- Navigate to local exercises instead of opening a terminal
                M.show_local_exercises()
            else
                vim.notify("󰅙 Download failed", vim.log.levels.ERROR)
                ui.show_log_window(obj.stdout .. obj.stderr)
            end
        end)
    end, target_path)
end

function M.test()
    local bufnr = vim.api.nvim_get_current_buf()
    local root = get_project_root()
    ui.clear_status(bufnr)
    ui.notify("Testing...", "info")

    system.run({ "test" }, function(obj)
        vim.schedule(function()
            local out = (obj.stdout .. obj.stderr):lower()
            local passed = out:match("all tests passed") ~= nil
            local no_tests = out:match("0 tests run") ~= nil or out:match("no tests found") ~= nil

            if passed and not no_tests then
                ui.show_virtual_status(bufnr, "TMC: Passed", true)
            else
                ui.show_virtual_status(bufnr, "TMC: Failed", false)
                ui.show_log_window(obj.stdout .. obj.stderr)
            end
        end)
    end, root)
end

function M.submit()
    local root = get_project_root()
    -- Use a clean split for terminal, but prevent nested nvim by clearing $EDITOR
    vim.cmd("split | term export EDITOR=cat && cd " .. vim.fn.shellescape(root) .. " && " .. config.bin .. " submit")
end

function M.login()
    -- Use a clean split for login
    vim.cmd("split | term export EDITOR=cat && " .. config.bin .. " login")
end

return M
