---@class Config
local _default_config = {
	binary_path = vim.env.HOME .. "/tmc-cli-rust-x86_64-apple-darwin-v1.1.2",
}

---@class tmc
local M = {}

---@type Config
M._config = _default_config

---@param user_config Config?
M.setup = function(user_config)
	M._config = vim.tbl_deep_extend("force", M._config, user_config or {})
end

return M
