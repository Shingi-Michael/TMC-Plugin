local M = {}
local config = require("tmc_plugin.config")

function M.setup(opts)
    opts = opts or {}
    config.bin = opts.bin or "tmc"

    -- Register all commands from your README
    local commands = {
        TmcDoctor  = "doctor",
        TmcLogin   = "login",
        TmcTest    = "test",
        TmcSubmit  = "submit",
        TmcCourses = "get_courses",
    }

    for cmd_name, api_func in pairs(commands) do
        vim.api.nvim_create_user_command(cmd_name, function()
            require("tmc_plugin.api")[api_func]()
        end, {})
    end

    print("TMC Ready: Run :TmcDoctor to check your setup.")
end

return M
