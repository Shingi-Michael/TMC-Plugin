# TMC-Plugin

A lightweight Neovim plugin for the **Test My Code (TMC)** framework. Manage courses, browse and download exercises, run tests, and submit your work — all without leaving your editor.

> **No Telescope. No Plenary.** Everything is built on native Neovim APIs (`vim.ui.select`, `vim.fn.jobstart`, `vim.system`).

---

## Features

- **Interactive Dashboard** — browse exercises for any course in a dedicated split window with progress bars and completion markers.
- **One-key Submit** — press `s` on an exercise in the dashboard to submit it; a live log window streams the cleaned TMC output in real time.
- **One-key Test** — press `<Enter>` on an exercise to run `tmc test` locally.
- **Exercise Download** — press `d` to download an exercise directly into the correct tmc-cli directory.
- **Background Testing** — `:TmcTest` runs tests asynchronously with a virtual-text pass/fail indicator on the current buffer.
- **Authentication** — `:TmcLogin` opens a terminal split for interactive login.
- **Diagnostics** — `:TmcDoctor` verifies you are connected and authenticated.
- **Disk-cached Course Data** — course and exercise data is cached so the dashboard opens instantly after the first sync.

---

## Dependencies

| Dependency | Notes |
|---|---|
| **Neovim ≥ 0.9** | Required for `vim.system` and `vim.fn.jobstart` |
| **tmc-cli-rust** | The native Rust TMC CLI binary — [github.com/rage/tmc-cli-rust](https://github.com/rage/tmc-cli-rust) |

No Telescope, no Plenary, no other plugins required.

---

## Installation

### lazy.nvim

```lua
{
  "Shingi-Michael/TMC-Plugin",
  config = function()
    require("tmc_plugin").setup({
      bin           = "tmc",   -- name/path of the tmc binary (default: "tmc")
      exercises_dir = nil,     -- override exercise root (see below)
    })
  end,
}
```

### packer.nvim

```lua
use {
  "Shingi-Michael/TMC-Plugin",
  config = function()
    require("tmc_plugin").setup({ bin = "tmc" })
  end,
}
```

---

## Configuration

```lua
require("tmc_plugin").setup({
  -- Path or name of the tmc CLI binary.
  -- If "tmc" is aliased in your shell, set this to the full absolute path.
  bin = "~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2",

  -- Root directory where tmc-cli stores downloaded exercises.
  -- Defaults to the native tmc-cli-rust location on macOS:
  --   ~/Library/Application Support/tmc/tmc_cli_rust
  -- Override only if your setup differs.
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

| Command | Description |
|---|---|
| `:TmcDashboard` | Open the course selector then render the exercise dashboard |
| `:TmcTest` | Run `tmc test` in the detected project root (result shown as virtual text) |
| `:TmcSubmit` | Submit the current exercise with a live streaming log window |
| `:TmcDoctor` | Check TMC authentication / connectivity |
| `:TmcLogin` | Open a terminal split to run `tmc login` |

---

## Dashboard

Open with `:TmcDashboard`. A menu lets you pick a course; the dashboard then opens in a vertical split.

```
 MOOC-PROGRAMMING-25
 ═══════════════════

 Progress: [██████░░░░]  60%

 Exercises:
 ──────────────────────────────
 [x] part01-01_emoticon
 [x] part01-02_seven_brothers
 [ ] part01-03_row_your_boat
 [ ] part01-04_minutes_in_a_year
 ...

 [Enter] Test  [d] Download  [s] Submit  [r] Refresh  [q] Close
```

### Dashboard keymaps

| Key | Action |
|---|---|
| `<Enter>` | Run `tmc test` for the exercise under the cursor |
| `s` | Submit the exercise under the cursor |
| `d` | Download the exercise under the cursor |
| `r` | Force-refresh course and exercise data from TMC |
| `q` | Close the dashboard |

> **Cursor placement matters** — move the cursor to the exercise line before pressing `s`, `<Enter>`, or `d`.

---

## Submit output

When you press `s`, a log window opens and streams the cleaned TMC output live:

```
Submitting: part01-02_seven_brothers
=====================================
You can view your submission at: https://tmc.mooc.fi/submissions/XXXXXXX
No new points awarded.
Failed: SevenBrothersTest: test_content
        'Simeoni' != 'Aapo'
        - Simeoni
        + Aapo
         : Line 1 in output is incorrect.
Test results: 0/1 tests passed

part01-02_seven_brothers — Tests failed ✗
```

Progress bars, `No Auto-Updates`, and other CLI noise are automatically stripped.

---

## Exercise directory layout

The plugin expects exercises to be stored in the standard tmc-cli-rust layout:

```
<exercises_dir>/
└── <course-name>/
    └── <exercise-name>/
        ├── src/
        └── ...
```

**macOS default:**
```
~/Library/Application Support/tmc/tmc_cli_rust/<course>/<exercise>
```

If your exercises live elsewhere, set `exercises_dir` in `setup()`.

---

## Project root detection (`:TmcTest` / `:TmcSubmit`)

When running tests or submitting via the Vim commands (not the dashboard), the project root is inferred from the current buffer:

- If the current file's directory ends in `src/`, the **parent** directory is used.
- Otherwise the **current file's directory** is used.

When using the dashboard, the exercise directory is resolved directly from `exercises_dir`.

---

## Troubleshooting

### `tmc: command not found`

The binary might be a shell alias that Neovim can't resolve. Set the full path:

```lua
require("tmc_plugin").setup({
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
})
```

### `Exercise not downloaded`

The plugin looked for the exercise at `<exercises_dir>/<course>/<exercise>` but found nothing. Either:
1. Download the exercise first (press `d` in the dashboard), or
2. Verify `exercises_dir` matches where your tmc-cli actually downloads to.

### Commands do not appear

Ensure `require("tmc_plugin").setup()` is called in your Neovim config before you use any `:Tmc*` commands.

### Dashboard shows stale data

Press `r` inside the dashboard to force a full re-sync from TMC servers.

---

## License

MIT
