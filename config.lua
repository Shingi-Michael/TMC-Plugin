local M = {}

-- create default function for the app to use
M.defaults = {
    bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2")
}

-- set M.option to the home path so that the plugin has an immediate "Plan A"
M.options = M.defaults
-- create a setup function that has an options table that allows the user to override my set defaults
function M.setup(user_configs)
    M.options = vim.tbl_deep_extend("force", M.defaults, user_configs or {})
end

return M
