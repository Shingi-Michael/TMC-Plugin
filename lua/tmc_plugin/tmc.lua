-- Implement the creation of a menu using telescope
-- Display a list of items i.e files and interact with them by selecting and searching
local pickers      = require("telescope.pickers")
-- Provide a list of selectable items with this function
local finders      = require("telescope.finders")
-- This function matches and ranks input to the list of items you have
local sorters      = require("telescope.sorters")
-- This function tells telescope what to do when the user selects an Item
local actions      = require("telescope.actions")
-- Access selected items, typed input and or raw data from tables. This is the bridge between the UI and the Lua logic
local action_state = require("telescope.actions.state")

local func         = require("vim.func")

local Job          = require("plenary.job")

local tmc          = require("tmc_plugin")

local function get_binary_path()
    return tmc._config.binary_path or vim.env.HOME .. "/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"
end

-- Define menu options
local options = {
    "❓Help",
    "🧪 Test",
    "✅ Submit",
    "📒Courses",
    "🔻Download Courses",
    "🔐Login",
    "🚪Logout",

}

vim.api.nvim_create_user_command("Ttmc", function()
    local tmc_binary = get_binary_path()
    local exercise_path = vim.fn.expand("%:p:h:h")

    -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
    local shell_cmd = string.format(
        'exec %s test "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read',
        tmc_binary,
        exercise_path
    )

    vim.cmd("split")
    vim.cmd("terminal " .. shell_cmd)
    vim.cmd("startinsert")
end, { desc = 'Run TMC submit without "Process exited" message' })

-- Login feature for initial tmc sign-in.
-- Use tmc binary only of login
vim.api.nvim_create_user_command("Ltmc", function()
    local tmc_binary = get_binary_path()

    local shell_cmd = string.format(
        'exec %s login && echo "" && echo "Press ENTER twice to exit..." && read && read',
        tmc_binary
    )

    vim.cmd("split")
    vim.cmd("terminal " .. shell_cmd)
    vim.cmd("startinsert")
end, { desc = 'Run TMC login without "Process exited" message' })

-- Logout feature for tmc
-- Use tmc binary only for logout
vim.api.nvim_create_user_command("Otmc", function()
    local tmc_binary = get_binary_path()

    local shell_cmd = string.format(
        'exec %s logout && echo "" && echo "Press ENTER twice to exit..." && read && read',
        tmc_binary
    )

    vim.cmd("split")
    vim.cmd("terminal " .. shell_cmd)
    vim.cmd("startinsert")
end, { desc = 'Run TMC logout without "Process exited" message' })

vim.api.nvim_create_user_command("Stmc", function()
    local tmc_binary = get_binary_path()
    local exercise_path = vim.fn.expand("%:p:h:h")

    -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
    local shell_cmd = string.format(
        'exec %s submit "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read',
        tmc_binary,
        exercise_path
    )

    vim.cmd("split")
    vim.cmd("terminal " .. shell_cmd)
    vim.cmd("startinsert")
end, { desc = 'Run TMC submit without "Process exited" message' })

vim.api.nvim_create_user_command("Htmc", function()
    local tmc_binary = get_binary_path()
    local exercise_path = vim.fn.expand("%:p:h:h")

    -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
    local shell_cmd = string.format(
        'exec %s --help "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read',
        tmc_binary,
        exercise_path
    )

    vim.cmd("split")
    vim.cmd("terminal " .. shell_cmd)
    vim.cmd("startinsert")
end, { desc = 'Run TMC submit without "Process exited" message' })

-- Create a function that has access to courses and displays them in telescope

local function select_course_to_download()
    Job:new({
        command = get_binary_path(),
        args = { 'courses' },
        enable_recording = true,
        on_exit = function(j)
            local stderr = j:stderr_result()
            local stdout = j:result()

            local courses = {}

            -- stderr sometimes contains useful output, so we check both
            for _, line in ipairs(stdout) do
                if line ~= "" then
                    table.insert(courses, line)
                end
            end
            for _, line in ipairs(stderr) do
                if line ~= "" then
                    table.insert(courses, line)
                end
            end

            vim.schedule(function()
                pickers.new({}, {
                    prompt_title = "Download a Course",
                    finder = finders.new_table({
                        results = courses,
                    }),
                    sorter = sorters.get_fzy_sorter(),
                    attach_mappings = function(prompt_bufnr, map)
                        actions.select_default:replace(function()
                            actions.close(prompt_bufnr)
                            local selection = action_state.get_selected_entry()

                            if selection then
                                local course_name = selection.value
                                local shell_cmd = string.format(
                                    'exec %s download --course "%s" && echo "" && echo "Press ENTER to exit..." && read && read',
                                    get_binary_path(),
                                    course_name
                                )
                                vim.cmd("split")
                                vim.cmd("terminal " .. shell_cmd)
                                vim.cmd("startinsert")
                            end
                        end)
                        return true
                    end,
                }):find()
            end)
        end,
    }):start()
end

vim.api.nvim_create_user_command('Dlist', function()
    select_course_to_download()
end, {})


local function list_courses()
    Job:new({
        command = vim.env.HOME .. "/tmc-cli-rust-x86_64-apple-darwin-v1.1.2",
        args = { 'courses' },
        enable_recording = true,
        on_exit = function(j)
            local stderr = j:stderr_result()
            local stdout = j:result()

            clean_courses = {}

            for _, line in ipairs(stderr) do
                if line ~= "" then
                    table.insert(clean_courses, line)
                end
            end

            vim.schedule(function()
                pickers.new({}, {
                    prompt_title = "Courses List",
                    finder = finders.new_table({
                        results = clean_courses,
                    }),
                    sorter = sorters.get_fzy_sorter(),
                }):find()
            end)
        end,
    }):start()
end

vim.api.nvim_create_user_command('Tlist', function()
    list_courses()
end, {})

-- Create a function for the menu
local function create_Menu()
    pickers
        .new({}, {
            prompt_title = "TMC-Menu",
            finder = finders.new_table({
                results = options,
            }),
            sorter = sorters.get_fzy_sorter(),
            layout_config = {
                width = 0.4,
                height = 0.45,
            },
            attach_mappings = function(prompt_bufnr, map)
                actions.select_default:replace(function()
                    actions.close(prompt_bufnr)
                    local selection = action_state.get_selected_entry()

                    if not selection then
                        return
                    end

                    if selection.value == "🧪 Test" then
                        vim.cmd("Ttmc")
                    elseif selection.value == "✅ Submit" then
                        vim.cmd("Stmc")
                    elseif selection.value == "❓Help" then
                        vim.cmd("Htmc")
                    elseif selection.value == "📒Courses" then
                        vim.cmd("Tlist")
                    elseif selection.value == "🔻Download Courses" then
                        vim.cmd("Dlist")
                    elseif selection.value == "🔐 Login" then
                        vim.cmd("Ltmc")
                    elseif selection.value == "🚪Logout" then
                        vim.cmd("Otmc")
                    end
                end)
                return true
            end,
        })
        :find()
end

vim.api.nvim_create_user_command("TMenu", create_Menu, { desc = "Open TMC Menu" })
