local lib = require("nviq.util.lib")

local M = {}

local ns_git_signs = vim.api.nvim_create_namespace("nviq.appl.diff.signs")

---
---@param bufnr integer
---@param diff_output string
local function render_git_signs(bufnr, diff_output)
  vim.api.nvim_buf_clear_namespace(bufnr, ns_git_signs, 0, -1)

  local hunks = {}
  local line_count = vim.api.nvim_buf_line_count(bufnr)

  for line in diff_output:gmatch("[^\r\n]+") do
    local old_c, new_s, new_c = line:match("^@@ %-%d+,?(%d*) %+(%d+),?(%d*) @@")
    if new_s then
      local old_count = tonumber(old_c) or 1
      local new_start = tonumber(new_s)
      local new_count = tonumber(new_c) or 1

      local target_line = lib.clamp(new_start, 1, line_count)
      table.insert(hunks, target_line)

      if old_count == 0 and new_count > 0 then
        for i = 0, new_count - 1 do
          local row = new_start + i - 1
          if row >= 0 and row < line_count then
            vim.api.nvim_buf_set_extmark(bufnr, ns_git_signs, row, 0, {
              sign_text = "│",
              sign_hl_group = "Added",
            })
          end
        end
      elseif old_count > 0 and new_count == 0 then
        vim.api.nvim_buf_set_extmark(bufnr, ns_git_signs, target_line - 1, 0, {
          sign_text = "_",
          sign_hl_group = "Removed",
        })
      else
        for i = 0, new_count - 1 do
          local row = new_start + i - 1
          if row >= 0 and row < line_count then
            vim.api.nvim_buf_set_extmark(bufnr, ns_git_signs, row, 0, {
              sign_text = "│",
              sign_hl_group = "Changed",
            })
          end
        end
      end
    end
  end

  vim.b[bufnr].nviq_git_hunks = hunks
end

---
---@param bufnr integer
local function update_git_signs(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local file = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(bufnr))
  if file == "" or vim.bo[bufnr].buftype ~= "" then
    return
  end

  local req_id = (vim.b[bufnr].nviq_git_diff_req_id or 0) + 1
  vim.b[bufnr].nviq_git_diff_req_id = req_id

  local dir = vim.uv.fs_realpath(lib.buf_dir(bufnr))
  vim.system(
    { "git", "--no-optional-locks", "diff", "-U0", "--", file },
    { cwd = dir, text = true },
    vim.schedule_wrap(function(result)
      if not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      if vim.b[bufnr].nviq_git_diff_req_id ~= req_id then
        return
      end

      if result.code == 0 then
        render_git_signs(bufnr, result.stdout)
      else
        render_git_signs(bufnr, "")
      end
    end))
end

function M.setup()
  local group = vim.api.nvim_create_augroup("nviq.appl.diff", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "FocusGained" }, {
    group = group,
    callback = function(args)
      update_git_signs(args.buf)
    end
  })
end

function M.jump(direction)
  if vim.wo.diff then
    vim.cmd("normal! " .. (direction > 0 and "]c" or "[c"))
    return
  end

  local hunks = vim.b.nviq_git_hunks
  if not hunks or #hunks == 0 then
    lib.warn("No hunks")
    return
  end

  local cur_line = vim.api.nvim_win_get_cursor(0)[1]
  if direction > 0 then
    for _, line in ipairs(hunks) do
      if line > cur_line then
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        return
      end
    end
    vim.api.nvim_win_set_cursor(0, { hunks[1], 0 })
  elseif direction < 0 then
    for i = #hunks, 1, -1 do
      if hunks[i] < cur_line then
        vim.api.nvim_win_set_cursor(0, { hunks[i], 0 })
        return
      end
    end
    vim.api.nvim_win_set_cursor(0, { hunks[#hunks], 0 })
  else
    return
  end
end

return M
