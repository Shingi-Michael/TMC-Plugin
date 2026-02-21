local M = {}

M.bin = nil -- set by setup()

-- Default exercises root used by the native tmc-cli (Rust) on macOS.
-- Override via setup({ exercises_dir = "/your/path" })
M.exercises_dir = vim.fn.expand("$HOME/Library/Application Support/tmc/tmc_cli_rust")

return M
