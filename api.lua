local system = require("tmc_plugin.system")

local M = {}


function M.get_version()
    system.run({ "--version" }, function(obj)
        print(obj.stdout)
    end)
end

-- function to allow user to login
function M.login()
    local bin = require("tmc_plugin.config").options.bin

    vim.cmd("split")

    vim.cmd.terminal(bin .. " login")

    vim.cmd("startinsert")
end

-- function to allow user to logout
function M.logout()
    local bin = require("tmc_plugin.config").options.bin

    vim.cmd("split")

    vim.cmd.terminal(bin .. " logout")
end

function M.set_organizations()
    local bin = require("tmc_plugin.config").options.bin
    vim.cmd("split")
    vim.cmd.terminal(bin .. " organization")
    vim.cmd("startinsert")
end

function M.get_courses()
    system.run({ "courses" }, function(obj)
        local raw_data = obj.stdout .. obj.stderr
        local raw_combined = vim.split(raw_data, "\n")
        local clean_courses = {}

        for _, line in ipairs(raw_combined) do
            if line ~= "" and not line:match("Auto%-Updates") then
                table.insert(clean_courses, line)
            end
        end
        vim.schedule(function()
            vim.ui.select(clean_courses, {
                prompt = "Select a TMC Course:",
            }, function(choice)
                print("Telescope gave me " .. tostring(choice))
                if choice then
                    M.get_exercises(choice)
                    -- This is where we will eventually call M.get_exercises(choice)
                else
                    print("Selection cancelled")
                end
            end)
        end)
    end)
end

function M.get_exercises(course_name)
    if not course_name then
        print("Error: No course provided to get_exercises")
        return
    end

    local prompt_text = "Exercises for: "

    local target_course = course_name

    system.run({ "exercises", target_course }, function(obj)
        local raw_data = obj.stdout .. obj.stderr
        local raw_combined = vim.split(raw_data, "\n")
        local cleaned_exercises = {}

        for _, lines in ipairs(raw_combined) do
            if lines ~= "" and not lines:match("Auto%-Updates") then
                table.insert(cleaned_exercises, lines)
            end
        end

        vim.schedule(function()
            vim.ui.select(cleaned_exercises, {
                prompt = prompt_text .. course_name .. ":"
            }, function(choice)
                if choice then
                    M.download_exercise(target_course, choice)
                else
                    print("Selection Cancelled")
                end
            end)
        end)
    end)
end

function M.download_exercise(course_name, exercise_name)
    local c_name = course_name
    local e_name = exercise_name

    print("Downloading course exercises for: " .. c_name)

    system.run({ "download", "-c", c_name }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                print("Successfully downloaded course: " .. c_name)
            else
                print("Download failed. See TMC OUTPUT.")
                if obj.stderr ~= "" then
                    print("TMC OUTPUT: " .. obj.stderr)
                end
            end
        end)
    end)
end

function M.test()
    local bin = require("tmc_plugin.config").options.bin

    vim.cmd("split")

    vim.cmd.terminal(bin .. " test")

    vim.cmd("startinsert")
end

function M.submit()
    local bin = require("tmc_plugin.config").options.bin

    vim.cmd("split")

    vim.cmd.terminal(bin .. " submit")

    vim.cmd("startinsert")
end

return M
