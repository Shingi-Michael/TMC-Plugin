# TMC-Plugin — Developer Reference

> For installation instructions see the [root README](../../README.md).

---

## ⚠️ `setup()` is required

The plugin registers no commands until `setup()` is called. Always include this in your Neovim config:

```lua
require("tmc_plugin").setup({
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),
})
```

---

## Module overview

| File | Purpose |
|---|---|
| `init.lua` | Entry point — `setup()` sets config and registers all `:Tmc*` commands |
| `config.lua` | Shared config table (`bin`, `exercises_dir`) |
| `api.lua` | Public API — courses, exercises, test, submit, download, login, doctor |
| `dashboard.lua` | Interactive exercise dashboard (buffer + keymaps) |
| `menu.lua` | Floating command palette (`:TmcMenu`) |
| `system.lua` | Thin async wrapper around `vim.system` |
| `ui.lua` | Progress bars, virtual text, log windows, notify helper |

---

## `setup()` options

```lua
require("tmc_plugin").setup({
  -- Path or name of the tmc-cli-rust binary. Default: "tmc"
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),

  -- Root where tmc-cli stores exercises.
  -- Default: ~/Library/Application Support/tmc/tmc_cli_rust  (macOS)
  exercises_dir = "~/Library/Application Support/tmc/tmc_cli_rust",
})
```

---

## Commands (registered by `setup()`)

| Command | API function | Description |
|---|---|---|
| `:TmcMenu` | `menu.open()` | Floating command palette |
| `:TmcDashboard` | `api.open_dashboard()` | Course picker → exercise dashboard |
| `:TmcTest` | `api.test()` | Run `tmc test` (must be inside `exercises_dir`) |
| `:TmcSubmit` | `api.submit()` | Submit with a live streaming log window |
| `:TmcNext` | `api.next()` | Open next exercise, download prompt if needed |
| `:TmcPrev` | `api.prev()` | Open previous exercise, boundary message at ends |
| `:TmcDoctor` | `api.doctor()` | Check TMC auth / connectivity |
| `:TmcLogin` | `api.login()` | Terminal split for `tmc login` |

---

## Dashboard keymaps

| Key | Action |
|---|---|
| `<Enter>` | Test exercise under cursor |
| `s` | Submit exercise under cursor |
| `d` | Download exercise under cursor |
| `r` | Force-refresh from TMC servers |
| `q` | Close dashboard |

---

## Exercise path convention

```
<exercises_dir>/
└── <course-name>/
    └── <exercise-name>/
        └── src/  (project root for test/submit)
```

**macOS default:**
```
~/Library/Application Support/tmc/tmc_cli_rust/<course>/<exercise>
```

---

## Circular dependency note

`api.lua` lazy-requires `dashboard.lua` (via `require("tmc_plugin.dashboard")` inside callbacks).  
`dashboard.lua` lazy-requires `api.lua` for the same reason.  
Neither module requires the other at the top level — this is intentional.

---

## Navigation internals

`api.next()` / `api.prev()` are implemented with three local helpers:

| Helper | What it does |
|---|---|
| `detect_exercise()` | Parses the current file path into `{ course, name, index, exercises }` |
| `find_source_file(dir)` | Globs `src/**/*`, skips compiled extensions (`.pyc`, `.class`, etc.) |
| `navigate_to_exercise(ctx, ex)` | Checks disk, shows `ui.confirm_dialog` if not downloaded, opens file |

`dashboard.scroll_to_exercise(name)` uses a dedicated `NS_NAV` namespace for the  
flash highlight so it doesn’t disturb the dashboard’s own render highlights.

`ui.confirm_dialog(opts)` is a reusable floating prompt — see `ui.lua` for the opts shape.
