-- Implement the creation of a menu using telescope
-- Display a list of items i.e files and interact with them by selecting and searching
local pickers = require 'telescope.pickers'
-- Provide a list of selectable items with this function
local finders = require 'telescope.finders'
-- This function matches and ranks input to the list of items you have
local sorters = require 'telescope.sorters'
-- This function tells telescope what to do when the user selects an Item
local actions = require 'telescope.actions'
-- Access selected items, typed input and or raw data from tables. This is the bridge between the UI and the Lua logic
local action_state = require 'telescope.actions.state'

-- Define menu options
local options = {
  '❓Help',
  '🧪 Test',
  '✅ Submit',
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

vim.api.nvim_create_user_command('Htmc', function()
  local tmc_binary = vim.env.HOME .. '/tmc-cli-rust-x86_64-apple-darwin-v1.1.2'
  local exercise_path = vim.fn.expand '%:p:h:h'

  -- Use 'exec' to replace the shell with the command, preventing "Process exited" message
  local shell_cmd = string.format('exec %s --help "%s" && echo "" && echo "Press ENTER twice to exit..." && read && read', tmc_binary, exercise_path)

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
      GetSelectionrter = sorters.get_fzy_sorter(),
      layout_config = {
        width = 0.4,
        height = 0.3,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          -- print(vim.inspect(selection))
          if not selection then
            return
          end

          if selection.value == '🧪 Test' then
            vim.cmd 'Ttmc'
          elseif selection.value == '✅ Submit' then
            vim.cmd 'Stmc'
          elseif selection.value == '❓Help' then
            vim.cmd 'Htmc'
          end
        end)
        return true
      end,
    })
    :find()
end

vim.api.nvim_create_user_command('TMenu', create_Menu, { desc = 'Open TMC Menu' })
