local M = {}
local ns_id = vim.api.nvim_create_namespace("tmc_status")

-- Your specific icons
local theme = {
    course = "󰉋 ",
    exercise_pending = "󱎫 ",
    exercise_done = "󰄬 ",
    menu = "󰮫 ",
    default = "• "
}

-- Define colors
vim.api.nvim_set_hl(0, "TmcSuccess", { fg = "#98c379", bold = true }) -- Green
vim.api.nvim_set_hl(0, "TmcFailure", { fg = "#e06c75", bold = true }) -- Red
vim.api.nvim_set_hl(0, "TmcProgress", { fg = "#61afef" })             -- Blue

function M.make_progress_bar(percentage)
    local width = 10
    local done_width = math.floor((percentage / 100) * width)
    -- Using solid block for filled, light shade for empty
    local bar = string.rep("█", done_width) .. string.rep("░", width - done_width)
    return string.format("[%s] %3d%%", bar, percentage)
end

function M.show_menu(items, prompt_text, menu_type, on_select, max_name_len)
    vim.ui.select(items, {
        prompt = prompt_text,
        format_item = function(item)
            if type(item) == "table" then
                -- Exercise format
                if item.completed ~= nil then
                    local icon = item.completed and theme.exercise_done or theme.exercise_pending
                    return icon .. " " .. item.name
                end
                -- Course format with dynamic alignment
                if item.progress_str then
                    local padding = max_name_len or 25
                    local format_str = theme.course .. " %-" .. padding .. "s  %s"
                    return string.format(format_str, item.name, item.progress_str)
                end
            end
            return (theme[menu_type] or theme.default) .. " " .. item
        end,
    }, function(choice) if choice then on_select(choice) end end)
end

function M.show_virtual_status(bufnr, message, is_success)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)

    -- Pick color based on success
    local hl = is_success and "TmcSuccess" or "TmcFailure"
    local icon = is_success and theme.exercise_done or "󰅙 "

    vim.api.nvim_buf_set_extmark(bufnr, ns_id, 0, 0, {
        virt_text = { { icon .. message, hl } },
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

function M.notify(msg, level)
    vim.schedule(function()
        vim.notify(msg, vim.log.levels[level:upper()] or vim.log.levels.INFO, { title = "TMC" })
    end)
end

function M.clear_status(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr or 0, ns_id, 0, -1)
end

return M
