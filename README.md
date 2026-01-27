# TMC-Plugin

## Getting Started

### Dependencies
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/nvim-telescope)

### Installation

[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Shingi-Michael/TMC-Plugin",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
    },
    config = function()
        require("tmc_plugin").setup({
            -- Users put THEIR specific path to the TMC binary here
            bin = "/path/to/their/tmc-cli-binary" 
        })
    end,
}

```
