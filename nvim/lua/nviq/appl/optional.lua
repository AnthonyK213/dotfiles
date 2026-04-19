local _augroup = vim.api.nvim_create_augroup("nviq.appl.optional", { clear = true })

-- Bigfile

require("nviq.appl.bigfile").setup {
  max_size        = 1.5 * 1024 * 1024,
  max_line_length = 1024,
}

-- GLSL

vim.api.nvim_create_autocmd("FileType", {
  group = _augroup,
  pattern = "glsl",
  callback = function(event)
    -- WORKAROUND: `omnifunc` cannot handle `v:lua` with `require`, the module
    -- must be global, or the omnifunc-completion won't work with `i_CTRL-X_CTRL-O`.
    if not _G._NVIQ_APPL_GLSL_OMNIFUNC then
      _G._NVIQ_APPL_GLSL_OMNIFUNC = require("nviq.appl.glsl").omnifunc
    end
    vim.bo[event.buf].omnifunc = "v:lua._NVIQ_APPL_GLSL_OMNIFUNC"
    -- vim.bo[event.buf].omnifunc = "v:lua.require('nviq.appl.glsl').omnifunc"

    vim.b[event.buf].nviq_handler_preview_toggle = require("nviq.appl.glsl").toggle
  end,
})

vim.api.nvim_create_user_command("GlslViewer", function(tbl)
  require("nviq.appl.glsl").start(0, tbl.fargs)
end, { nargs = "*", desc = "Start GlslViewer", complete = "file" })

vim.api.nvim_create_user_command("GlslViewerInput", function(_)
  require("nviq.appl.glsl").input(0)
end, { desc = "GlslViewer input commands" })

-- Markdown

---Checks whether `chunk` is a markdown list marker (with a suffix space).
---@param chunk string
---@return boolean
local function is_after_md_list_item(chunk)
  if not chunk then return false end
  return vim.regex([[\v^\s*(\+|-|\*|\d+\.|\w\))(\s\[.\])?\s$]]):match_str(chunk) ~= nil
end

vim.keymap.set("i", "<M-CR>", function()
  local lib = require("nviq.util.lib")
  local kutil = require("nviq.util.k")

  if not lib.has_filetype("markdown") then
    kutil.feedkeys("<C-O>o", "in")
    return
  end

  local markdown = require("nviq.appl.markdown")

  local region = markdown.ListItemRegion.get(0)

  if not region then
    kutil.feedkeys("<C-O>o", "in")
    return
  end

  local new_bullet = region.bullet
  if region.ordered then
    new_bullet = markdown.bullet_increment(region.bullet) or region.bullet
  end

  local new_line = string.rep(" ", region.indent) .. new_bullet .. " "
  vim.api.nvim_buf_set_lines(0, region.end_, region.end_, true, { new_line })

  local col = #new_line
  if region.ordered then
    markdown.regen_ordered_list(0, region.end_, { forward_only = true })
    col = vim.api.nvim_buf_get_lines(0, region.end_, region.end_ + 1, true)[1]:len()
  end

  vim.api.nvim_win_set_cursor(0, { region.end_ + 1, col })
end, { desc = "Insert new list item" })

vim.keymap.set("i", "<Tab>", function()
  local lib = require("nviq.util.lib")
  local kutil = require("nviq.util.k")

  if lib.has_filetype("markdown") then
    local back = lib.get_half_line(-1).b
    if is_after_md_list_item(back) then
      kutil.feedkeys("<C-\\><C-O>>>" .. string.rep(kutil.dir_key("r"), vim.bo.tabstop), "in")
      return
    end
  end
  kutil.feedkeys("<Tab>", "in")
end, { desc = "Indent markdown list item rightwards" })

