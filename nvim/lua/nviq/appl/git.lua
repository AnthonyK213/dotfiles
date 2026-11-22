local lib = require("nviq.util.lib")
local autil = require("nviq.util.a")

local M = {}

---Returns the root directory of this repository.
---@return string?
function M.get_root()
  local buf_path = vim.api.nvim_buf_get_name(0)
  local start_path = buf_path ~= "" and buf_path or vim.uv.cwd()
  if start_path then
    return vim.fs.root(start_path, ".git")
  end
end

---Returns the current branch name.
---@param git_root string The root directory of the repository.
---@return string? result The current branch name.
function M.get_branch(git_root)
  local head_file = vim.fs.joinpath(git_root, "/.git/HEAD")

  local file = io.open(head_file)
  if file then
    local gitdir_line = file:read("*l")
    file:close()
    if gitdir_line then
      local branch = gitdir_line:match("^ref:%s.+/([^%s]-)$")
      if branch and #branch > 0 then
        return branch
      end
    end
  end
end

---@type vim.lpeg.Pattern?
local blame_info_pattern = nil

---
---@param info string
---@return table<string, string>?
local function parse_blame_info(info)
  if not blame_info_pattern then
    blame_info_pattern = vim.re.compile([[
      blame <- {| head (%nl field)* (%nl) code |}
      head <- {:hash: [0-9a-f]^40 :} %s {:lnum_origin: %d+ :} %s {:lnum_final: %d+ :} %s {:lcnt: %d+ :}
      field <- {| {[%a-]+} (" ")? {[^%nl]*} |}
      code <- %t {:code: ([^%nl]*) :}
    ]], { t = "\t" })
  end

  local captures = vim.re.match(info, blame_info_pattern)
  if not captures then
    return
  end

  for _, v in ipairs(captures --[[@as table]]) do
    captures[v[1]] = v[2]
  end

  return captures --[[@as table<string, string>]]
end

---To blame someone :)
function M.blame_line()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local file = vim.api.nvim_buf_get_name(0)
  local cwd = lib.buf_dir(0)
  local range = string.format("%d,%d", lnum, lnum)
  autil.task.start("git.blame_line", function()
    local result = autil.process.run({
      "git", "blame", "--line-porcelain", "-L", range, file,
    }, {
      cwd = cwd,
      text = true,
    })
    if result.code ~= 0 or not result.stdout or result.stdout:len() == 0 then
      vim.notify("No one to blame...")
      return
    end
    local blame_info = parse_blame_info(result.stdout)
    if blame_info then
      local hash = blame_info["hash"]
      if hash:match("^0+$") then
        vim.notify("Not Committed Yet")
        return
      end
      vim.notify(string.format("%s %s (%s): %s",
        hash:sub(1, 8),
        blame_info["author"],
        os.date("%Y-%m-%d %H:%M", tonumber(blame_info["author-time"])),
        blame_info["summary"]
      ))
    end
  end)
end

---
---@param result vim.SystemCompleted
---@param fallback_msg string
---@return integer
local function handle_system_result(result, fallback_msg)
  if result.code == 0 then
    vim.notify(result.stdout or "")
  elseif result.stderr ~= "" then
    lib.warn(result.stderr)
  elseif result.stdout ~= "" then
    lib.warn(result.stdout)
  else
    lib.warn(fallback_msg)
  end
  return result.code
end

---
---@return vim.async.Task?
function M.add()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return nil
  end

  return autil.task.start("git.add", function()
    local result = autil.process.run({ "git", "add", "-A" }, { cwd = root, text = true })
    return handle_system_result(result, "Git stage failed")
  end)
end

---
---@return vim.async.Task?
function M.reset()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return nil
  end

  return autil.task.start("git.add", function()
    local result = autil.process.run({ "git", "reset" }, { cwd = root, text = true })
    return handle_system_result(result, "Git reset failed")
  end)
end

---
---@return vim.async.Task?
function M.commit()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return nil
  end

  return autil.task.start("git.commit", function()
    local message = autil.ui.input { prompt = "Commit message: " }
    if not message then
      lib.warn("Canceled")
      return 1
    end

    local result = autil.process.run({ "git", "commit", "-m", message }, {
      cwd = root,
      text = true,
    })

    return handle_system_result(result, "Git commit failed")
  end)
end

---@param job_id integer
---@param data string
local function prompt_default(job_id, data)
  local prompt = data:gsub("[\r\n]", "")
  local user_input = vim.fn.input { prompt = prompt }
  pcall(vim.fn.chansend, job_id, user_input .. "\n")
end

