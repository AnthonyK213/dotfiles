local _augroup = vim.api.nvim_create_augroup("nviq.appl", { clear = true })

-- Emacs

require("nviq.appl.emacs")

-- Autopair

require("nviq.appl.autopair").setup {
  pairs = {
    ["()"]  = { left = "(", right = ")" },
    ["[]"]  = { left = "[", right = "]" },
    ["{}"]  = { left = "{", right = "}" },
    ["''"]  = { left = "'", right = "'" },
    ['""']  = { left = '"', right = '"' },
    tex_bf  = { left = "\\textbf{", right = "}" },
    tex_it  = { left = "\\textit{", right = "}" },
    tex_rm  = { left = "\\textrm{", right = "}" },
    md_p    = { left = "`", right = "`" },
    md_i    = { left = "*", right = "*" },
    md_b    = { left = "**", right = "**" },
    md_m    = { left = "***", right = "***" },
    md_u    = { left = "<u>", right = "</u>" },
    paren   = { left = "（", right = "）" },
    brack   = { left = "【", right = "】" },
    quine   = { left = "「", right = "」" },
    title_1 = { left = "〈", right = "〉" },
    title_2 = { left = "《", right = "》" },
    quote_1 = { left = "‘", right = "’" },
    quote_2 = { left = "“", right = "”" },
  },
  keymaps = {
    ["("] = { action = "open", pair = "()" },
    [")"] = { action = "close", pair = "()" },
    ["["] = { action = "open", pair = "[]" },
    ["]"] = { action = "close", pair = "[]" },
    ["{"] = { action = "open", pair = "{}" },
    ["}"] = { action = "close", pair = "{}" },
    ["'"] = {
      action = "closeopen",
      pair = {
        ["_"] = "''",
        lisp = "",
        rust = "",
      }
    },
    ['"'] = { action = "closeopen", pair = '""' },
    ["<M-P>"] = {
      action = "closeopen",
      pair = {
        markdown = "md_p",
      }
    },
    ["<M-I>"] = {
      action = "closeopen",
      pair = {
        markdown = "md_i",
        tex = "tex_it",
      }
    },
    ["<M-B>"] = {
      action = "closeopen",
      pair = {
        markdown = "md_b",
        tex = "tex_bf",
      }
    },
    ["<M-N>"] = {
      action = "closeopen",
      pair = {
        markdown = "tex_rm",
        tex = "tex_rm",
      }
    },
    ["<M-M>"] = {
      action = "closeopen",
      pair = {
        markdown = "md_m"
      }
    },
    ["<M-U>"] = {
      action = "closeopen",
      pair = {
        markdown = "md_u"
      }
    },
    ["（"] = { action = "open", pair = "paren" },
    ["）"] = { action = "close", pair = "paren" },
    ["【"] = { action = "open", pair = "brack" },
    ["】"] = { action = "close", pair = "brack" },
    ["「"] = { action = "open", pair = "quine" },
    ["」"] = { action = "close", pair = "quine" },
    ["〈"] = { action = "open", pair = "title_1" },
    ["〉"] = { action = "close", pair = "title_1" },
    ["《"] = { action = "open", pair = "title_2" },
    ["》"] = { action = "close", pair = "title_2" },
    ["‘"] = { action = "open", pair = "quote_1" },
    ["’"] = { action = "close", pair = "quote_1" },
    ["“"] = { action = "open", pair = "quote_2" },
    ["”"] = { action = "close", pair = "quote_2" },
  }
}

-- Commenting

vim.keymap.set("n", "<leader>kc", function()
  return require("vim._comment").operator() .. "_"
end, { expr = true, desc = "Toggle comment line" })

vim.keymap.set("n", "<leader>ku", function() end)

vim.keymap.set("x", "<leader>kc", function()
  return require("vim._comment").operator()
end, { expr = true, desc = "Toggle comment" })

vim.keymap.set("x", "<leader>ku", function() end)

-- Surrounding

vim.keymap.set({ "n", "x" }, "<leader>sa", function()
  if not vim.bo.modifiable then return end
  local mode = require("nviq.util.lib").get_mode()
  require("nviq.util.k").to_normal()
  local futures = require("nviq.util.futures")
  futures.spawn(function()
    local left = futures.ui.input { prompt = "Insert surrounding: " }
    if not left then return end
    require("nviq.appl.surround").insert(mode, left, _G.NVIQ.handlers.get_word)
  end)
end, { desc = "Insert surrounding" })

vim.keymap.set("n", "<leader>sd", function()
  if not vim.bo.modifiable then return end
  local futures = require("nviq.util.futures")
  futures.spawn(function()
    local left = futures.ui.input { prompt = "Delete surrounding: " }
    if not left then return end
    require("nviq.appl.surround").delete(left)
  end)
end, { desc = "Delete surrounding" })

