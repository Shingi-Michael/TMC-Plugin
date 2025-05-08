-- Implement the creation of a menu using telescope
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local sorters = require 'telescope.sorters'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

-- Define menu options
local options = {
  '1: Test',
  '2: Submit',
}

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

-- Create a function for the menu
local function create_Menu()
  pickers
    .new({}, {
      prompt_title = 'TMC-Menu',
      finder = finders.new_table {
        results = options,
      },
      sorter = sorters.get_generic_fuzzy_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          print(vim.inspect(selection))
          if not selection then
            return
          end

          if selection.value == '1: Test' then
            vim.cmd 'Ttmc'
          elseif selection.value == '2: Submit' then
            vim.cmd 'Stmc'
          end
        end)
        return true
      end,
    })
    :find()
end

vim.api.nvim_create_user_command('TMenu', create_Menu, { desc = 'Open TMC Menu' })
