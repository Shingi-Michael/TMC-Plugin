vim.api.nvim_create_user_command('Ttmc', function()
  local tmc_binary = vim.env.HOME .. '/tmc-cli-rust-x86_64-apple-darwin-v1.1.2'
  local exercise_path = vim.fn.expand '%:p:h:h'

  -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
  local shell_cmd = string.format('exec %s test "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read', tmc_binary, exercise_path)

  vim.cmd 'split'
  vim.cmd('terminal ' .. shell_cmd)
  vim.cmd 'startinsert'
end, { desc = 'Run TMC submit without "Process exited" message' })

vim.api.nvim_create_user_command('Stmc', function()
  local tmc_binary = vim.env.HOME .. '/tmc-cli-rust-x86_64-apple-darwin-v1.1.2'
  local exercise_path = vim.fn.expand '%:p:h:h'

  -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
  local shell_cmd = string.format('exec %s submit "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read', tmc_binary, exercise_path)

  vim.cmd 'split'
  vim.cmd('terminal ' .. shell_cmd)
  vim.cmd 'startinsert'
end, { desc = 'Run TMC submit without "Process exited" message' })
