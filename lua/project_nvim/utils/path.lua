local config = require("project_nvim.config")
local uv = vim.uv
local M = {}

M.projectpath = vim.fn.stdpath("data") .. "/project_nvim"
M.historyfile = M.projectpath .. "/project_history"

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

---@param dir string
---@return boolean
function M.dir_exists(dir)
  local stat = uv.fs_stat(dir)
  return stat ~= nil and stat.type == "directory"
end

---@param path string
---@return string
function M.normalize(path)
  path = vim.fs.normalize(path)
  path = path:gsub([[\]], "/")
  if vim.fn.has("win32") == 1 then path = path:sub(1, 1):upper() .. path:sub(2):lower() end
  return path
end

return M