vim.keymap.set("n", "<leader>sc", function()
  if not vim.bo.modifiable then return end
  local futures = require("nviq.util.futures")
  futures.spawn(function()
    local old = futures.ui.input { prompt = "Change surrounding: " }
    if not old then return end
    local new = futures.ui.input { prompt = "New surrounding: " }
    if not new then return end
    require("nviq.appl.surround").change(old, new)
  end)
end, { desc = "Change surrounding" })

---
---@param lhs string
---@param pair string|string[]
---@param pattern? string
---@param opts? vim.keymap.set.Opts
local function surround_toggle(lhs, pair, pattern, opts)
  vim.keymap.set({ "n", "x" }, lhs, function()
    local lib = require("nviq.util.lib")
    local mode = lib.get_mode()
    if mode == lib.Mode.Normal and pattern and require("nviq.util.syntax").Syntax.get():match(pattern) then
      require("nviq.appl.surround").delete(pair)
    else
      require("nviq.util.k").to_normal()
      require("nviq.appl.surround").insert(mode, pair, _G.NVIQ.handlers.get_word)
    end
  end, opts)
end

vim.api.nvim_create_autocmd("FileType", {
  group = _augroup,
  pattern = { "markdown" },
  callback = function(event)
    ---@type vim.keymap.set.Opts
    local opts = { buf = event.buf }
    surround_toggle("<M-P>", "`", [[\vmarkdownCode|raw]], opts)
    surround_toggle("<M-I>", "*", [[\vmarkdownItalic|italic]], opts)
    surround_toggle("<M-B>", "**", [[\vmarkdownBold|strong]], opts)
    surround_toggle("<M-M>", "***", [[\vmarkdownBoldItalic|strong|italic]], opts)
    surround_toggle("<M-U>", "<u>", [[\vhtmlUnderline]], opts)
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = _augroup,
  pattern = "tex",
  callback = function(event)
    ---@type vim.keymap.set.Opts
    local opts = { buf = event.buf }
    surround_toggle("<M-I>", { "\\textit{", "}" }, [[\vtexStyle(Ital|Both)]], opts)
    surround_toggle("<M-B>", { "\\textbf{", "}" }, [[\vtexStyleBo(ld|th)]], opts)
    surround_toggle("<M-M>", { "\\textrm{", "}" }, [[\vtex(StyleArgConc|MathTextConcArg)]], opts)
  end,
})

-- Evaluate

vim.keymap.set("n", "<leader>el", function()
  local lib = require("nviq.util.lib")
  local l_lin, l_col, r_lin, r_col = lib.search_pair_pos("(", ")")
  if l_lin < 0 or l_col < 0 or r_lin < 0 or r_col < 0 then return end
  local txt = vim.api.nvim_buf_get_text(0, l_lin, l_col, r_lin, r_col + 1, {})
  local str = table.concat(txt, " ")
  local ok, result = pcall(require("nviq.appl.evaluate").eval, str)
  if not ok then
    lib.warn("Invalid expression")
    return
  end
  vim.api.nvim_buf_set_text(0, l_lin, l_col, r_lin, r_col + 1, { tostring(result) })
end, { desc = "Evaluate lisp expression" })

-- Rust modules

vim.api.nvim_create_user_command("BuildCrates", function(tbl)
  local rsmod = require("nviq.appl.rsmod")
  local crates = rsmod.find_crates()
  local args = tbl.args
  if args:len() == 0 then
    rsmod.build_crates(crates)
  elseif crates[args] then
    rsmod.build_crates { [args] = crates[args] }
  else
    vim.notify("Crate was not found")
  end
end, {
  nargs = "?",
  complete = function()
    local crates = require("nviq.appl.rsmod").find_crates()
    return vim.tbl_keys(crates)
  end,
  desc = "Build crates in this configuration"
})

-- Jieba

vim.keymap.set("n", "<leader>jm", function()
  local jieba = require("nviq.appl.jieba")
  if jieba.is_enabled() then
    jieba:disable()
    vim.notify("Jieba is disabled")
  else
    if jieba:enable() then
      vim.notify("Jieba is enabled")
    end
  end
end, { desc = "Toggle jieba-mode" })

-- Stardict

vim.keymap.set({ "n", "x" }, "<leader>hh", function()
  local lib = require("nviq.util.lib")
  local word
  local mode = lib.get_mode()
  if mode == lib.Mode.Normal then
    word = NVIQ.handlers.get_word()
  elseif mode == lib.Mode.Visual then
    word = lib.get_gv()
  else
    return
  end
  require("nviq.appl.stardict").stardict(word)
end, { desc = "Look up the word under the cursor" })

-- IME

if _G.NVIQ.settings.general.auto_ime then
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = _augroup,
    callback = function(event)
      local ime = require("nviq.appl.ime")
      vim.b[event.buf].nviq_ime_insert_mode = ime.get()
      ime.set(ime.Layout.US)
    end
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = _augroup,
    callback = function(event)
      local layout = vim.b[event.buf].nviq_ime_insert_mode
      if layout then
        require("nviq.appl.ime").set(layout)
      end
    end
  })
end
