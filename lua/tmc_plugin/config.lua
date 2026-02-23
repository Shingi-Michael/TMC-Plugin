local M = {}

local os_name = vim.loop.os_uname().sysname
local is_windows = os_name == "Windows_NT"
local is_mac = os_name == "Darwin"

M.bin = nil -- set by setup()

-- Default exercises root used by the native tmc-cli (Rust).
-- Resolves path based on Operating System.
local function get_default_exercises_dir()
    if is_windows then
        -- Native TMC CLI on Windows
        local appdata = os.getenv("LOCALAPPDATA") or os.getenv("APPDATA") or vim.fn.expand("~\\AppData\\Local")
        return vim.fn.expand(appdata .. "\\tmc\\tmc_cli_rust")
    elseif is_mac then
        return vim.fn.expand("$HOME/Library/Application Support/tmc/tmc_cli_rust")
    else
        -- Linux / Unix fallback
        local xdg_data = os.getenv("XDG_DATA_HOME")
        if xdg_data and xdg_data ~= "" then
            return vim.fn.expand(xdg_data .. "/tmc/tmc_cli_rust")
        else
            return vim.fn.expand("$HOME/.local/share/tmc/tmc_cli_rust")
        end
    end
end

M.exercises_dir = get_default_exercises_dir()

-- MOOC.fi course site base URL used to fetch exercise instructions.
M.mooc_url = "https://programming-25.mooc.fi"

return M
