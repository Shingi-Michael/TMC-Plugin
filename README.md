# TMC-Plugin

A lightweight Neovim plugin for the **Test My Code (TMC)** framework.
Manage courses, browse exercises, run tests, and submit — without leaving your editor.

> **No Telescope. No Plenary.** Built entirely on native Neovim APIs.

---

## ⚠️ IMPORTANT — `setup()` is required

**The plugin will not work without calling `setup()` in your Neovim config.**

The `:Tmc*` commands are only registered when `setup()` is called. If you skip this step, none of the commands will exist and the plugin will appear to do nothing.

```lua
-- This MUST be in your Neovim config (init.lua or equivalent)
require("tmc_plugin").setup({
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
})
```

---

## Requirements

- **Neovim ≥ 0.9**
- **tmc-cli-rust** — [github.com/rage/tmc-cli-rust](https://github.com/rage/tmc-cli-rust)

---

## Installation

### lazy.nvim

```lua
{
  "Shingi-Michael/TMC-Plugin",
  -- ✅ config function is REQUIRED — setup() registers all :Tmc* commands
  config = function()
    require("tmc_plugin").setup({
      bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
    })
  end,
}
```

> ❌ **Do NOT use `event = "VeryLazy"` or `lazy = true`** without a manual trigger.
> Lazy-loading the plugin means `setup()` won't fire at startup and commands
> will be unavailable until something else loads the plugin.

### packer.nvim

```lua
use {
  "Shingi-Michael/TMC-Plugin",
  -- ✅ config function is REQUIRED — setup() registers all :Tmc* commands
  config = function()
    require("tmc_plugin").setup({
      bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
    })
  end,
}
```

---

## Configuration

`setup()` accepts the following options:

```lua
require("tmc_plugin").setup({
  -- REQUIRED if "tmc" is not on your PATH.
  -- Provide the full path to the tmc-cli-rust binary.
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),

  -- Root directory where tmc-cli stores downloaded exercises.
  -- Default (macOS): ~/Library/Application Support/tmc/tmc_cli_rust
  -- Change this only if your tmc-cli uses a different location.
  exercises_dir = "~/Library/Application Support/tmc/tmc_cli_rust",
})
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `bin` | string | `"tmc"` | Path or name of the TMC CLI executable |
| `exercises_dir` | string | `~/Library/Application Support/tmc/tmc_cli_rust` | Root directory where tmc-cli downloads exercises |

---

## Commands

All commands are registered by `setup()`. If a command is not found, check that `setup()` is being called correctly.

| Command | Description |
|---|---|
| `:TmcDashboard` | Open the course selector → exercise dashboard |
| `:TmcTest` | Run `tmc test` in the current project root |
| `:TmcSubmit` | Submit the current exercise with a live log window |
| `:TmcDoctor` | Check TMC authentication / connectivity |
| `:TmcLogin` | Open a terminal split to run `tmc login` |

---

## Dashboard

`:TmcDashboard` opens a course picker, then renders an exercise list in a vertical split:

```
 MOOC-PROGRAMMING-25
 ═══════════════════

 Progress: [██████░░░░]  60%

 Exercises:
 ──────────────────────────────
 [x] part01-01_emoticon
 [x] part01-02_seven_brothers
 [ ] part01-03_row_your_boat

 [Enter] Test  [d] Download  [s] Submit  [r] Refresh  [q] Close
```

| Key | Action |
|---|---|
| `<Enter>` | Test the exercise under the cursor |
| `s` | Submit the exercise under the cursor |
| `d` | Download the exercise under the cursor |
| `r` | Force-refresh data from TMC servers |
| `q` | Close the dashboard |

Move the cursor to an exercise line before pressing `s`, `<Enter>`, or `d`.

---

## Exercise directory layout

The plugin expects exercises at:

```
<exercises_dir>/<course-name>/<exercise-name>/
```

**macOS default (tmc-cli-rust):**
```
~/Library/Application Support/tmc/tmc_cli_rust/<course>/<exercise>
```

---

## Troubleshooting

### Commands not found (`:TmcDashboard`, etc.)

`setup()` was not called. Verify your config contains:

```lua
require("tmc_plugin").setup({ bin = "/path/to/tmc" })
```

Then restart Neovim and check again.

### `tmc: command not found`

The binary is not on Neovim's PATH. Pass the full absolute path:

```lua
require("tmc_plugin").setup({
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
})
```

### `Exercise not downloaded`

The exercise directory was not found at `<exercises_dir>/<course>/<exercise>`.
Either download the exercise first (press `d` in the dashboard) or update `exercises_dir` in `setup()` to match where your tmc-cli actually saves files.

### Dashboard shows stale data

Press `r` in the dashboard to force a full re-sync from TMC servers.

---

## License

MIT
