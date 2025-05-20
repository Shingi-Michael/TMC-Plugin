---@class Config
local _default_config = {}

---@class tmc
local M = {}

---@type Config
M._config = _default_config

---@param user_config Config?
M.setup = function(user_config)
  M._config = vim.tbl_deep_extend("force", M._config, user_config or {})
end

return M
