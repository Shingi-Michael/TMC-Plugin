local config = require("tmc_plugin.config")
local M = {}

-- define the runner logic
function M.run(args, on_finish)
    local new_cmd_tbl = { config.options.bin }

    -- cycle through the arguments provided and insert them in a new table
    for _, v in ipairs(args) do
        table.insert(new_cmd_tbl, v)
    end

    vim.system(new_cmd_tbl, { text = true }, function(result)
        if on_finish then
            on_finish(result)
        end
    end)
end

return M
