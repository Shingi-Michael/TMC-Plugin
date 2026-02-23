<h1 align="center">
  <br>
  <img src="https://raw.githubusercontent.com/Shingi-Michael/TMC.nvim/main/assets/logo.png" alt="TMC.nvim" width="200">
  <br>
  TMC.nvim
</h1>

<h4 align="center">A premium, blazingly fast Neovim interface for the <a href="https://github.com/rage/tmc-cli-rust" target="_blank">Test My Code (TMC)</a> framework.</h4>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#commands">Commands</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#health-checks">Health Checks</a>
</p>

---

## 🚀 Features

**TMC.nvim** brings the University of Helsinki's MOOC programming environment directly into your terminal with zero bloat.

- **Native Dashboard**: A beautifully categorized, asynchronous dashboard for managing courses and exercises.
- **Cross-Platform**: Seamlessly detects and resolves paths on **macOS**, **Linux**, and **Windows**.
- **Interactive UI**: Navigate with a floating command palette, live virtual text testing spinners, and colored Nerd Font checkmarks.
- **Contextual Awareness**: Automatically injects dynamic breadcrumb trails into your `winbar` so you always know which exercise you're currently hacking on.
- **System Doctor**: A pristine visual diagnostic modal that instantly pinpoints misconfigurations (binary missing, unauthenticated, wrong folders).
- **Zero Dependencies**: Pure Lua. No `plenary.nvim`, no `telescope.nvim`. Built entirely on Neovim's standard library.

<br>

---

## 📦 Requirements

- **Neovim** `≥ 0.10.0` (Recommended) or `≥ 0.9.0`
- **tmc-cli-rust**: You must install the [native Rust CLI client](https://github.com/rage/tmc-cli-rust).

---

## 🛠 Installation

> **⚠️ IMPORTANT:** The plugin will not load its user commands unless `setup()` is called. 

### [lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
  "Shingi-Michael/TMC.nvim",
  -- Note: Do not `lazy = true` without defining a trigger event.
  config = function()
    require("tmc_plugin").setup()
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
  "Shingi-Michael/TMC.nvim",
  config = function()
    require("tmc_plugin").setup()
  end
}
```

<br>

---

## ⚙️ Configuration

`TMC.nvim` attempts to smartly auto-resolve your `exercises_dir` depending on whether you are on Windows, Mac, or Linux. However, you can explicitly override these settings inside your `setup()` call:

```lua
require("tmc_plugin").setup({
  -- Provide the absolute path to your tmc binary if it is not on your $PATH
  bin = vim.fn.expand("~/tmc-cli-rust-x86_64-apple-darwin-v1.1.2"),

  -- Override the exact root directory where TMC downloads your courses
  -- By default, it natively selects OS-specific paths (e.g., %LOCALAPPDATA%\tmc\tmc_cli_rust)
  exercises_dir = vim.fn.expand("~/my_custom_tmc_folder"),

  -- Base URL used by :TmcInstructions to fetch course-specific manuals
  mooc_url = "https://programming-25.mooc.fi",
})
```

<br>

---

## 🎯 Commands

Access the entirety of the plugin by typing `:TmcMenu` to open the central floating command palette!

| Command | Action | Description |
|---|---|---|
| `:TmcMenu` | **Open Palette** | Opens a centered floating menu to access all commands interactively. *(Recommended)* |
| `:TmcDashboard`| **Dashboard** | View your selected course, track completion stats, and open exercises. |
| `:TmcDownload` | **Download** | Opens a picker to download all exercises for a course. |
| `:TmcTest` | **Run Tests** | Executes `tmc test` locally. Displays a live animated spinner using Virtual Text. |
| `:TmcSubmit` | **Submit Code**| Submits the current exercise to the MOOC.fi servers for official grading. |
| `:TmcNext` | **Next Ex.** | Automatically jumps to the next sequential exercise in the current course. |
| `:TmcPrev` | **Prev Ex.** | Automatically jumps to the previous sequential exercise. |
| `:TmcLogin` | **Authenticate** | Opens a terminal split to securely log in to the TMC servers. |
| `:TmcDoctor` | **Diagnostics** | Opens a visual health dashboard to debug file paths, binaries, and auth state. |

<br>

---

## 🏥 Health Checks (`:TmcDoctor`)

If you are having trouble running tests or downloading courses, simply run:
```vim
:TmcDoctor
```

This will launch a dedicated floating diagnostic window that verifies:
1. **Binary Detection**: Checks if `tmc` is executable on your system.
2. **Neovim Version**: Ensures you have standard library support.
3. **Authentication**: Pings the TMC severs to confirm your token is valid.
4. **Context**: Checks if the file you currently have open geometrically belongs to a TMC exercise folder.

---

<p align="center">
  Built with ☕ by <a href="https://github.com/Shingi-Michael">Shingi-Michael</a><br>
  Released under the MIT License
</p>
