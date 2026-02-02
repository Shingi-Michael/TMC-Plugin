local system = require("tmc_plugin.system")
local ui = require("tmc_plugin.ui")
local config = require("tmc_plugin.config")

local M = {}

local function get_project_root()
    local current_dir = vim.fn.expand("%:p:h")
    if current_dir:match("src$") then
        return vim.fn.fnamemodify(current_dir, ":h")
    end
    return current_dir
end

local function parse_exercises(raw_lines)
    local cleaned = {}
    for _, line in ipairs(raw_lines) do
        if line ~= "" and not line:match("Auto%-Updates") then
            local is_completed = line:match("Completed:") ~= nil
            local name = line:match("Completed:%s*(.*)") or line:match(":%s*([^:]+)$") or line
            table.insert(cleaned, { name = vim.trim(name), completed = is_completed })
        end
    end
    return cleaned
end

-- NEW: The Doctor Command Logic
function M.doctor()
    print("Checking TMC Environment...")
    local report = { "\n=== TMC Doctor Report ===" }

    -- 1. Binary Check
    local bin_path = config.bin or "tmc"
    if vim.fn.executable(bin_path) == 1 then
        table.insert(report, "✓ Binary: Found (" .. bin_path .. ")")
    else
        table.insert(report, "✗ Binary: NOT FOUND.")
    end

    -- 2. Corrected Auth Check (Singular 'organization')
    system.run({ "organization" }, function(obj)
        vim.schedule(function()
            local output = (obj.stdout .. obj.stderr)
            local lower_out = output:lower()

            -- If logged out, TMC usually says "Authentication required"
            -- or "No logged in user".
            local is_logged_in = obj.code == 0
                and not lower_out:match("login")
                and not lower_out:match("unauthorized")
                and #output > 5 -- Logged out messages are usually very short

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

function M.get_courses()
    system.run({ "courses" }, function(obj)
        local raw_combined = vim.split(obj.stdout .. obj.stderr, "\n")
        local clean_courses = {}
        for _, line in ipairs(raw_combined) do
            if line ~= "" and not line:match("Auto%-Updates") then
                table.insert(clean_courses, line)
            end
        end
        vim.schedule(function()
            ui.show_menu(clean_courses, "Select Course", "course", function(choice)
                M.get_exercises(choice)
            end)
        end)
    end)
end

function M.get_exercises(course_name)
    system.run({ "exercises", course_name }, function(obj)
        local exercise_objects = parse_exercises(vim.split(obj.stdout .. obj.stderr, "\n"))
        vim.schedule(function()
            ui.show_menu(exercise_objects, "Exercises", "exercise", function(choice)
                if choice and choice.name then M.download_exercise(course_name, choice.name) end
            end)
        end)
    end)
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
    vim.cmd("split | terminal cd " .. vim.fn.shellescape(root) .. " && " .. config.bin .. " submit")
end

function M.login()
    vim.cmd("split | terminal " .. config.bin .. " login")
end

return M