vim.keymap.set("i", "<S-Tab>", function()
  local lib = require("nviq.util.lib")
  local kutil = require("nviq.util.k")

  if lib.has_filetype("markdown") then
    local back = lib.get_half_line(-1).b
    if is_after_md_list_item(back) then
      local indent = vim.fn.indent(".")
      if indent == 0 then return end
      local pos = vim.api.nvim_win_get_cursor(0)
      kutil.feedkeys("<C-\\><C-O><<", "in")
      pos[2] = pos[2] - math.min(indent, vim.bo.tabstop)
      vim.api.nvim_win_set_cursor(0, pos)
      return
    end
  end
  kutil.feedkeys("<S-Tab>", "in")
end, { desc = "Indent markdown list item leftwards" })

vim.keymap.set("n", "<leader>ml", function()
  if require("nviq.util.lib").has_filetype("markdown") then
    require("nviq.appl.markdown").regen_ordered_list()
  end
end, { desc = "Regenerate bullets for ordered list" })

-- Marp

vim.api.nvim_create_user_command("MarpToggle", function(_)
  require("nviq.appl.marp").toggle()
end, { desc = "Toggle marp-cli" })

-- Markdown Preview

vim.api.nvim_create_autocmd("FileType", {
  group = _augroup,
  pattern = { "markdown" },
  callback = function(event)
    vim.b[event.buf].nviq_handler_preview_toggle = require("nviq.appl.mdp").toggle
  end,
})

-- Template

vim.api.nvim_create_user_command("CreateProject", function(_)
  require("nviq.appl.template"):create_project()
end, { desc = "Create project with templates" })

-- Run

vim.api.nvim_create_user_command("CodeRun", function(tbl)
  local lib = require("nviq.util.lib")
  local run = require("nviq.appl.run")
  local filetype = vim.bo.filetype
  local recipe = run.get_recipe(filetype)
  if not recipe then
    lib.warn("File type " .. filetype .. " is not supported")
    return
  end
  local option = tbl.args:len() > 0 and tbl.args or 1
  local task = recipe[option]
  if not task then
    lib.warn("Option is invalid")
    return
  end
  run.task_run(task, {
    file_name = vim.api.nvim_buf_get_name(0),
    file_dir  = lib.buf_dir(0),
    file_type = filetype,
  })
end, {
  nargs = "?",
  complete = function()
    local run = require("nviq.appl.run")
    local recipe = run.get_recipe(vim.bo.filetype)
    if not recipe then return {} end
    return run.recipe_get_options(recipe)
  end,
  desc = "Run code in current buffer",
})

-- Terminal

vim.keymap.set("n", "<leader>on", function()
  require("nviq.appl.terminal").new()
end, { desc = "Open a new terminal" })

vim.keymap.set("n", "<leader>ot", function()
  require("nviq.appl.terminal").toggle()
end, { desc = "Toggle terminals" })

vim.api.nvim_create_user_command("ToggleTerm", function(tbl)
  local args = tbl.args
  local term = require("nviq.appl.terminal")
  if args == "" or args == "toggle" then
    term.toggle()
  elseif args == "new" then
    term.new()
  elseif args == "close" then
    term.close()
  elseif args == "hide" then
    term.hide()
  else
    vim.notify("Invalid argument", vim.log.levels.WARN)
  end
end, {
  nargs = "?",
  complete = function() return { "new", "toggle", "close", "hide" } end,
  desc = "Toggle terminals",
})

-- Color scheme

if vim.list_contains({
      "default",
      "catppuccin",
      "lunaperche",
    }, _G.NVIQ.settings.tui.scheme) then
  vim.cmd.colorscheme(_G.NVIQ.settings.tui.scheme)
end

-- Theme

require("nviq.appl.theme").set_theme(_G.NVIQ.settings.tui.theme)

-- Upgrade

vim.api.nvim_create_user_command("NvimUpgrade", function(tbl)
  if not _G.NVIQ.settings.general.upgrade then
    vim.notify("NvimUpgrade is disabled", vim.log.levels.WARN)
    return
  end
  require("nviq.appl.upgrade").nvim_upgrade(tbl.args)
end, {
  nargs = "?",
  complete = function() return { "stable", "nightly" } end,
  desc = "Upgrade Neovim by channel"
})
