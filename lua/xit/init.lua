local ts_utils = require("nvim-treesitter.ts_utils")

local options = {
  in_development = false
}
local configured = false
local M = {}

local get_node_for_cursor = function(cursor)
  if cursor == nil then
    cursor = vim.api.nvim_win_get_cursor(0)
  end
  local root = ts_utils.get_root_for_position(unpack({ cursor[1] - 1, cursor[2] }))
  if not root then return end
  return root:named_descendant_for_range(cursor[1] - 1, cursor[2], cursor[1] - 1, cursor[2])
end

M.setup = function(opts)
  options = vim.tbl_deep_extend('force', options, opts)
  configured = true

  local parser_config = require "nvim-treesitter.parsers".get_parser_configs()
  parser_config.xit = {
    install_info = {
      url = "https://github.com/synaptiko/tree-sitter-xit",
      files = { "src/parser.c" },
      branch = "master",
      generate_requires_npm = false,
      requires_generate_from_grammar = false,
    },
    filetype = "xit",
  }

  if options.in_development then
    vim.cmd([[
      nnoremap <silent> <leader>x <cmd>lua package.loaded['xit'] = nil<CR><cmd>lua xit = require'xit'<CR>
    ]])
  end
end

local get_task_node = function(cursor)
  local node = get_node_for_cursor(cursor)

  if node == nil then
    return nil
  end

  local root = ts_utils.get_root_for_node(node)

  while (node ~= nil and node ~= root and node:type() ~= "task") do
    node = node:parent()
  end

  if node:type() == "task" then
    return node
  else
    return nil
  end
end

local get_checkbox = function(task_node)
  return task_node:child():child()
end

local get_next_checkbox_status_char = function(checkbox_node, toogle_back)
  if checkbox_node:type() == "open_checkbox" then
    return toogle_back and '~' or '@'
  elseif checkbox_node:type() == "ongoing_checkbox" then
    return toogle_back and ' ' or 'x'
  elseif checkbox_node:type() == "checked_checkbox" then
    return toogle_back and '@' or '~'
  else
    return toogle_back and 'x' or ' '
  end
end

M.toggle_checkbox = function(toggle_back)
  local task_node = get_task_node()

  if task_node == nil then
    return
  end

  local checkbox_node = get_checkbox(task_node)
  local next_status = get_next_checkbox_status_char(checkbox_node, toggle_back)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col = checkbox_node:range()

  vim.api.nvim_buf_set_text(bufnr, start_row, start_col + 1, end_row, end_col - 1, { next_status })
end

local find_next_task = function(current_task_node, start_line, end_line)
  for i = start_line, end_line do
    local next_task = get_task_node({ i, 0 })

    if next_task ~= nil and (current_task_node == nil or next_task ~= current_task_node) then
      local checkbox_row = get_checkbox(next_task):range()
      vim.api.nvim_win_set_cursor(0, { checkbox_row + 1, 4 })
      return true
    end
  end

  return false
end

M.jump_to_next_task = function(wrap)
  local current_task_node = get_task_node()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local max_line = vim.api.nvim_buf_line_count(0)
  local found = find_next_task(current_task_node, cursor[1], max_line)

  if wrap and not found then
    find_next_task(current_task_node, 0, cursor[1] - 1)
  end
end

local find_previous_task = function(current_task_node, start_line, end_line)
  for i = start_line, end_line, -1 do
    local previous_task = get_task_node({ i, 0 })

    if previous_task ~= nil and (current_task_node == nil or previous_task ~= current_task_node) then
      local checkbox_row = get_checkbox(previous_task):range()
      vim.api.nvim_win_set_cursor(0, { checkbox_row + 1, 4 })
      return true
    end
  end

  return false
end

M.jump_to_previous_task = function(wrap)
  local current_task_node = get_task_node()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local found = find_previous_task(current_task_node, cursor[1], 0)

  if wrap and not found then
    local max_line = vim.api.nvim_buf_line_count(0)

    find_previous_task(current_task_node, max_line, cursor[1] + 1)
  end
end

M.is_configured = function()
   return configured
end

return M