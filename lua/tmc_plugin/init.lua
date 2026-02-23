local M = {}
local config = require("tmc_plugin.config")

local function setup_breadcrumbs()
    if vim.fn.has("nvim-0.8") == 0 then return end
    vim.api.nvim_set_hl(0, "TmcBreadcrumbRoot", { fg = "#cba6f7", bold = true, default = true })
    vim.api.nvim_set_hl(0, "TmcBreadcrumbSep", { fg = "#6c7086", default = true })
    vim.api.nvim_set_hl(0, "TmcBreadcrumbCourse", { fg = "#89b4fa", default = true })
    vim.api.nvim_set_hl(0, "TmcBreadcrumbExercise", { fg = "#f9e2af", italic = true, default = true })

    vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("TmcBreadcrumbs", { clear = true }),
        callback = function(args)
            if vim.bo[args.buf].buftype ~= "" then return end
            -- Ensure safe scheduling for UI updates
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(args.buf) then return end
                local path = vim.api.nvim_buf_get_name(args.buf)
                local base = vim.fn.expand(config.exercises_dir)
                if path:sub(1, #base) == base then
                    local rest = path:sub(#base + 2)
                    local course, exercise = rest:match("^([^/\\]+)[/\\]([^/\\]+)")
                    if course and exercise then
                        local c_name = course:gsub("-", " "):gsub("^%l", string.upper)
                        local e_name = exercise:gsub("^[%w]+%-[%w]+_", ""):gsub("_", " ")
                        if #e_name > 0 then e_name = e_name:sub(1,1):upper() .. e_name:sub(2) else e_name = exercise end
                        
                        local part = exercise:match("^([^%-]+)")
                        local part_num = part and part:match("%d+")
                        local section = part_num and ("Part " .. tonumber(part_num) .. " - ") or ""
                        
                        local winbar_str = "  %#TmcBreadcrumbRoot#󰮫 TMC%* %#TmcBreadcrumbSep#  %* %#TmcBreadcrumbCourse#" .. c_name .. "%* %#TmcBreadcrumbSep#  %* %#TmcBreadcrumbExercise#" .. section .. e_name .. "%*"
                        
                        pcall(function() vim.wo.winbar = winbar_str end)
                    end
                end
            end)
        end
    })
end

function M.setup(opts)
    opts = opts or {}
    config.bin = opts.bin or "tmc"
    -- Allow the user to override where tmc-cli stores downloaded exercises.
    -- Defaults to the native Rust CLI path on macOS.
    if opts.exercises_dir then
        config.exercises_dir = vim.fn.expand(opts.exercises_dir)
    end
    -- Allow the user to override the MOOC.fi base URL (e.g. for older course years).
    if opts.mooc_url then
        config.mooc_url = opts.mooc_url
    end
    local commands = {
        TmcMenu      = "menu",
        TmcDashboard = "open_dashboard",
        TmcTest      = "test",
        TmcSubmit    = "submit",
        TmcDoctor    = "doctor",
        TmcInstructions = "instructions",
        TmcDownload  = "download_prompt",
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
    
    setup_breadcrumbs()
end

return M
