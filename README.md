# TMC-Plugin

A Neovim interface for the Test My Code (TMC) framework, allowing you to manage courses, download exercises, and run tests without leaving your editor.

## Features
* **Course & Exercise Management:** Browse and download exercises directly via Telescope.
* **Background Testing:** Run TMC tests asynchronously with virtual text status updates.
* **Integrated Diagnostics:** Built-in `TmcDoctor` to verify your binary, auth, and workspace health.
* **Log Navigation:** View detailed test output in a dedicated, scrubbed log window.

## Getting Started

### Dependencies
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/nvim-telescope)
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- **TMC CLI:** Ensure you have the official [TMC CLI binary](https://github.com/rage/tmc-cli-rust) installed.

### Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Shingi-Michael/TMC-Plugin",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("tmc_plugin").setup({
            -- Provide the path to your tmc binary
            -- Can be a global command "tmc" or an absolute path
            bin = "tmc" 
        })
    end,
}
