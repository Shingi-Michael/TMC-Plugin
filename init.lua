local M = {}
local config = require("tmc_plugin.config")

function M.setup(opts)
    opts = opts or {}
    config.bin = opts.bin or "tmc"

    -- Create user commands for easier access
    vim.api.nvim_create_user_command("TmcDoctor", function()
        require("tmc_plugin.api").doctor()
    end, {})

    print("TMC Ready: Run :TmcDoctor to check your setup.")
end

return M
