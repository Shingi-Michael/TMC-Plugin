local config = require("tmc_plugin.config")
local M = {}

function M.run(args, on_finish, cwd)
    local cmd = { config.bin or "tmc" }
    for _, v in ipairs(args) do table.insert(cmd, v) end
    vim.system(cmd, {
        text = true,
        cwd = cwd,
        env = vim.fn.environ()
    }, function(result)
        if on_finish then on_finish(result) end
    end)
end

return M
