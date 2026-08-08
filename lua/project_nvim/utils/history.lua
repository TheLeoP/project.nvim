local path = require("project_nvim.utils.path")
local uv = vim.uv
local async = require("async")

local M = {}

local project_path = vim.fn.stdpath("data") .. "/project_nvim"
local history_file = project_path .. "/project_history"

---@type string[]
local recent_projects = {}
local history_semaphore = async.semaphore(1)

---@param project string
function M.delete(project)
  local task = async.run(function()
    history_semaphore:with(function()
      for i, v in ipairs(recent_projects) do
        if v == project then
          table.remove(recent_projects, i)
          break
        end
      end
    end)
    async.await(M.write())
  end)
  task:raise_on_error()
  return task
end

---@param project string
function M.add(project)
  local task = async.run(function()
    if vim.list_contains(recent_projects, project) then async.await(M.delete(project)) end
    history_semaphore:with(function()
      if path.exists(project) and not path.is_excluded(project) then table.insert(recent_projects, 1, project) end
    end)
    async.await(M.write())
  end)
  task:raise_on_error()
end

---@type fun(path: string): err: string|nil, stat: uv.fs_stat.result|nil
local a_fs_stat = async.wrap(2, uv.fs_stat)
---@type fun(path: string, mode: integer): err: string|nil, success: boolean|nil
local a_fs_mkdir = async.wrap(3, uv.fs_mkdir)
---@type fun(path: string, flags: string|integer, mode: integer): err: string|nil, fd: integer|nil
local a_fs_open = async.wrap(4, uv.fs_open)
---@type fun(fd: integer): err: string|nil, stat: uv.fs_stat.result|nil
local a_fs_fstat = async.wrap(2, uv.fs_fstat)
---@type fun(fd: integer, size: integer, offset?: integer): err: string|nil, data: string|nil
local a_fs_read = async.wrap(4, uv.fs_read)
---@type fun(fd: integer): err: string|nil, success: boolean|nil
local a_fs_close = async.wrap(2, uv.fs_close)
---@type fun(fd: integer, data: string|string[], offset?: integer): err: string|nil, bytes: integer|nil
local a_fs_write = async.wrap(4, uv.fs_write)

function M.read_history()
  local task = async.run(function()
    history_semaphore:with(function()
      local err = a_fs_stat(project_path)
      if err and not err:match("^ENOENT:") then return vim.notify(err, vim.log.levels.ERROR) end
      if err and err:match("^ENOENT:") then
        local err2 = a_fs_mkdir(project_path, tonumber("700", 8))
        if err2 then return vim.notify(err2, vim.log.levels.ERROR) end
      end

      local err3, fd = a_fs_open(history_file, "r", tonumber("666", 8))
      if err3 then return vim.notify(err3, vim.log.levels.ERROR) end
      ---@cast fd -nil

      local err4, fd_stat = a_fs_fstat(fd)
      if err4 then return vim.notify(err4, vim.log.levels.ERROR) end
      ---@cast fd_stat -nil

      local err5, data = a_fs_read(fd, fd_stat.size, 0)
      if err5 then return vim.notify(err5, vim.log.levels.ERROR) end
      ---@cast data -nil

      local err6 = a_fs_close(fd)
      if err6 then return vim.notify(err6, vim.log.levels.ERROR) end

      recent_projects = vim
        .iter(vim.gsplit(data, "[\r\n]+", { trimempty = true }))
        :filter(function(p) return not path.is_excluded(p) and path.dir_exists(p) end)
        :map(path.normalize)
        :unique()
        :totable()
    end)
  end)
  task:raise_on_error()
end

function M.get_recent()
  return async.run(function()
    return history_semaphore:with(function() return recent_projects end)
  end)
end

function M.write()
  local task = async.run(function()
    history_semaphore:with(function()
      local err = a_fs_stat(project_path)
      if err and not err:match("^ENOENT:") then return vim.notify(err, vim.log.levels.ERROR) end
      if err and err:match("^ENOENT:") then
        local err2 = a_fs_mkdir(project_path, tonumber("700", 8))
        if err2 then return vim.notify(err2, vim.log.levels.ERROR) end
      end

      if vim.tbl_isempty(recent_projects) then return end

      local out = table.concat(recent_projects, "\n")

      local err5, file = a_fs_open(history_file, "w", tonumber("666", 8)) ---@type string|nil, integer|nil
      if err5 then return vim.notify(err5, vim.log.levels.ERROR) end
      ---@cast file -nil
      local err3 = a_fs_write(file, out, -1) ---@type string|nil
      if err3 then return vim.notify(err3, vim.log.levels.ERROR) end
      local err4 = a_fs_close(file) ---@type string|nil
      if err4 then return vim.notify(err4, vim.log.levels.ERROR) end
    end)
  end)
  task:raise_on_error()
  return task
end

function M.start_history_watcher()
  local watcher = uv.new_fs_event()
  if not watcher then return end
  watcher:start(project_path, {}, function(err, file, events)
    if err then return vim.notify(err, vim.log.levels.ERROR) end
    if not events.change or file ~= "project_history" then return end

    M.read_history()
  end)
end

return M
