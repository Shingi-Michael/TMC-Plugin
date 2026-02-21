local M = {}
local config = require("tmc_plugin.config")

function M.setup(opts)
    opts = opts or {}
    config.bin = opts.bin or "tmc"
    -- Allow the user to override where tmc-cli stores downloaded exercises.
    -- Defaults to the native Rust CLI path on macOS.
    if opts.exercises_dir then
        config.exercises_dir = vim.fn.expand(opts.exercises_dir)
    end
    local commands = {
        TmcMenu      = "menu",
        TmcDashboard = "open_dashboard",
        TmcTest      = "test",
        TmcSubmit    = "submit",
        TmcDoctor    = "doctor",
        TmcLogin     = "login",
        TmcNext      = "next",
        TmcPrev      = "prev",
    }
    for cmd_name, api_func in pairs(commands) do
        vim.api.nvim_create_user_command(cmd_name, function()
            if cmd_name == "TmcMenu" then
                require("tmc_plugin.menu").open()
            else
                require("tmc_plugin.api")[api_func]()
            end
        end, { desc = "TMC: " .. api_func })
    end
end

return M
