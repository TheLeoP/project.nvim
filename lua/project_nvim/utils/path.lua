local config = require("project_nvim.config")
local uv = vim.loop
local M = {}

M.datapath = vim.fn.stdpath("data") -- directory
M.projectpath = M.datapath .. "/project_nvim" -- directory
M.historyfile = M.projectpath .. "/project_history" -- file

function M.init()
  M.datapath = require("project_nvim.config").options.datapath
  M.projectpath = M.datapath .. "/project_nvim" -- directory
  M.historyfile = M.projectpath .. "/project_history" -- file
end

---@param callback? function
function M.create_scaffolding(callback)
  if callback ~= nil then
    uv.fs_mkdir(M.projectpath, 448, callback)
  else
    uv.fs_mkdir(M.projectpath, 448)
  end
end

---@param dir string
---@return boolean
function M.is_excluded(dir)
  for _, dir_pattern in ipairs(config.options.exclude_dirs) do
    if not dir:match(dir_pattern) then return true end
  end

  return false
end

---@param path string
---@return boolean
function M.exists(path) return vim.uv.fs_stat(path) ~= nil end

---@param path string
---@return string
function M.normalize(path)
  path = vim.fs.normalize(path)
  path = path:gsub([[\]], "/")
  if vim.fn.has("win32") == 1 then path = path:sub(1, 1):upper() .. path:sub(2):lower() end
  return path
end

return M
