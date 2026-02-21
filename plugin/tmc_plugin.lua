-- plugin/tmc_plugin.lua
-- This file is auto-sourced by Neovim on startup (no setup() call required).
-- Calling require("tmc_plugin").setup() in your config is still supported
-- and lets you customise the binary path and exercises directory.

-- Register commands with defaults immediately so the plugin works out of
-- the box even if the user never calls setup().
local ok, api = pcall(require, "tmc_plugin.api")
if not ok then return end  -- fail silently if plugin not yet loaded

-- Ensure config has sensible defaults even if setup() was never called
local cfg = require("tmc_plugin.config")
if not cfg.bin then cfg.bin = "tmc" end

local commands = {
    TmcDashboard = "open_dashboard",
    TmcTest      = "test",
    TmcSubmit    = "submit",
    TmcDoctor    = "doctor",
    TmcLogin     = "login",
}

for cmd_name, api_func in pairs(commands) do
    if vim.fn.exists(":" .. cmd_name) == 0 then
        vim.api.nvim_create_user_command(cmd_name, function()
            require("tmc_plugin.api")[api_func]()
        end, { desc = "TMC: " .. api_func })
    end
end
