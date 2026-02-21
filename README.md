# TMC-Plugin

A lightweight Neovim plugin for the **Test My Code (TMC)** framework.
Manage courses, browse exercises, run tests, and submit — without leaving your editor.

> **No Telescope. No Plenary.** Built entirely on native Neovim APIs.

---

## Requirements

- **Neovim ≥ 0.9**
- **tmc-cli-rust** — [github.com/rage/tmc-cli-rust](https://github.com/rage/tmc-cli-rust)

---

## Installation

### lazy.nvim (recommended)

```lua
{
  "Shingi-Michael/TMC-Plugin",
  config = function()
    require("tmc_plugin").setup({
      -- Full path to your tmc binary (if not on PATH as "tmc")
      bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
    })
  end,
}
```

The plugin works out of the box with zero configuration — all `:Tmc*` commands are
registered automatically on startup. The `setup()` call is only needed to customise
the binary path or exercises directory.

### packer.nvim

```lua
use {
  "Shingi-Michael/TMC-Plugin",
  config = function()
    require("tmc_plugin").setup({
      bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
    })
  end,
}
```

---

## Configuration

```lua
require("tmc_plugin").setup({
  -- Path or name of the tmc CLI binary. Default: "tmc"
  bin = "tmc",

  -- Root directory where tmc-cli stores downloaded exercises.
  -- Default (macOS): ~/Library/Application Support/tmc/tmc_cli_rust
  exercises_dir = "~/Library/Application Support/tmc/tmc_cli_rust",
})
```

---

## Commands

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

---

## Troubleshooting

**Commands not found** — Check that the plugin loaded correctly:
```vim
:lua require("tmc_plugin.api").doctor()
```

**`tmc: command not found`** — Set the full binary path in `setup()`:
```lua
require("tmc_plugin").setup({
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
})
```

**`Exercise not downloaded`** — The plugin expects exercises at:
```
~/Library/Application Support/tmc/tmc_cli_rust/<course>/<exercise>
```
Download exercises first (press `d` in the dashboard), or set `exercises_dir` in `setup()`.

---

## License

MIT
