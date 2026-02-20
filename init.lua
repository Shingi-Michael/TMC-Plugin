local M = {}
local config = require("tmc_plugin.config")

function M.setup(opts)
    opts = opts or {}
    config.bin = opts.bin or "tmc"

    local commands = {
        TmcMenu    = "open_main_menu",
        TmcTest    = "test",
        TmcSubmit  = "submit",
        TmcStatus  = "show_progress_flow",
        TmcCourses = "start_download_flow",
        TmcDoctor  = "doctor",
        TmcLogin   = "login",
    }

    for cmd_name, api_func in pairs(commands) do
        vim.api.nvim_create_user_command(cmd_name, function()
            require("tmc_plugin.api")[api_func]()
        end, { desc = "TMC Command" })
    end
end

return M
