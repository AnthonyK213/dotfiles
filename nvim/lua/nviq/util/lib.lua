local futil = require("nviq.util.f")
local putil = require("nviq.util.p")
local sutil = require("nviq.util.s")

local M = {}

---@enum nviq.util.lib.Mode
M.Mode = {
  Normal    = 0,
  Insert    = 1,
  Visual    = 2,
  Command   = 3,
  Replace   = 4,
  Select    = 5,
  Ex        = 6,
  More      = 7,
  Confirm   = 8,
  Shell     = 9,
  Terminal  = 10,
  O_Pending = 11,
}

local _p_word_first_half = [[\v([\]] .. [[u4e00-\]] .. [[u9fff0-9a-zA-Z_-]+)$]]
local _p_word_last_half = [[\v^([\]] .. [[u4e00-\]] .. [[u9fff0-9a-zA-Z_-])+]]

---@type table<string, nviq.util.lib.Mode>
local _mode_map = {
  ["n"]     = M.Mode.Normal,
  ["no"]    = M.Mode.O_Pending,
  ["nov"]   = M.Mode.O_Pending,
  ["noV"]   = M.Mode.O_Pending,
  ["no\22"] = M.Mode.O_Pending,
  ["niI"]   = M.Mode.Normal,
  ["niR"]   = M.Mode.Normal,
  ["niV"]   = M.Mode.Normal,
  ["nt"]    = M.Mode.Normal,
  ["ntT"]   = M.Mode.Normal,
  ["v"]     = M.Mode.Visual,
  ["vs"]    = M.Mode.Visual,
  ["V"]     = M.Mode.Visual,
  ["Vs"]    = M.Mode.Visual,
  ["\22"]   = M.Mode.Visual,
  ["\22s"]  = M.Mode.Visual,
  ["s"]     = M.Mode.Select,
  ["S"]     = M.Mode.Select,
  ["\19"]   = M.Mode.Select,
  ["i"]     = M.Mode.Insert,
  ["ic"]    = M.Mode.Insert,
  ["ix"]    = M.Mode.Insert,
  ["R"]     = M.Mode.Replace,
  ["Rc"]    = M.Mode.Replace,
  ["Rx"]    = M.Mode.Replace,
  ["Rv"]    = M.Mode.Replace,
  ["Rvc"]   = M.Mode.Replace,
  ["Rvx"]   = M.Mode.Replace,
  ["c"]     = M.Mode.Command,
  ["cr"]    = M.Mode.Command,
  ["cv"]    = M.Mode.Ex,
  ["cvr"]   = M.Mode.Ex,
  ["r"]     = M.Mode.Replace,
  ["rm"]    = M.Mode.More,
  ["r?"]    = M.Mode.Confirm,
  ["!"]     = M.Mode.Shell,
  ["t"]     = M.Mode.Terminal,
}

---Returns the directory of the buffer with bufnr.
---@param bufnr? integer The buffer number, default 0 (current buffer).
---@return string buf_dir The buffer directory.
function M.buf_dir(bufnr)
  return vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr or 0))
end

---Returns an array of listed buffer handles.
---@return integer[] bufs Loaded buffer handles.
function M.buf_listed()
  return vim.tbl_filter(function(h)
    return vim.api.nvim_buf_is_loaded(h) and vim.bo[h].buflisted
  end, vim.api.nvim_list_bufs())
end

---Extracts the buffer handle.
---@param bufnr? integer
---@return integer
function M.bufnr(bufnr)
  if bufnr == 0 or not bufnr then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

---Limits a value within a range \[min_value, max_value\]
---@generic T
---@param value T
---@param min_value T
---@param max_value T
---@return T
function M.clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

---Open and edit a file.
---@param path string The file path.
---@param option? {chdir:boolean?, new_tab:boolean?, silent:boolean?}
function M.edit_file(path, option)
  path = vim.fs.normalize(path)
  option = option or {}

  if not futil.is_file(path) then return end

  if option.new_tab then
    vim.cmd.tabnew {
      args = { path },
      mods = { silent = (option.silent == true) }
    }
  else
    vim.cmd.edit {
      args = { path },
      mods = { silent = (option.silent == true) }
    }
  end

  if option.chdir then
    vim.api.nvim_set_current_dir(vim.fs.dirname(path))
  end
