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
  exercises_dir = "~/Library/Application Support/tmc/tmc_cli_rust",

  -- Base URL of the MOOC.fi course site used by :TmcInstructions.
  -- Default: https://programming-25.mooc.fi
  -- Change this when working with a different course year, e.g.:
  --   mooc_url = "https://programming-24.mooc.fi"
  mooc_url = "https://programming-25.mooc.fi",
})
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `bin` | string | `"tmc"` | Path or name of the TMC CLI executable |
| `exercises_dir` | string | `~/Library/Application Support/tmc/tmc_cli_rust` | Root directory where tmc-cli downloads exercises |
| `mooc_url` | string | `https://programming-25.mooc.fi` | MOOC.fi base URL used by `:TmcInstructions` |

---

## Commands

All commands are registered by `setup()`. If a command is not found, check that `setup()` is being called correctly.

| Command | Description |
|---|---|
| `:TmcMenu` | Open the floating command palette (recommended entry point) |
| `:TmcDashboard` | Open the course selector → exercise dashboard |
| `:TmcTest` | Run `tmc test` in the current exercise directory |
| `:TmcSubmit` | Submit the current exercise with a live log window |
| `:TmcNext` | Navigate to the next exercise in the current course |
| `:TmcPrev` | Navigate to the previous exercise in the current course |
| `:TmcInstructions` | Display instructions for the active exercise inside a Neovim split |
| `:TmcDoctor` | Full diagnostics report — binary, auth, cache, context, config |
| `:TmcLogin` | Open a terminal split to run `tmc login` |

> **Note:** `:TmcTest` and `:TmcSubmit` require the current buffer to be inside the
> configured `exercises_dir`. Opening them from an unrelated file shows a warning
> instead of running the wrong command.

---

## Menu (`:TmcMenu`)

The recommended entry point. Opens a centered floating window:

```
╭────────────────────────────────────────────────────────╮
│  ⚡ TMC Plugin                                          │
│  ✓ Connected  •  programming-25                        │
├────────────────────────────────────────────────────────┤
│                                                        │
│  Exercises                                             │
│  ────────────────────────────────────────────────────  │
│        Dashboard       Browse & manage exercises      │
│     ✓   Test            Run tests in current exercise  │
│     ↑   Submit          Submit exercise to TMC         │
│                                                        │
│  Account                                               │
│  ────────────────────────────────────────────────────  │
│        Login           Sign in to TMC                 │
│     📖  Instructions    Show exercise instructions     |
│     ✔   Doctor          Check connection & auth        │
│                                                        │
├────────────────────────────────────────────────────────┤
│  j/k Navigate          Enter Select           q Close  │
╰────────────────────────────────────────────────────────╯
```

**Header behaviour:**
- Course name is detected **instantly** from the current file path — no network call
- Auth status (`✓ Connected` / `✗ Auth Required`) is checked async and updates in place
- `✓ Connected` lights up **green**, `✗ Auth Required` lights up **red**
- When not authenticated, the cursor auto-focuses the **Login** entry

**Navigation:**

| Key | Action |
|---|---|
| `j` / `k` | Move selection up/down |
| `1`–`5` | Jump directly to that item and execute |
| `<Enter>` | Execute selected command |
| `q` / `<Esc>` | Close menu |

The menu closes automatically if you navigate to another window (`<C-w>w`, etc.).

## Exercise Navigation (`:TmcNext` / `:TmcPrev`)

Navigate between exercises without leaving Neovim.

```
:TmcNext   → opens the next exercise in the course
:TmcPrev   → opens the previous exercise
```

**Behaviour:**

| Situation | Result |
|---|---|
| Inside a downloaded exercise | Opens the first source file of the adjacent exercise |
| Exercise not downloaded | Confirm dialog: `[d] Download & open` / `[q] Cancel` |
| At the first exercise, `:TmcPrev` | `"You are at the first exercise of <course>"` |
| At the last exercise, `:TmcNext` | `"You have reached the end of <course>! 🎉"` |
| Not inside `exercises_dir` | Warning to open an exercise file first |
| Dashboard is open | Scrolls to and flashes the new exercise row |

> **Tip:** Run `:TmcDashboard` at least once before using navigation so the
> exercise list is cached locally.

---

## Diagnostics (`:TmcDoctor`)

Opens a structured diagnostic report in a bottom split (press `q` to close):

```
TMC Doctor — 2026-02-21 12:01
======================================

  [1] Binary
  ──────────────────────────────────────────────────────
  ✓  Found:   ~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2
  ✓  Version: tmc-cli-rust 1.1.2

  [2] Neovim
  ──────────────────────────────────────────────────────
  ✓  Neovim 0.10.2 (supported)

  [3] Authentication
  ──────────────────────────────────────────────────────
  ✓  Connected to TMC server

  [4] Exercises Directory  [5] Cache  [6] Current Context  [7] Configuration
  ...
```

| # | Check | Speed | Outcomes |
|---|---|---|---|
| 1 | Binary — found + version | Async | ✓ / ✗ not found / ~ no version |
| 2 | Neovim ≥ 0.9 | Instant | ✓ / ✗ |
| 3 | TMC server authentication | Async | ✓ connected / ✗ not auth / ? no network |
| 4 | Exercises directory exists + folder count | Instant | ✓ / ✗ / ~ empty |
| 5 | Local cache (courses · exercises) | Instant | ✓ / ~ empty / ✗ corrupt |
| 6 | Current file context (course, exercise, on disk, in cache) | Instant | ✓ / ~ |
| 7 | Resolved config (`bin`, `exercises_dir`) | Instant | info only |

Checks 1 and 3 run async and update in-place when results arrive — the report appears instantly and fills in.

---

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

 [Enter] Open  [t] Test  [d] Download  [s] Submit  [r] Refresh  [q] Close
```

| Key | Action |
|---|---|
| `<Enter>` | Open the exercise source file in a new buffer |
| `t` | Run `tmc test` on the exercise under the cursor |
| `s` | Submit the exercise under the cursor |
| `d` | Download the exercise under the cursor |
| `r` | Force-refresh data from TMC servers |
| `q` | Close the dashboard |

Move the cursor to an exercise line before pressing `<Enter>`, `t`, `s`, or `d`.

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

### `Not in a TMC exercise directory`

`:TmcTest` and `:TmcSubmit` check that the current file is inside `exercises_dir`
before running. If you see this warning, navigate to a file inside your exercise
directory first, then run the command again.

### `Exercise not downloaded`

The exercise directory was not found at `<exercises_dir>/<course>/<exercise>`.
Either download the exercise first (press `d` in the dashboard) or update `exercises_dir` in `setup()` to match where your tmc-cli actually saves files.

### Dashboard shows stale data

Press `r` in the dashboard to force a full re-sync from TMC servers.

---

## License

MIT
