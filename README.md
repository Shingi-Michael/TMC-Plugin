# TMC-Plugin

A Neovim interface for the **Test My Code (TMC)** framework, allowing you to manage courses, download exercises, and run tests without leaving your editor.

---

## Features

- **Course & Exercise Management:** Browse courses and exercises and download content from within Neovim (Telescope-powered UI when available).
- **Background Testing:** Run TMC tests asynchronously with virtual text status updates.
- **Integrated Diagnostics:** Built-in `:TmcDoctor` to verify your binary, authentication, and basic connectivity.
- **Log Navigation:** View detailed test output in a dedicated, scrubbed log window.

---

## Getting Started

### Dependencies

- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- **TMC CLI:** Install the official TMC CLI binary from the rust implementation:
  - https://github.com/rage/tmc-cli-rust

> Note: Ensure the TMC binary is available on your `PATH` (e.g., `tmc`) or configure the absolute path via `setup({ bin = ... })`.

---

## Installation

### lazy.nvim

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
      bin = "tmc",
    })
  end,
}
```

---

## Configuration

### `setup()`

```lua
require("tmc_plugin").setup({
  bin = "tmc", -- optional; defaults to "tmc"
})
```

#### Options

| Option | Type   | Default | Description |
|--------|--------|---------|-------------|
| `bin`  | string | `"tmc"` | Path or name of the TMC CLI executable |

---

## Commands

After calling `setup()`, these commands are available:

| Command       | Description |
|---------------|-------------|
| `:TmcMenu`    | Open the main menu |
| `:TmcTest`    | Run `tmc test` in the detected project root |
| `:TmcSubmit`  | Run `tmc submit` in a terminal split |
| `:TmcStatus`  | Course progress flow (course → exercise) |
| `:TmcCourses` | Download flow (course → exercise → download) |
| `:TmcDoctor`  | Verify TMC authentication/connectivity |
| `:TmcLogin`   | Run `tmc login` in a terminal split |

---

## Behavior Notes

### Project root detection (tests)

When running tests, the plugin determines the project root from the current buffer path:

- If the current file lives inside a directory named `src/`, the parent directory is used.
- Otherwise the current file’s directory is used.

### Downloads

Exercises are downloaded to:

```
~/tmc_exercises/<course>
```

The directory is created automatically if it does not exist.

---

## Troubleshooting

### `tmc: command not found`

Set the binary explicitly:

```lua
require("tmc_plugin").setup({
  bin = "/full/path/to/tmc",
})
```

### Commands do not appear

Ensure `require("tmc_plugin").setup()` is called in your Neovim configuration.

---

## License

MIT