end

---Returns a float option with limited size depends on the editor size.
---@return vim.lsp.util.open_floating_preview.Opts
function M.flex_float()
  return {
    max_width  = math.max(1, math.floor(vim.o.columns * 0.8)),
    max_height = math.max(1, math.floor(vim.o.lines * 0.8)),
  }
end

---Returns the path of the dotfile (.nvimrc, etc.).
---Searching order: stdpath("config") -> home -> ...
---Uses the last one was found.
---@param name string Name of the dotfile (with out '.' or '\_' at the start).
---@return boolean exists True if the option file exists.
---@return string? path Path to the dotfile.
function M.get_dotfile(name)
  local dir_table = {
    vim.fn.stdpath("config"),
    vim.uv.os_homedir(),
  }

  local ok_index = 0
  local file_name

  for i, dir in ipairs(dir_table) do
    ok_index = i
    file_name = "/." .. name
    local file_path = dir .. file_name
    if futil.is_file(file_path) then
      return true, file_path
    elseif putil.os_type() == putil.OS.Windows then
      file_name = "/_" .. name
      file_path = dir .. file_name
      if futil.is_file(file_path) then
        return true, file_path
      end
    end
  end

  if ok_index > 0 then
    return false, dir_table[ok_index] .. file_name
  else
    return false, nil
  end
end