---@param job_id integer
---@param data string
local function prompt_secret(job_id, data)
  vim.fn.inputsave()
  local prompt = data:gsub("[\r\n]", "")
  local user_input = vim.fn.inputsecret(prompt)
  vim.fn.inputrestore()
  pcall(vim.fn.chansend, job_id, user_input .. "\n")
end

---@class nviq.appl.git.PtyState
---@field lines string[]
---@field tail string

---@param data string
---@return string
local function strip_pty_data(data)
  local stripped = data:gsub("\27%[[%d;?]*[FGHJKhlm]", "")
  return stripped
end

---@param job_id integer
---@param data string
---@return boolean prompted
local function handle_prompt(job_id, data)
  if data:match("^Username for .-:%s*$") then
    prompt_default(job_id, data)
  elseif data:match("^Enter passphrase.-:%s*$") or
      data:match("'s password:%s*$") or
      data:match("^Password for .-:%s*$") then
    prompt_secret(job_id, data)
  elseif data:match("^Are you sure you want to continue connecting .-%?%s*$") or
      data:match("Please type .+:%s*$") then
    prompt_default(job_id, data)
  else
    return false
  end
  return true
end

---@param job_id integer
---@param state nviq.appl.git.PtyState
---@param data string
local function consume_pty_data(job_id, state, data)
  local raw_data = strip_pty_data(data)
  if raw_data == "" or raw_data:match("^\27]0;") then
    return
  end
  if not handle_prompt(job_id, raw_data) then
    table.insert(state.lines, raw_data)
  end
end

---@param job_id integer
---@param state nviq.appl.git.PtyState
---@param data string[]
local function on_pty_stdout(job_id, state, data)
  local eof = #data == 1 and data[1] == ""
  state.tail = state.tail .. (data[1] or "")

  for index = 2, #data do
    consume_pty_data(job_id, state, state.tail)
    state.tail = data[index]
  end

  if eof then
    consume_pty_data(job_id, state, state.tail)
    state.tail = ""
    return
  end

  local tail = strip_pty_data(state.tail)
  if handle_prompt(job_id, tail) then
    state.tail = ""
  end
end

---@param state nviq.appl.git.PtyState
---@param code integer
local function on_pty_exit(state, code)
  if state.tail ~= "" then
    local tail = strip_pty_data(state.tail)
    if tail ~= "" and not tail:match("^\27]0;") then
      table.insert(state.lines, tail)
    end
    state.tail = ""
  end

  local message = table.concat(state.lines, "\n")
  if code == 0 then
    vim.notify(message)
  else
    lib.warn(message)
  end
end

---@param operation "pull"|"push"
---@return nviq.util.a.Job?
local function start_remote(operation)
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return
  end

  if not lib.has_exe("git", true) then
    return
  end

  local state = {
    lines = {},
    tail = "",
  }
  return autil.job.start({ "git", operation }, {
    cwd = root,
    pty = true,
    on_stdout = function(job_id, data)
      on_pty_stdout(job_id, state, data)
    end,
    on_exit = function(_, code)
      on_pty_exit(state, code)
    end,
  })
end

---@return nviq.util.a.Job?
function M.pull()
  return start_remote("pull")
end

---@return nviq.util.a.Job?
function M.push()
  return start_remote("push")
end

local status_win = nil
local status_buf = nil

---
---@return vim.async.Task?
function M.status()
  local root = M.get_root()
  if not root then
    lib.warn("Not a git repository.")
    return nil
  end

  return autil.task.start("git.status", function()
    local result = autil.process.run({ "git", "status", "-sb" }, {
      cwd = root,
      text = true
    })

    local lines
    if result.code ~= 0 then
      lib.warn("Not a git repository.")
      return result.code
    else
      lines = vim.split(result.stdout or "", "\n", { trimempty = true })
    end

    if not status_win or not vim.api.nvim_win_is_valid(status_win) then
      vim.cmd("botright split")
      status_win = vim.api.nvim_get_current_win()
    end

    if not status_buf or not vim.api.nvim_buf_is_valid(status_buf) then
      status_buf = vim.api.nvim_create_buf(false, true);
      vim.bo[status_buf].buftype = "nofile"
      vim.bo[status_buf].bufhidden = "wipe"
      vim.bo[status_buf].swapfile = false
      vim.bo[status_buf].filetype = "nviq-git"
    end

    vim.api.nvim_win_set_buf(status_win, status_buf)

    vim.wo[status_win].number = false
    vim.wo[status_win].relativenumber = false
    vim.wo[status_win].signcolumn = "no"
    vim.wo[status_win].winfixheight = true

    vim.bo[status_buf].modifiable = true
    vim.api.nvim_buf_set_lines(status_buf, 0, -1, false, lines)
    vim.bo[status_buf].modifiable = false

    return result.code
  end)
end

return M
