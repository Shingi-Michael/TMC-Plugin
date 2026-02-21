local M = {}

M.bin = nil -- set by setup()

-- Default exercises root used by the native tmc-cli (Rust) on macOS.
-- Override via setup({ exercises_dir = "/your/path" })
M.exercises_dir = vim.fn.expand("$HOME/Library/Application Support/tmc/tmc_cli_rust")

-- MOOC.fi course site base URL used to fetch exercise instructions.
-- Override via setup({ mooc_url = "https://programming-24.mooc.fi" }) for older courses.
M.mooc_url = "https://programming-25.mooc.fi"

return M
