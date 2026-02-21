local M = {}
local ns_id = vim.api.nvim_create_namespace("tmc_status")
local theme = { course = "󰉋 ", exercise_pending = "󱎫 ", exercise_done = "󰄬 ", menu = "󰮫 ", default = "• " }

vim.api.nvim_set_hl(0, "TmcSuccess", { fg = "#98c379", bold = true })
vim.api.nvim_set_hl(0, "TmcFailure", { fg = "#e06c75", bold = true })

function M.make_progress_bar(percentage)
    local width = 10
    local done_width = math.floor((percentage / 100) * width)
    local bar = string.rep("█", done_width) .. string.rep("░", width - done_width)
    return string.format("[%s] %3d%%", bar, percentage)
end

function M.show_menu(items, prompt_text, menu_type, on_select, max_name_len)
    vim.ui.select(items, {
        prompt = prompt_text,
        format_item = function(item)
            if type(item) == "table" and item.progress_str then
                return string.format(theme.course .. " %-" .. (max_name_len or 25) .. "s  %s", item.name,
                    item.progress_str)
            end
            return (theme[menu_type] or theme.default) .. " " .. item
        end,
    }, function(choice) if choice then on_select(choice) end end)
end

function M.show_virtual_status(bufnr, message, is_success)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
        virt_text = { { (is_success and "󰄬 " or "󰅙 ") .. message, is_success and "TmcSuccess" or "TmcFailure" } },
        virt_text_pos = "right_align",
    })
end

function M.show_log_window(content)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.cmd("botright 12split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.keymap.set("n", "q", ":close<CR>", { buffer = buf })
end

function M.create_live_log_window(title)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { title or "TMC Log", string.rep("=", #(title or "TMC Log")) })
    vim.cmd("botright 12split")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    vim.keymap.set("n", "q", ":close<CR>", { buffer = buf })
    return buf, win
end

function M.notify(msg, level)
    vim.schedule(function() vim.notify(msg, vim.log.levels[(level or "info"):upper()], { title = "TMC" }) end)
end

function M.clear_status(bufnr) vim.api.nvim_buf_clear_namespace(bufnr or 0, ns_id, 0, -1) end

return M
