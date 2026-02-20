local system = require("tmc_plugin.system")
local ui = require("tmc_plugin.ui")
local config = require("tmc_plugin.config")

local M = {}

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

function M.get_courses(on_select)
    ui.notify("Syncing course data...", "info")
    system.run({ "courses" }, function(obj)
        local raw = vim.split(obj.stdout .. obj.stderr, "\n")
        local names = {}
        for _, line in ipairs(raw) do
            if line ~= "" and not line:match("Auto%-") and not line:match("Organization") then
                table.insert(names, vim.trim(line))
            end
        end

        local results = {}
        local count = 0
        local max_len = 0

        -- Determine longest name first
        for _, n in ipairs(names) do if #n > max_len then max_len = #n end end

        for _, name in ipairs(names) do
            system.run({ "exercises", name }, function(ex_obj)
                local exs = parse_exercises(vim.split(ex_obj.stdout .. ex_obj.stderr, "\n"))
                local done = 0
                for _, e in ipairs(exs) do if e.completed then done = done + 1 end end
                local pct = #exs > 0 and math.floor((done / #exs) * 100) or 0

                table.insert(results, { name = name, progress_str = ui.make_progress_bar(pct) })
                count = count + 1

                if count == #names then
                    vim.schedule(function()
                        ui.show_menu(results, "TMC Courses", "course", function(choice)
                            on_select(choice.name)
                        end, max_len)
                    end)
                end
            end)
        end
    end)
end

function M.get_exercises(course_name, on_select)
    system.run({ "exercises", course_name }, function(obj)
        local cleaned = parse_exercises(vim.split(obj.stdout .. obj.stderr, "\n"))
        vim.schedule(function() ui.show_menu(cleaned, "Exercises", "exercise", on_select) end)
    end)
end

function M.open_main_menu()
    local opts = {
        { label = "Run Tests",       action = "test" },
        { label = "Submit Exercise", action = "submit" },
        { label = "Course Progress", action = "show_progress_flow" },
        { label = "Download New",    action = "start_download_flow" },
        { label = "TMC Login",       action = "login" },
        { label = "TMC Doctor",      action = "doctor" },
    }
    local labels = {}
    for _, o in ipairs(opts) do table.insert(labels, o.label) end
    ui.show_menu(labels, "Main Menu", "menu", function(choice)
        for _, o in ipairs(opts) do if o.label == choice then
                M[o.action]()
                break
            end end
    end)
end

function M.show_progress_flow()
    M.get_courses(function(course)
        M.get_exercises(course, function(ex)
            ui.notify(ex.name .. ": " .. (ex.completed and "Completed" or "Pending"))
        end)
    end)
end

function M.start_download_flow()
    M.get_courses(function(course)
        M.get_exercises(course, function(ex) M.download_exercise(course, ex.name) end)
    end)
end

function M.test()
    local bufnr = vim.api.nvim_get_current_buf()
    ui.clear_status(bufnr)
    ui.notify("Running local tests...", "info")
    system.run({ "test" }, function(obj)
        vim.schedule(function()
            local out = (obj.stdout .. obj.stderr):lower()
            local passed = out:match("all tests passed") ~= nil
            ui.show_virtual_status(bufnr, passed and "Passed" or "Failed", passed)
            if not passed then ui.show_log_window(obj.stdout .. obj.stderr) end
        end)
    end, get_project_root())
end

function M.submit()
    local root = get_project_root()
    vim.cmd("split | term export EDITOR=cat && cd " .. vim.fn.shellescape(root) .. " && " .. config.bin .. " submit")
end

function M.login()
    vim.cmd("split | term export EDITOR=cat && " .. config.bin .. " login")
end

function M.doctor()
    system.run({ "organization" }, function(obj)
        local logged = obj.code == 0 and not (obj.stdout .. obj.stderr):lower():match("login")
        ui.notify(logged and "Connected to TMC" or "Auth Failed", logged and "info" or "error")
    end)
end

function M.download_exercise(course, name)
    local target = vim.fn.expand("$HOME/tmc_exercises/") .. course
    if vim.fn.isdirectory(target) == 0 then vim.fn.mkdir(target, "p") end
    ui.notify("Downloading " .. name, "info")
    system.run({ "download", "--course", course, "--currentdir" }, function(obj)
        vim.schedule(function() ui.notify(obj.code == 0 and "Download Complete" or "Download Failed") end)
    end, target)
end

return M
