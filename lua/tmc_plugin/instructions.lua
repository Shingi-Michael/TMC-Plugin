local M = {}
local ui = require("tmc_plugin.ui")

-- HTML to Markdown super-simple converter
local function html_to_md(html)
    if not html then return "" end
    
    local md = html
    -- Remove span tags but keep content
    md = string.gsub(md, "<span[^>]*>", "")
    md = string.gsub(md, "</span%s*>", "")
    
    -- Links
    md = string.gsub(md, '<a[^>]*href="([^"]+)"[^>]*>(.-)</a>', "[%2](%1)")
    
    -- Bold & Italic
    md = string.gsub(md, "<strong[^>]*>(.-)</strong>", "**%1**")
    md = string.gsub(md, "<b[^>]*>(.-)</b>", "**%1**")
    md = string.gsub(md, "<em[^>]*>(.-)</em>", "*%1*")
    
    -- Code blocks: <div class="gatsby-highlight" data-language="python"><pre...><code...>...</code></pre></div>
    md = string.gsub(md, '<div class="gatsby%-highlight"[^>]*data%-language="([^"]+)"[^>]*>.*<code[^>]*>(.-)</code>.*</div>', "\n```%1\n%2\n```\n")
    
    -- Inline code
    md = string.gsub(md, "<code[^>]*>(.-)</code>", "`%1`")
    
    -- Sample output
    md = string.gsub(md, "<sample%-output[^>]*>(.-)</sample%-output>", function(inner)
        -- Inner might have <p> and \n. Clean it up for a blockquote style
        inner = string.gsub(inner, "<p[^>]*>", "")
        inner = string.gsub(inner, "</p>", "")
        -- Add "> " to each line
        local quoted = "\n"
        for line in string.gmatch(inner .. "\n", "(.-)\n") do
            if line ~= "" then
                quoted = quoted .. "> " .. line .. "\n"
            end
        end
        return "\n**Sample output**" .. quoted .. "\n"
    end)
    
    -- Paragraphs
    md = string.gsub(md, "<p[^>]*>(.-)</p>", "%1\n\n")
    
    -- Line breaks
    md = string.gsub(md, "<br%s*/?>", "\n")
    md = string.gsub(md, "</p>", "\n\n")
    md = string.gsub(md, "</div>", "\n")
    
    -- Lists
    md = string.gsub(md, "<ul[^>]*>(.-)</ul>", "%1")
    md = string.gsub(md, "<li[^>]*>(.-)</li>", "- %1\n")
    
    -- Remove remaining HTML tags
    md = string.gsub(md, "<[^>]+>", "")
    
    -- Unescape HTML entities
    md = string.gsub(md, "&quot;", '"')
    md = string.gsub(md, "&amp;", "&")
    md = string.gsub(md, "&lt;", "<")
    md = string.gsub(md, "&gt;", ">")
    md = string.gsub(md, "&#39;", "'")
    
    -- Clean up extra newlines
    md = string.gsub(md, "\n\n\n+", "\n\n")
    return vim.trim(md)
end

local function get_cache_dir()
    local dir = vim.fn.stdpath("cache") .. "/tmc_plugin/instructions"
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
    return dir
end

-- Sync fetch with curl
local function curl_json(url)
    local obj = vim.system({"curl", "-sL", url}):wait()
    if obj.code == 0 and obj.stdout then
        local ok, data = pcall(vim.json.decode, obj.stdout)
        if ok then return data end
    end
    return nil
end

function M.fetch_and_show(tmcname)
    local cache_file = get_cache_dir() .. "/" .. tmcname .. ".md"
    
    -- Check cache first
    local f = io.open(cache_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        M.show_in_split(tmcname, content)
        return
    end

    local part = string.match(tmcname, "^part(%d%d)")
    if not part then
        vim.notify("Could not determine course part from exercise name: " .. tmcname, vim.log.levels.WARN)
        return
    end
    part = tonumber(part)
    
    -- NOTE: base_url is currently fixed to programming-25.mooc.fi.
    -- If you need to support other MOOC.fi courses, expose this via config.
    local base_url = "https://programming-25.mooc.fi"
    local part_url = string.format("%s/page-data/part-%d/page-data.json", base_url, part)
    
    vim.notify("Fetching instructions for " .. tmcname .. "...", vim.log.levels.INFO)
    vim.system({"curl", "-sL", part_url}, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function() vim.notify("Failed to fetch course data for part " .. part, vim.log.levels.ERROR) end)
            return
        end
        local ok, data = pcall(vim.json.decode, obj.stdout)
        if not ok or not data or not data.result or not data.result.data or not data.result.data.allPages then
            vim.schedule(function() vim.notify("Failed to parse course data.", vim.log.levels.ERROR) end)
            return
        end
        
        local paths = {}
        local prefix = string.format("/part-%d/", part)
        for _, edge in ipairs(data.result.data.allPages.edges) do
            local path = edge.node.frontmatter.path
            if path and string.sub(path, 1, #prefix) == prefix then
                table.insert(paths, path)
            end
        end
        
        -- Chain async vim.system calls sequentially through each page until the exercise is found.
        local function check_next_path(index)
            if index > #paths then
                vim.schedule(function() vim.notify("Instructions for " .. tmcname .. " not found on MOOC.fi", vim.log.levels.WARN) end)
                return
            end
            
            local path = paths[index]
            local page_url = string.format("%s/page-data%s/page-data.json", base_url, path)
            
            vim.system({"curl", "-sL", page_url}, function(p_obj)
                local found = false
                if p_obj.code == 0 then
                    local p_ok, p_data = pcall(vim.json.decode, p_obj.stdout)
                    if p_ok and p_data.result and p_data.result.data and p_data.result.data.page then
                        local html = p_data.result.data.page.html
                        if html then
                            -- Parse all exercises in this page and cache them
                            for _, tag in ipairs({"in%-browser%-programming%-exercise", "programming%-exercise"}) do
                                for exercise_block in string.gmatch(html, "<" .. tag .. "(.-)</" .. tag .. ">") do
                                    local ex_tmcname = string.match(exercise_block, 'tmcname=["\']([^"\']+)["\']')
                                    local ex_name = string.match(exercise_block, 'name=["\']([^"\']+)["\']')
                                    
                                    if ex_tmcname then
                                        local content = string.match(exercise_block, ">%s*(.*)$")
                                        if content then
                                            local md = string.format("# %s\n\n%s", ex_name or ex_tmcname, html_to_md(content))
                                            local f_out = io.open(get_cache_dir() .. "/" .. ex_tmcname .. ".md", "w")
                                            if f_out then
                                                f_out:write(md)
                                                f_out:close()
                                            end
                                            if ex_tmcname == tmcname then
                                                found = true
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                if found then
                    local fh = io.open(cache_file, "r")
                    if fh then
                        local content = fh:read("*a")
                        fh:close()
                        vim.schedule(function() M.show_in_split(tmcname, content) end)
                        return
                    end
                end
                
                check_next_path(index + 1)
            end)
        end
        
        check_next_path(1)
    end)
end

function M.show_in_split(tmcname, content)
    -- Close existing instructions buffer if any
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.api.nvim_buf_get_name(buf):match("TMC_Instructions") then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Create vertical split
    vim.cmd("vsplit")
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, buf)
    
    local lines = vim.split(content, "\n")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    vim.api.nvim_buf_set_name(buf, "TMC_Instructions_" .. tmcname)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].readonly = true
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    
    -- Map q to close
    vim.keymap.set("n", "q", ":q<CR>", { buffer = buf, silent = true, noremap = true })
end

return M
