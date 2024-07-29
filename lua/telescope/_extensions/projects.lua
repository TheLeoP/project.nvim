-- Inspiration from:
-- https://github.com/nvim-telescope/telescope-project.nvim
local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then return end

local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local telescope_config = require("telescope.config").values
local actions = require("telescope.actions")
local state = require("telescope.actions.state")
local builtin = require("telescope.builtin")
local entry_display = require("telescope.pickers.entry_display")

local history = require("project_nvim.utils.history")
local project = require("project_nvim.project")
local config = require("project_nvim.config")

----------
-- Actions
----------

local function create_finder()
  local projects = history.get_recent_projects()
  projects = vim.iter(projects):rev():totable()

  local displayer = entry_display.create({
    separator = " ",
    items = {
      {
        width = 30,
      },
      {
        remaining = true,
      },
    },
  })

  local function make_display(entry) return displayer({ entry.name, { entry.value, "Comment" } }) end

  return finders.new_table({
    results = projects,
    ---@param entry string
    entry_maker = function(entry)
      local name = vim.fn.fnamemodify(entry, ":t")
      return {
        display = make_display,
        name = name,
        value = entry,
        ordinal = name .. " " .. entry,
      }
    end,
  })
end

local function change_working_directory(prompt_bufnr)
  local selected_entry = state.get_selected_entry() --[[@as {value: string}]]
  if selected_entry == nil then
    actions.close(prompt_bufnr)
    return
  end
  local project_path = selected_entry.value
  actions.close(prompt_bufnr)
  local cd_successful = project.set_cwd(project_path, "telescope")
  return project_path, cd_successful
end

local function find_project_files(prompt_bufnr)
  local project_path, cd_successful = change_working_directory(prompt_bufnr)
  local opt = {
    cwd = project_path,
    hidden = config.options.show_hidden,
    mode = "insert",
  }
  if cd_successful then builtin.find_files(opt) end
end

local function browse_project_files(prompt_bufnr)
  local project_path, cd_successful = change_working_directory(prompt_bufnr)
  local opt = {
    cwd = project_path,
    hidden = config.options.show_hidden,
  }
  if cd_successful then require("telescope").extensions.file_browser.file_browser(opt) end
end

local function search_in_project_files(prompt_bufnr)
  local project_path, cd_successful = change_working_directory(prompt_bufnr)
  local opt = {
    cwd = project_path,
    hidden = config.options.show_hidden,
    mode = "insert",
  }
  if cd_successful then builtin.live_grep(opt) end
end

local function recent_project_files(prompt_bufnr)
  local _, cd_successful = change_working_directory(prompt_bufnr)
  local opt = {
    cwd_only = true,
    hidden = config.options.show_hidden,
  }
  if cd_successful then builtin.oldfiles(opt) end
end

---@param prompt_bufnr integer
local function delete_project(prompt_bufnr)
  local selectedEntry = state.get_selected_entry() --[[@as {value: string}]]
  if selectedEntry == nil then
    actions.close(prompt_bufnr)
    return
  end
  local choice = vim.fn.confirm(("Delete '%s' from project list?"):format(selectedEntry.value), "&Yes\n&No", 2)

  if choice == 1 then
    history.delete_project(selectedEntry.value)

    local finder = create_finder()
    state.get_current_picker(prompt_bufnr):refresh(finder, {
      reset_prompt = true,
    })
  end
end

local on_project_selected = function(prompt_bufnr)
  local open_find_files = false

  if vim.is_callable(config.options.find_files) then
    open_find_files = config.options.find_files(prompt_bufnr)
  else
    open_find_files = config.options.find_files --[[@as boolean]]
  end

  if open_find_files then
    find_project_files(prompt_bufnr)
  else
    actions.close(prompt_bufnr)
  end
end

---Main entrypoint for Telescope.
---@param opts table
local function projects(opts)
  opts = opts or {}

  pickers
    .new(opts, {
      prompt_title = "Recent Projects",
      finder = create_finder(),
      previewer = false,
      sorter = telescope_config.generic_sorter(opts),
      attach_mappings = function(_, map)
        map("n", "f", find_project_files)
        map("n", "b", browse_project_files)
        map("n", "d", delete_project)
        map("n", "s", search_in_project_files)
        map("n", "r", recent_project_files)
        map("n", "w", change_working_directory)

        map("i", "<c-f>", find_project_files)
        map("i", "<c-b>", browse_project_files)
        map("i", "<c-d>", delete_project)
        map("i", "<c-s>", search_in_project_files)
        map("i", "<c-r>", recent_project_files)
        map("i", "<c-w>", change_working_directory)

        actions.select_default:replace(on_project_selected)
        return true
      end,
    })
    :find()
end

return telescope.register_extension({
  exports = {
    projects = projects,
  },
})