---Returns the visual selections.
---@return string selection Visual selection.
function M.get_gv()
  local mode = M.get_mode()
  local a_bak = vim.fn.getreg("a", 1)
  vim.cmd.normal {
    (mode == M.Mode.Visual and "" or "gv") .. [["ay]],
    mods = { silent = true }
  }
  local a_val = vim.fn.getreg("a")
  vim.fn.setreg("a", a_bak)
  return a_val
end

---Returns the start and end positions of visual selection.
---@param bufnr? integer Buffer number, default 0 (current buffer).
---@return integer row_s Start row (0-based, inclusive).
---@return integer col_s Start column (0-based, inclusive).
---@return integer row_e End row (0-based, exclusive).
---@return integer col_e End column (0-based, exclusive).
function M.get_gv_mark(bufnr)
  bufnr = bufnr or 0
  local s_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
  local e_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
  local e_len = #vim.api.nvim_buf_get_lines(bufnr, e_pos[1] - 1, e_pos[1], true)[1]

  if e_pos[2] >= e_len then
    e_pos[2] = math.max(0, e_len - 1)
  end

  local e_txt = vim.api.nvim_buf_get_text(bufnr, e_pos[1] - 1, e_pos[2], e_pos[1] - 1, -1, {})[1]
  local d = #sutil.sub(e_txt, 1, 1)

  return s_pos[1] - 1, s_pos[2], e_pos[1] - 1, e_pos[2] + d
end

---Returns backward/forward part of current line around the cursor.
---@param half? -1|0|1 -1: backward part; 0: both parts; 1: forward part.
---@return { b:string, f:string } result *b*: Half line before the cursor; *f*: Half line after the cursor.
function M.get_half_line(half)
  half = half or 0

  local col = vim.api.nvim_win_get_cursor(0)[2]
  local line = vim.api.nvim_get_current_line()
  local res = { b = "", f = "" }

  if half <= 0 then
    res.b = line:sub(1, col)
  end

  if half >= 0 then
    res.f = line:sub(col + 1, #line)
  end

  return res
end

---Returns the current mode.
---@return nviq.util.lib.Mode
function M.get_mode()
  local mode = vim.api.nvim_get_mode().mode
  return _mode_map[mode]
end

---Returns the word and its position under the cursor.
---@return string word Word under the cursor.
---@return integer start_column Start index of the line (0-based, inclusive).
---@return integer end_column End index of the line (0-based, exclusive).
function M.get_word()
  local context = M.get_half_line()
  local b = context.b
  local f = context.f
  local s_a, _ = vim.regex(_p_word_first_half):match_str(b)
  local _, e_b = vim.regex(_p_word_last_half):match_str(f)
  local p_a = ""
  local p_b = ""
  if e_b then
    p_a = s_a and b:sub(s_a + 1) or ""
    p_b = f:sub(1, e_b)
  end
  local word = p_a .. p_b
  if word == "" then
    word = sutil.sub(f, 1, 1)
    p_b = word
  end
  return word, #b - #p_a, #b + #p_b
end

---Returns URL or path under the cursor.
---@return string?
function M.get_url_or_path()
  local url = M.url_match(vim.fn.expand("<cWORD>"))
  if url then
    return url
  end

  local path = vim.fn.expand("<cfile>")
  if futil.is_relative(path) then
    path = vim.fs.joinpath(M.buf_dir(), path)
    path = vim.fs.normalize(path)
  end

  if futil.exist(path) then
    return path
  end
end

---Checks whether `exe` exists in path.
---@param exe string Name of the executable.
---@param to_warn? boolean If true, warn when executable not found.
---@return boolean result True if `exe` is a valid executable.
function M.has_exe(exe, to_warn)
  if vim.fn.executable(exe) == 1 then
    return true
  end

  if to_warn then
    M.warn("Executable " .. exe .. " was not found.")
  end

  return false
end

---Checks if `filetype` has `target` filetype.
---@param target string Destination file type.
---@param filetype? string File type to be checked, default *filetype* of current buffer.
---@return boolean result True if `filetype` has `target` filetype.
function M.has_filetype(target, filetype)
  filetype = filetype or vim.bo.filetype
  if not filetype then return false end
  return vim.list_contains(vim.split(filetype, "%."), target)
end

---Checks whether the OS is Windows.
---@return boolean
function M.has_win()
  return putil.os_type() == putil.OS.Windows
end

---Decodes a json file.
---@param path string Path of file to decode.
---@param loosely? boolean If true, tries to ignore comment lines and trailing commas (not recommended).
---@return 0|1|2 code 0: ok, 1: json is invalid, 2: file does not exist.
---@return table? result Decode result.
function M.json_decode(path, loosely)
  local content = futil.read_all_text(path)
  if not content then
    return 2, nil
  end

  ---@type (fun(chunk: string):string)[]
  local filters = {
    ---Remove comment lines.
    ---@param chunk string
    ---@return string
    function(chunk)
      local lines = vim.split(chunk, "[\n\r]", {
        plain = false,
        trimempty = true,
      })
      return table.concat(vim.tbl_filter(function(v)
        if vim.startswith(vim.trim(v), "//") then
          return false
        end
        return true
      end, lines))
    end,
    ---Remove trailing commas.
    ---@param chunk string
    ---@return string
    ---@return integer
    function(chunk)
      local s = chunk:gsub(",%s*([%]%}])", "%1")
      return s
    end,
  }

  local ok, result;
  local i = 0;
  local n = #filters

  while true do
    ok, result = pcall(vim.json.decode, content)
    if ok then
      return 0, result
    elseif not loosely or i == n then
      break
    end
    i = i + 1
    content = filters[i](content)
  end

  return 1, nil
end

---The same as `vim.ui.open`, but uses `start` on Windows by default.
---@param path string Path or URL to open.
---@param opt? { cmd: string[] } Options.
---@return vim.SystemObj? object Command object, or nil if not found.
---@return string? error Error message on failure, or nil on success.
function M.open(path, opt)
  if M.has_win() and not opt then
    local option = {
      args = { "/c", "start", "", path },
      hide = false, -- Why is this hardcoded to true in vim.system?
    }
    local proc, pid
    proc, pid = vim.uv.spawn("cmd", option, vim.schedule_wrap(function()
      if proc then
        proc:close()
      end
    end))
    return { cmd = "cmd", pid = pid }, nil
  end
  return vim.ui.open(path, opt)
end

---Locates surrounding pair in direction `dir`. Returns -1 when not found.
---CAVEATS: This function won't check the syntax, so imbalanced pairs in a string
---won't be handled correctly.
---@param left string Left part of the pair.
---@param right string Right part of the pair.
---@return integer l_lin Line number of the left pair pos (0-based).
---@return integer l_col Column number of the left pair pos (0-based).
---@return integer r_lin Line number of the right pair pos (0-based).
---@return integer r_col Column number of the right pair pos (0-based).
function M.search_pair_pos(left, right)
  if left == right then
    local pat = "\\v" .. M.vim_pesc(left)
    local l_lin, l_col = unpack(vim.fn.searchpos(pat, "nbW"))
    local r_lin, r_col = unpack(vim.fn.searchpos(pat, "ncW"))
    return l_lin - 1, l_col - 1, r_lin - 1, r_col - 1
  else
    local l_pat = "\\v" .. M.vim_pesc(left)
    local r_pat = "\\v" .. M.vim_pesc(right)
    local l_lin, l_col = unpack(vim.fn.searchpairpos(l_pat, "", r_pat, "nbW"))
    local r_lin, r_col = unpack(vim.fn.searchpairpos(l_pat, "", r_pat, "ncW"))
    return l_lin - 1, l_col - 1, r_lin - 1, r_col - 1
  end
end

---Sets background theme.
---@param theme "dark"|"light"
function M.set_theme(theme)
  if vim.o.background ~= theme then
    vim.o.background = theme
  end
end

---Try-Catch-Finally.
---@param try_block function
---@return { catch: fun(catch_block: fun(ex: string)):{ finally: fun(finally_block: function) }, finally: fun(finally_block: function) }
function M.try(try_block)
  local status, err = true, nil

  if type(try_block) == "function" then
    status, err = xpcall(try_block, debug.traceback)
  end

  ---Finally.
  ---@param finally_block function
  ---@param catch_block_declared boolean
  local finally = function(finally_block, catch_block_declared)
    if type(finally_block) == "function" then
      finally_block()
    end

    if not catch_block_declared and not status then
      error(err)
    end
  end

  ---Catch.
  ---@param catch_block fun(ex: string)
  ---@return { finally: fun(finally_block: function) }
  local catch = function(catch_block)
    local catch_block_declared = type(catch_block) == "function"

    if not status and catch_block_declared then
      local ex = err or "Unknown error"
      catch_block(ex)
    end

    return {
      finally = function(finally_block)
        finally(finally_block, catch_block_declared)
      end
    }
  end

  return {
    catch = catch,
    finally = function(finally_block)
      finally(finally_block, false)
    end
  }
end

---Matches URL within a string.
---@param str string The string.
---@return string? url The matched URL.
function M.url_match(str)
  local url_pat = "((%f[%w]%a+://)(%w[-.%w]*)(:?)(%d*)(/?)([%w_.~!*:@&+$/?%%#=-]*))"
  local protocols = {
    [""] = 0,
    ["http://"] = 0,
    ["https://"] = 0,
    ["ftp://"] = 0
  }

  local url, prot, dom, colon, port, slash, path = str:match(url_pat)

  if (url and
        not (dom .. "."):find("%W%W") and
        protocols[prot:lower()] == (1 - #slash) * #path and
        (colon == "" or port ~= "" and port + 0 < 65536)) then
    return url
  end
end

---Sources a vim file in config directory.
---@param file string Vim script path relative to the config directory.
function M.vim_source(file)
  local file_path = vim.fs.joinpath(vim.fn.stdpath("config"), file .. ".vim")
  if futil.is_file(file_path) then
    vim.cmd.source(file_path)
  else
    vim.notify("" .. file .. ".vim was not found.", vim.log.levels.WARN)
  end
end

---Escapes vim regex (\\v) special characters in a string.
---@param str string The string.
---@return string result Escaped string.
function M.vim_pesc(str)
  return vim.fn.escape(str, " ()[]{}<>.+!@#$%^&*=\\|?~")
end

---Notifies a warning message.
---@param msg string The message.
function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN, nil)
end

return M
