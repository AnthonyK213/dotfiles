local lib = require("nviq.util.lib")
local putil = require("nviq.util.p")

---@class nviq.core.settings.LspSpec
---@field enable? boolean
---@field install? boolean
---@field settings? table

---@class nviq.core.settings.DapSpec
---@field enable? boolean
---@field install? boolean

local settings = {
  general = {
    offline  = true,
    proxy    = nil,
    shell    = ({
      [putil.OS.Unknown] = "bash",
      [putil.OS.Linux]   = "bash",
      [putil.OS.Windows] = { "powershell.exe", "-nologo" },
      [putil.OS.MacOS]   = "zsh",
    })[putil.os_type()],
    upgrade  = false,
    auto_ime = false,
  },
  path = {
    home    = vim.env.HOME,
    desktop = vim.fs.joinpath(vim.env.HOME, "Desktop"),
    vimwiki = vim.fs.joinpath(vim.env.HOME, "vimwiki"),
  },
  tui = {
    scheme        = "default",
    theme         = "dark",
    style         = "dark",
    transparent   = false,
    global_status = false,
    border        = "none",
    auto_dim      = false,
    devicons      = false,
  },
  gui = {
    theme        = "dark",
    opacity      = 1.0,
    ligature     = false,
    popup_menu   = false,
    tabline      = false,
    scroll_bar   = false,
    cursor_blink = false,
    line_space   = 0.0,
    font_size    = 13,
    font_half    = "Monospace",
    font_wide    = "Monospace",
  },
  ---@type table<string, nviq.core.settings.LspSpec>
  lsp = {},
  ---@type table<string, nviq.core.settings.DapSpec>
  dap = {},
  ts = {
    ---@type string[]
    parsers = {},
  },
}

-- Merge custom settings.
local exists, opt_file = lib.get_dotfile("nvimrc")
if exists and opt_file then
  local code, result = lib.json_decode(opt_file, true)
  -- TODO: Validate `result` with `schema.json`.
  if code == 0 then
    settings = vim.tbl_deep_extend("force", settings, result)
  else
    lib.warn("nvimrc is invalid.")
  end
end

-- Normalize the paths.
for k, v in pairs(settings.path) do
  settings.path[k] = vim.fs.normalize(v)
end

_G.NVIQ.settings = settings
