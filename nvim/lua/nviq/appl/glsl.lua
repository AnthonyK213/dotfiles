local lib = require("nviq.util.lib")
local autil = require("nviq.util.a")

local _comp_list = {
  "void", "bool", "int", "float", "vec2", "vec3", "vec4", "bvec2", "bvec3",
  "bvec4", "ivec2", "ivec3", "ivec4", "mat2", "mat2x2", "mat3", "mat3x3",
  "mat4x4", "mat2x3", "mat2x4", "mat3x2", "mat3x4", "mat4x2", "mat4x3",
  "sampler1D", "sampler2D", "sampler3D", "samplerCube", "sampler1DShadow",
  "sampler2DShadow", "struct",
  "gl_Color", "gl_SecondaryColor", "gl_Normal", "gl_Vertex", "gl_MultiTexCoordn",
  "gl_FogCoord", "gl_Position", "gl_ClipVertex", "gl_PointSize", "gl_FrontColor",
  "gl_BackColor", "gl_FrontSecondaryColor", "gl_BackSecondaryColor", "gl_TexCoord",
  "gl_FogFragCoord", "gl_FragCoord", "gl_FrontFacing", "gl_PointCoord",
  "gl_FragData", "gl_FragColor", "gl_FragDepth",
  "const", "attribute", "uniform", "varying", "centroid varying", "invariant",
  "in", "out", "inout",
  "radians", "degrees", "sin", "cos", "tan", "asin", "atan",
  "pow", "exp", "log", "exp2", "log2", "sqrt", "inversesqrt", "step", "smoothstep",
  "abs", "sign", "floor", "ceil", "fract", "mod", "min", "max", "clamp", "mix",
  "length", "distance", "dot", "cross", "normalize", "faceforward", "reflect", "refract",
  "matrixCompMult", "lessThan", "lessThanEqual", "greaterThan", "greaterThanEqual",
  "equal", "notEqual", "any", "all", "not",
  "texture2D", "texture2DProj", "texture2DLod", "texture2DProjLod",
  "textureCube", "textureCubeLod",
}

local M = {}

---@class nviq.appl.glsl.Session
---@field process nviq.util.a.Process
---@field stdout_tail string

---@private
---@type table<integer, nviq.appl.glsl.Session>
M.tbl = {}

---@param session nviq.appl.glsl.Session
---@param data string
---@return string[] lines
local function read_lines(session, data)
  data = session.stdout_tail .. data
  local lines = {}
  local start = 1

  while true do
    local first, last = data:find("[\r\n]+", start)
    if not first then
      break
    end
    table.insert(lines, data:sub(start, first - 1))
    start = last + 1
  end

  session.stdout_tail = data:sub(start)
  return lines
end

---@param bufnr integer
---@param session nviq.appl.glsl.Session
---@param lines string[]
local function notify_output(bufnr, session, lines)
  local output = table.concat(lines, "\n")
  vim.schedule(function()
    if M.tbl[bufnr] == session then
      vim.notify(output)
    end
  end)
end

---@private
---@param bufnr integer
---@return boolean
function M.is_alive(bufnr)
  local session = M.tbl[bufnr]
  return session ~= nil and not session.process:is_closing()
end

---Start glslViewer.
---@param bufnr? integer
---@param fargs? string[]
function M.start(bufnr, fargs)
  bufnr = lib.bufnr(bufnr)
  fargs = fargs or {}

  if M.is_alive(bufnr) then
    vim.notify("glslViewer is already running")
    return
  end

  if not lib.has_exe("glslViewer", true) then
    return
  end

  table.insert(fargs, "--noncurses")
  local session = {
    stdout_tail = "",
  }

  local cmd = vim.list_extend({ "glslViewer" }, fargs)
  session.process = autil.process.start(cmd, {
    cwd = lib.buf_dir(bufnr),
    stdin = true,
    text = true,
    stdout = function(err, data)
      if err then
        vim.schedule(function()
          if M.tbl[bufnr] == session then
            lib.warn("glslViewer: " .. err)
          end
        end)
      elseif data then
        notify_output(bufnr, session, read_lines(session, data))
      end
    end,
  }, function(_, result)
    if session.stdout_tail ~= "" then
      if session.stdout_tail and M.tbl[bufnr] == session then
        vim.notify(session.stdout_tail)
      end
      session.stdout_tail = ""
    end
    if M.tbl[bufnr] == session then
      M.tbl[bufnr] = nil
      if result.code == 0 then
        vim.notify("glslViewer: Exited")
      else
        lib.warn("glslViewer: Exited with code " .. result.code)
      end
    end
  end)

  M.tbl[bufnr] = session
  vim.api.nvim_buf_attach(bufnr, false, {
    on_detach = function(_, h) M.stop(h) end
  })
  vim.notify("glslViewer: Started")
end

---Stop glslViewer attached to the buffer.
---@param bufnr? integer
function M.stop(bufnr)
  bufnr = lib.bufnr(bufnr)
  local session = M.tbl[bufnr]
  if session then
    M.tbl[bufnr] = nil
    session.process:close()
  end
end

---@param bufnr? integer
function M.toggle(bufnr)
  bufnr = lib.bufnr(bufnr)
  if M.is_alive(bufnr) then
    M.stop(bufnr)
  else
    M.start(bufnr, { vim.api.nvim_buf_get_name(bufnr) })
  end
end

---@param bufnr? integer
function M.input(bufnr)
  bufnr = lib.bufnr(bufnr)
  if not M.is_alive(bufnr) then
    lib.warn("glslViewer is not running!")
    return
  end

  autil.task.start("glsl.input", function()
    local session = M.tbl[bufnr]
    local data = autil.ui.input { prompt = "glslViewer > " }
    if not data or #data == 0 then return end
    if M.tbl[bufnr] ~= session or not M.is_alive(bufnr) then
      lib.warn("glslViewer is no longer running!")
      return
    end
    vim.notify("// > " .. data)
    session.process:write(data .. "\n")
  end)
end

---GLSL omnifunc.
---@param findstart integer
---@param base string
---@return integer|string[]
function M.omnifunc(findstart, base)
  if findstart == 1 then
    local start = vim.api.nvim_win_get_cursor(0)[2]
    if start == 0 then return -2 end
    local back = lib.get_half_line(-1).b
    local match = back:match("[%a_]+$")
    if not match then return -2 end
    return start - match:len()
  else
    local base_ = base:lower()
    return vim.tbl_filter(function(item)
      return vim.startswith(item:lower(), base_)
    end, _comp_list)
  end
end

return M
