-- menu.lua
-- Floating window command palette for the TMC plugin.
-- No external dependencies — pure Neovim APIs.
local M = {}
local config  = require("tmc_plugin.config")
local system  = require("tmc_plugin.system")
local _menu_win = nil   -- tracks the single open menu window

local W = 52  -- total window width including the two border chars

-- ─── Box drawing ─────────────────────────────────────────────────────────────

local function inner(text)
    local iw = W - 2  -- inner width (excludes │ on each side)
    local dw = vim.api.nvim_strwidth(text)
    return text .. string.rep(" ", math.max(0, iw - dw))
end

local function box(text) return "│" .. inner(text) .. "│" end
local function top()     return "╭" .. string.rep("─", W - 2) .. "╮" end
local function mid()     return "├" .. string.rep("─", W - 2) .. "┤" end
local function bot()     return "╰" .. string.rep("─", W - 2) .. "╯" end
local function sep()     return box("  " .. string.rep("─", W - 6)) end

-- ─── Course detection (instant, no network) ───────────────────────────────────

local function detect_course()
    local path = vim.fn.expand("%:p")
    local base = vim.fn.expand(config.exercises_dir)
    -- Normalise trailing slash
    if base:sub(-1) == "/" then base = base:sub(1, -2) end
    if path:sub(1, #base) == base then
        local rest = path:sub(#base + 2)         -- skip the separator
        return rest:match("^([^/\\]+)")           -- first directory = course name
    end
    return nil
end

-- ─── Menu items ───────────────────────────────────────────────────────────────

-- type = "group"  → category header + separator
-- type = "item"   → selectable entry
-- type = "spacer" → blank line
local ITEMS = {
    { type = "group", label = "Exercises" },
    { type = "item",  icon = "󰙨",  label = "Dashboard",  desc = "Browse & manage exercises",   action = "open_dashboard" },
    { type = "item",  icon = "✓",  label = "Test",        desc = "Run tests in current exercise", action = "test" },
    { type = "item",  icon = "↑",  label = "Submit",      desc = "Submit exercise to TMC",       action = "submit" },
    { type = "spacer" },
    { type = "group", label = "Account" },
    { type = "item",  icon = "󰍋",  label = "Login",       desc = "Sign in to TMC",              action = "login" },
    { type = "item",  icon = "✔",  label = "Doctor",      desc = "Check connection & auth",     action = "doctor" },
}

-- ─── Buffer content builder ───────────────────────────────────────────────────

-- Returns:
--   lines      – the full list of strings to put in the buffer
--   selectables – { line (0-based), action, is_login } for each item entry
--   group_lines – 0-based line indices of group header rows (for highlighting)
local function build(auth_status, course)
    -- Separate the COLOURED indicator from the neutral hint that follows it.
    -- Line 2 byte layout: │(3) + "  "(2) = indicator starts at byte 5
    local indicator, hint
    if auth_status == nil then
        indicator = "Checking..."
        hint      = ""
    elseif auth_status then
        indicator = "✓ Connected"
        hint      = course and ("  •  " .. course) or "  •  No exercise detected"
    else
        indicator = "✗ Auth Required"
        hint      = "  —  use Login below"
    end

    local lines = {
        top(),                                -- 0
        box("  ⚡ TMC Plugin"),               -- 1
        box("  " .. indicator .. hint),       -- 2  ← status line
        mid(),                                -- 3
        box(""),                              -- 4
    }

    local selectables = {}
    local group_lines = {}

    for _, item in ipairs(ITEMS) do
        if item.type == "group" then
            table.insert(group_lines, #lines)
            table.insert(lines, box("  " .. item.label))
            table.insert(lines, sep())
        elseif item.type == "item" then
            local line_idx = #lines
            local content = string.format("     %s  %-11s %s",
                item.icon, item.label, item.desc)
            table.insert(lines, box(content))
            table.insert(selectables, {
                line     = line_idx,
                action   = item.action,
                is_login = item.action == "login",
            })
        elseif item.type == "spacer" then
            table.insert(lines, box(""))
        end
    end

    table.insert(lines, box(""))
    table.insert(lines, mid())
    table.insert(lines, box("  j/k Navigate   Enter Select   q Close"))
    table.insert(lines, bot())

    -- Return indicator so the caller can compute its byte range for highlighting
    return lines, selectables, group_lines, indicator
end

-- ─── Open ─────────────────────────────────────────────────────────────────────

function M.open()
    -- If a menu is already open, close it first (prevents stacking)
    if _menu_win and vim.api.nvim_win_is_valid(_menu_win) then
        vim.api.nvim_win_close(_menu_win, true)
    end

    -- Ensure highlight groups exist (safe to call repeatedly)
    vim.api.nvim_set_hl(0, "TmcMenuTitle",    { fg = "#e5c07b", bold = true })
    vim.api.nvim_set_hl(0, "TmcMenuGroup",    { fg = "#5c6370", italic = true })
    vim.api.nvim_set_hl(0, "TmcMenuHint",     { fg = "#5c6370" })
    vim.api.nvim_set_hl(0, "TmcMenuSelected", { fg = "#61afef", bold = true, reverse = true })

    local course     = detect_course()
    local auth_status = nil   -- nil = still checking

    local lines, selectables, group_lines, indicator = build(auth_status, course)

    -- ── Create buffer ──────────────────────────────────────────────────────
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    for k, v in pairs({ modifiable = false, bufhidden = "wipe", buftype = "nofile" }) do
        vim.bo[buf][k] = v
    end

    -- ── Open centered floating window ──────────────────────────────────────
    local height = #lines
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        row      = math.max(0, math.floor((vim.o.lines   - height) / 2)),
        col      = math.max(0, math.floor((vim.o.columns - W)      / 2)),
        width    = W,
        height   = height,
        style    = "minimal",
        zindex   = 50,
    })
    for k, v in pairs({ wrap = false, number = false, relativenumber = false,
                         signcolumn = "no", cursorline = false }) do
        vim.wo[win][k] = v
    end
    _menu_win = win  -- register so repeated :TmcMenu calls close the old one

    -- ── Namespaces ─────────────────────────────────────────────────────────
    local ns_static = vim.api.nvim_create_namespace("tmc_menu_static")
    local ns_cursor = vim.api.nvim_create_namespace("tmc_menu_cursor")

    -- Byte layout of line 2: │(3 bytes) + "  "(2 bytes) = indicator at byte 5
    local STATUS_BYTE_START = 5

    local function apply_static_highlights(ind, logged)
        vim.api.nvim_buf_clear_namespace(buf, ns_static, 0, -1)
        -- Title line
        vim.api.nvim_buf_add_highlight(buf, ns_static, "TmcMenuTitle", 1, 0, -1)
        -- Status indicator — colour ONLY the indicator word, not the course name
        local hl = (logged == nil)    and "TmcMenuHint"
                or logged             and "TmcSuccess"
                or                       "TmcFailure"
        vim.api.nvim_buf_add_highlight(buf, ns_static, hl,
            2, STATUS_BYTE_START, STATUS_BYTE_START + #ind)
        -- Group headers
        for _, gl in ipairs(group_lines) do
            vim.api.nvim_buf_add_highlight(buf, ns_static, "TmcMenuGroup", gl, 0, -1)
        end
        -- Footer hint
        vim.api.nvim_buf_add_highlight(buf, ns_static, "TmcMenuHint", #lines - 2, 0, -1)
    end

    apply_static_highlights(indicator, auth_status)

    -- ── Selection ──────────────────────────────────────────────────────────
    local selected = 1

    local function render_cursor()
        vim.api.nvim_buf_clear_namespace(buf, ns_cursor, 0, -1)
        local s = selectables[selected]
        if s then
            vim.api.nvim_buf_add_highlight(buf, ns_cursor, "TmcMenuSelected", s.line, 0, -1)
        end
    end

    render_cursor()

    -- ── Actions ────────────────────────────────────────────────────────────
    local function close()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
        _menu_win = nil
    end

    -- Close the float automatically if the user navigates away (Ctrl-w, etc.)
    vim.api.nvim_create_autocmd("WinLeave", {
        buffer   = buf,
        once     = true,
        callback = function() vim.schedule(close) end,
    })

    local function execute()
        local s = selectables[selected]
        if not s then return end
        close()
        vim.schedule(function() require("tmc_plugin.api")[s.action]() end)
    end

    -- ── Keymaps ────────────────────────────────────────────────────────────
    local o = { buffer = buf, noremap = true, silent = true, nowait = true }

    vim.keymap.set("n", "j", function()
        selected = (selected % #selectables) + 1
        render_cursor()
    end, o)

    vim.keymap.set("n", "k", function()
        selected = ((selected - 2) % #selectables) + 1
        render_cursor()
    end, o)

    -- Number shortcuts: 1-6 jump directly to that item and execute
    for i = 1, #selectables do
        vim.keymap.set("n", tostring(i), function()
            selected = i
            render_cursor()
            vim.defer_fn(execute, 80)   -- brief flash so user sees selection
        end, o)
    end

    vim.keymap.set("n", "<CR>",  execute, o)
    vim.keymap.set("n", "q",     close,   o)
    vim.keymap.set("n", "<Esc>", close,   o)

    -- ── Async auth check ───────────────────────────────────────────────────
    -- Menu opens instantly; status line updates ~1 s later with real result.
    system.run({ "courses" }, function(obj)
        local out    = (obj.stdout .. obj.stderr):lower()
        local logged = obj.code == 0
            and not out:match("login")
            and not out:match("error")

        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then return end

            auth_status = logged

            -- Rebuild just line 2 with the updated indicator + hint
            local new_indicator = logged and "✓ Connected" or "✗ Auth Required"
            local new_hint      = logged
                and (course and ("  •  " .. course) or "  •  No exercise detected")
                or  "  —  use Login below"
            local new_line = box("  " .. new_indicator .. new_hint)

            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 2, 3, false, { new_line })
            vim.bo[buf].modifiable = false

            -- Re-apply highlights with the new indicator text for byte-range calc
            apply_static_highlights(new_indicator, logged)
            render_cursor()

            -- Auto-focus Login when not authenticated
            if not logged then
                for i, s in ipairs(selectables) do
                    if s.is_login then
                        selected = i
                        render_cursor()
                        break
                    end
                end
            end
        end)
    end)
end

return M
