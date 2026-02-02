local M = {}
local ns_id = vim.api.nvim_create_namespace("tmc_status")

local theme = { course = "󰉋 ", exercise_pending = "󱎫 ", exercise_done = "󰄬 ", default = "• " }

vim.api.nvim_set_hl(0, "TmcSuccess", { fg = "#98c379", bold = true })
vim.api.nvim_set_hl(0, "TmcFailure", { fg = "#e06c75", bold = true })

function M.show_menu(items, prompt_text, menu_type, on_select)
    vim.ui.select(items, {
        prompt = prompt_text,
        format_item = function(item)
            if type(item) == "table" then
                local icon = item.completed and theme.exercise_done or theme.exercise_pending
                return icon .. " " .. item.name
            end
            return (theme[menu_type] or theme.default) .. " " .. item
        end,
    }, function(choice) if choice then on_select(choice) end end)
end

function M.show_virtual_status(bufnr, message, is_success)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
        virt_text = { { (is_success and "󰄬 " or "󰅖 ") .. message, is_success and "TmcSuccess" or "TmcFailure" } },
        virt_text_pos = "right_align",
    })
end

function M.show_log_window(content)
    local clean = content:gsub("\27%[[0-9;]*%a", "")
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(clean, "\n"))
    vim.cmd("botright 12split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.bo[buf].buftype = "nofile"
    vim.keymap.set("n", "q", ":close<CR>", { buffer = buf })
end

function M.clear_status(bufnr) vim.api.nvim_buf_clear_namespace(bufnr or 0, ns_id, 0, -1) end

function M.notify(msg, level)
    vim.schedule(function()
        local opts = {
            title = "TMC",
            timeout = 1000
        }

        vim.notify(msg, vim.log.levels[level:upper()] or vim.log.levels.INFO, opts)
    end)
end

return M
