vim.keymap.set("t", "<ESC><ESC>", "<C-\\><C-N>", {
  desc = "Switch to normal mode in terminal"
})

vim.keymap.set("t", "<M-d>", "<C-\\><C-N><Cmd>bd!<CR>", {
  desc = "Close the terminal"
})

vim.keymap.set("n", "<M-g>", ":%s/", {
  desc = "Find and replace",
})

vim.keymap.set("v", "<M-g>", ":s/", {
  desc = "Find and replace",
})

vim.keymap.set("n", "<leader>bh", "<Cmd>noh<CR>", {
  desc = "Stop the search highlighting"
})

vim.keymap.set("n", "<leader>cs", "<Cmd>setlocal spell! spelllang=en_us<CR>", {
  desc = "Toggle spell check"
})

vim.keymap.set("v", "<M-c>", [["+y]], {
  desc = "Copy to system clipboard"
})

vim.keymap.set("v", "<M-x>", [["+x]], {
  desc = "Cut to system clipboard"
})

vim.keymap.set({ "n", "v" }, "<M-v>", [["+p]], {
  desc = "Paste from system clipboard"
})

vim.keymap.set("i", "<M-v>", "<C-R>=@+<CR>", {
  desc = "Paste from system clipboard"
})

vim.keymap.set("n", "<M-a>", "ggVG", {
  desc = "Select all lines in buffer"
})

vim.keymap.set("n", "<M-,>", function()
  local lib = require("nviq.util.lib")
  local exists, opt_file = lib.get_dotfile("nvimrc")
  local cfg_dir = vim.fn.stdpath("config")
  if exists and opt_file then
    lib.edit_file(opt_file)
    vim.api.nvim_set_current_dir(cfg_dir)
  elseif opt_file then
    vim.cmd.new(opt_file)
    local schema_uri = vim.uri_from_fname(vim.fs.joinpath(cfg_dir, "schema.json"))
    vim.api.nvim_buf_set_lines(0, 0, 1, true, {
      "{",
      string.format([[  "$schema": "%s"]], schema_uri),
      "}",
    })
  else
    vim.notify("Configuration directory not found")
  end
end, { desc = "Open nvimrc" })

for dir, key in pairs { h = "left", j = "down", k = "up", l = "right" } do
  vim.keymap.set("n", "<M-" .. dir .. ">", function()
    require("nviq.util.k").feedkeys("<C-W>" .. dir, "nx")
  end, { desc = "Move cursor to window: " .. key })
end

vim.keymap.set("n", "<leader>bg", function()
  if vim.is_callable(_G.NVIQ.handlers.set_theme) then
    local theme = vim.o.background == "dark" and "light" or "dark"
    _G.NVIQ.handlers.set_theme(theme)
  end
end, { desc = "Toggle background theme" })

-- Buffer

vim.keymap.set("n", "<leader>bc", function()
  vim.api.nvim_set_current_dir(require("nviq.util.lib").buf_dir())
  vim.cmd.pwd()
end, { desc = "Change cwd to current buffer" })

vim.keymap.set("n", "<leader>bd", function()
  if vim.wo.winfixbuf then
    pcall(vim.cmd.close)
    return
  end

  local buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_call(buf, function()
    local no_layout = vim.list_contains({
      "help", "terminal", "quickfix", "nofile"
    }, vim.bo.buftype)

    if not no_layout then
      for _, win in ipairs(vim.fn.win_findbuf(buf)) do
        if vim.api.nvim_win_is_valid(win) and
            vim.api.nvim_win_get_buf(win) == buf then
          vim.api.nvim_win_call(win, function()
            -- Try using alternate buffer
            local alt = vim.fn.bufnr("#")
            if alt ~= buf and vim.fn.buflisted(alt) == 1 then
              vim.api.nvim_win_set_buf(win, alt)
              return
            end

            -- Try using previous buffer
            local has_previous = pcall(vim.cmd.bprevious)
            if has_previous and buf ~= vim.api.nvim_win_get_buf(win) then
              return
            end

            -- Create new listed buffer
            local new_buf = vim.api.nvim_create_buf(true, false)
            vim.api.nvim_win_set_buf(win, new_buf)
          end)
        end
      end
    end

    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.cmd.bdelete, buf)
    end
  end)
end, { desc = "Delete current buffer" })

vim.keymap.set("n", "<leader>bn", "<Cmd>bn<CR>", {
  desc = "Next buffer"
})

vim.keymap.set("n", "<leader>bp", "<Cmd>bp<CR>", {
  desc = "Previous buffer"
})

-- Open

vim.keymap.set("n", "<leader>oe", function()
  local lib = require("nviq.util.lib")
  lib.open(lib.buf_dir())
end, { desc = "Open file manager" })

vim.keymap.set("n", "<leader>ou", function()
  local lib = require("nviq.util.lib")
  local path = lib.get_url_or_path()
  if not path then
    lib.warn("Path not found")
    return
  end
  lib.open(path)
end, { desc = "Open URL or path under the cursor" })

-- Search

for key, val in pairs {
  Bing       = { "b", "https://www.bing.com/search?q=" },
  DuckDuckGo = { "d", "https://duckduckgo.com/?q=" },
  Google     = { "g", "https://www.google.com/search?q=" },
} do
  vim.keymap.set({ "n", "x" }, "<leader>h" .. val[1], function()
    local lib = require("nviq.util.lib")
    local txt
    local mode = lib.get_mode()
    if mode == lib.Mode.Normal then
      local word = _G.NVIQ.handlers.get_word()
      txt = vim.uri_encode(word)
    elseif mode == lib.Mode.Visual then
      txt = vim.uri_encode(lib.get_gv())
    else
      return
    end
    vim.ui.open(val[2] .. txt)
  end, { desc = "Search <cword>/selection with " .. key })
end

-- Preview

vim.keymap.set("n", "<leader>pt", function()
  if vim.is_callable(vim.b.nviq_handler_preview_toggle) then
    vim.b.nviq_handler_preview_toggle()
  else
    vim.notify("No preview available")
  end
end, { desc = "Toggle preview" })
