local path = require("project_nvim.utils.path")
local uv = vim.loop
local M = {}

---@type string[]
M.recent_projects = nil -- projects from previous neovim sessions
M.session_projects = {} -- projects from current neovim session
M.has_watch_setup = false

---@param mode string
---@param callback? function
local function open_history(mode, callback)
  if callback ~= nil then
    path.create_scaffolding(function(_, _) uv.fs_open(path.historyfile, mode, 438, callback) end)
  else
    path.create_scaffolding()
    return uv.fs_open(path.historyfile, mode, 438)
  end
end

---@param project string
function M.delete_project(project)
  for k, v in ipairs(M.recent_projects) do
    if v == project then M.recent_projects[k] = nil end
  end
end

local function toset()
  local already_seen = {} ---@type table<string, boolean>
  return function(paths, _path)
    if not already_seen[_path] then
      already_seen[_path] = true
      paths[#paths + 1] = _path
    end
    return paths
  end
end

---@param history_data string|nil
local function deserialize_history(history_data)
  if not history_data then return end

  ---@type string[]
  local projects = vim
    .iter(vim.gsplit(history_data, "[\r\n]+", { trimempty = true }))
    :filter(function(_path) return not path.is_excluded(_path) and path.dir_exists(_path) end)
    :map(path.normalize)
    :fold({}, toset())

  M.recent_projects = projects
end

local function setup_watch()
  if M.has_watch_setup then return end

  M.has_watch_setup = true
  local event = uv.new_fs_event()
  if not event then return end
  event:start(path.projectpath, {}, function(err, _, events)
    if err ~= nil then return end
    if events["change"] then
      M.recent_projects = nil
      M.read_projects_from_history()
    end
  end)
end

function M.read_projects_from_history()
  open_history("r", function(_, fd)
    setup_watch()
    if not fd then return end
    uv.fs_fstat(fd, function(_, stat)
      if not stat then return end
      uv.fs_read(fd, stat.size, -1, function(_, data)
        uv.fs_close(fd, function(_, _) end)
        deserialize_history(data)
      end)
    end)
  end)
end

---@return string[]
local function sanitize_projects()
  local projects = M.session_projects
  if M.recent_projects then vim.list_extend(projects, M.recent_projects) end

  return vim.iter(projects):filter(function(dir) return path.dir_exists(dir) end):fold({}, toset())
end

function M.get_recent_projects() return sanitize_projects() end

function M.write_projects_to_history()
  -- Unlike read projects, write projects is synchronous
  -- because it runs when vim ends
  local mode = "w"
  if M.recent_projects == nil then mode = "a" end
  local file = open_history(mode)

  if file ~= nil then
    local output = sanitize_projects()

    -- Trim table to last 100 entries
    local len_res = #output
    ---@type string[]
    local tbl_out
    if #output > 100 then
      tbl_out = vim.list_slice(output, len_res - 100, len_res)
    else
      tbl_out = output
    end

    -- Transform table to string
    local out = ""
    for _, v in ipairs(tbl_out) do
      out = out .. v .. "\n"
    end

    -- Write string out to file and close
    uv.fs_write(file, out, -1)
    uv.fs_close(file)
  end
end

return M
