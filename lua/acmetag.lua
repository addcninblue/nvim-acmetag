local f = vim.fn
local api = vim.api
local cmd = vim.cmd
local opt = vim.opt
local Job = require("plenary.job")
local tagbufnr = nil
local pids = {}
local ns = api.nvim_create_namespace("acmetag")
api.nvim_set_hl(0, "TagbarComment", {ctermfg = 11, fg = "Gray", italic = 1, default = true})
api.nvim_set_hl(0, "TagbarError", {ctermfg = 1, fg = "Red", italic = 1, default = true})
api.nvim_set_hl(0, "TagbarWarn", {ctermfg = 3, fg = "Orange", default = true})
api.nvim_set_hl(0, "TagbarOK", {ctermfg = 2, fg = "Green", default = true})
local function kill_pid(pid, killcode_3f)
  return io.popen(("kill -" .. (killcode_3f or 9) .. " " .. pid))
end
local function kill_all_running_processes()
  for _, pid in pairs(pids) do
    kill_pid(pid)
  end
  return nil
end
api.nvim_create_autocmd("VimLeavePre", {callback = kill_all_running_processes})
local function open_centered_buf_in_float(bufnr, width_proportion, height_proportion)
  _G.assert((nil ~= height_proportion), "Missing argument height-proportion on fnl/acmetag.fnl:36")
  _G.assert((nil ~= width_proportion), "Missing argument width-proportion on fnl/acmetag.fnl:36")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:36")
  local columns = (opt.columns):get()
  local lines = ((opt.lines):get() - 2)
  local width = vim.fn.round((columns * width_proportion))
  local height = vim.fn.round((lines * height_proportion))
  local row_offset = vim.fn.round(((lines - height) / 2))
  local col_offset = vim.fn.round(((columns - width) / 2))
  local win_id = api.nvim_open_win(bufnr, true, {relative = "editor", row = row_offset, col = col_offset, width = width, height = height, border = "single"})
  api.nvim_win_set_option(win_id, "winhl", "Normal:")
  local function _3_(_1_)
    local _arg_2_ = _1_
    local buf = _arg_2_["buf"]
    local id = _arg_2_["id"]
    if (buf == bufnr) then
      api.nvim_win_close(win_id, false)
      return api.nvim_del_autocmd(id)
    else
      return nil
    end
  end
  return api.nvim_create_autocmd("BufLeave", {callback = _3_})
end
local function open_acmetag()
  local bufnr = api.nvim_create_buf(false, false)
  open_centered_buf_in_float(bufnr, 0.8, 0.8)
  return bufnr
end
local function restore_acmetag(bufnr)
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:62")
  return open_centered_buf_in_float(bufnr, 0.8, 0.8)
end
local function get_line_at_cursor()
  local function _5_(_241)
    return (_241)[1]
  end
  local function _6_(_241)
    return api.nvim_buf_get_lines(0, (_241 - 1), _241, true)
  end
  local function _7_(_241)
    return (_241)[1]
  end
  return _5_(_6_(_7_(api.nvim_win_get_cursor(0))))
end
local function get_index(table, value)
  _G.assert((nil ~= value), "Missing argument value on fnl/acmetag.fnl:73")
  _G.assert((nil ~= table), "Missing argument table on fnl/acmetag.fnl:73")
  local index = nil
  for t_ind, t_val in pairs(table) do
    if (t_val == value) then
      index = t_ind
    else
    end
  end
  return index
end
local function add_pid(status_extmark_id, pid)
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:80")
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:80")
  do end (pids)[status_extmark_id] = pid
  return nil
end
local function remove_pid(pid)
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:83")
  local index = get_index(pids, pid)
  do end (pids)[index] = nil
  return nil
end
local function get_pid_by_status_extmark(status_extmark_id)
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:87")
  return pids[status_extmark_id]
end
local function get_extmarks_at_line()
  local line_nr = (api.nvim_win_get_cursor(0))[1]
  return api.nvim_buf_get_extmarks(0, ns, {(line_nr - 1), 0}, {(line_nr - 1), -1}, {})
end
local function clear_extmarks_at_line()
  local extmarks = get_extmarks_at_line()
  for _, _9_ in ipairs(extmarks) do
    local _each_10_ = _9_
    local extmark_id = _each_10_[1]
    local _0 = _each_10_[2]
    local _1 = _each_10_[3]
    api.nvim_buf_del_extmark(0, ns, extmark_id)
  end
  return nil
end
local function create_extmark_at_line()
  return api.nvim_buf_set_extmark(0, ns, ((api.nvim_win_get_cursor(0))[1] - 1), 0, {})
end
local function get_lines_at_extmark(bufnr, extmark_id)
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:105")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:105")
  local function _11_()
    return ((api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[3]).virt_lines
  end
  return (_11_() or {})
end
local function get_row_at_extmark(bufnr, extmark_id)
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:112")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:112")
  return (api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[1]
end
local function set_lines_at_extmark(bufnr, extmark_id, lines)
  _G.assert((nil ~= lines), "Missing argument lines on fnl/acmetag.fnl:116")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:116")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:116")
  local line_nr = get_row_at_extmark(bufnr, extmark_id)
  return api.nvim_buf_set_extmark(bufnr, ns, line_nr, 0, {id = extmark_id, virt_lines = lines})
end
local function append_lines_to_extmark(bufnr, extmark_id, newline, hl)
  if newline then
    local lines = get_lines_at_extmark(bufnr, extmark_id)
    table.insert(lines, {{newline, hl}})
    return set_lines_at_extmark(bufnr, extmark_id, lines)
  else
    return nil
  end
end
local function set_extmark(bufnr, extmark_id, text, hl)
  _G.assert((nil ~= hl), "Missing argument hl on fnl/acmetag.fnl:128")
  _G.assert((nil ~= text), "Missing argument text on fnl/acmetag.fnl:128")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:128")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:128")
  local line_nr = get_row_at_extmark(bufnr, extmark_id)
  return api.nvim_buf_set_extmark(bufnr, ns, line_nr, 0, {id = extmark_id, virt_text = {{text, hl}}})
end
local function execute_line()
  clear_extmarks_at_line()
  local line = get_line_at_cursor()
  local output_extmark_id = create_extmark_at_line()
  local status_extmark_id = create_extmark_at_line()
  local bufnr = f.bufnr()
  local job
  local function _13_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "TagbarComment")
  end
  local function _14_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "TagbarError")
  end
  local function _15_(j, retval)
    _G.assert((nil ~= retval), "Missing argument retval on fnl/acmetag.fnl:143")
    _G.assert((nil ~= j), "Missing argument j on fnl/acmetag.fnl:143")
    remove_pid(j.pid)
    local function _16_()
      if ((0 ~= j.code) or (0 ~= j.signal)) then
        return "TagbarError"
      else
        return "TagbarOK"
      end
    end
    return set_extmark(bufnr, status_extmark_id, "\226\150\160", _16_())
  end
  job = Job:new({command = "/bin/sh", args = {"-c", line}, on_stdout = vim.schedule_wrap(_13_), on_stderr = vim.schedule_wrap(_14_), on_exit = vim.schedule_wrap(_15_)})
  set_extmark(bufnr, status_extmark_id, "\226\150\160", "TagbarWarn")
  job:start()
  return add_pid(status_extmark_id, job.pid)
end
local function stop_execution_at_line(signal)
  _G.assert((nil ~= signal), "Missing argument signal on fnl/acmetag.fnl:154")
  for _, _17_ in ipairs(get_extmarks_at_line()) do
    local _each_18_ = _17_
    local extmark_id = _each_18_[1]
    local _0 = _each_18_[2]
    local _1 = _each_18_[3]
    local pid = get_pid_by_status_extmark(extmark_id)
    if (nil ~= pid) then
      kill_pid(pid, signal)
    else
    end
  end
  return nil
end
local function open_tags()
  if ((tagbufnr == nil) or not f.bufexists(tagbufnr)) then
    tagbufnr = open_acmetag()
    cmd("edit .tagbar")
    vim.keymap.set("n", "<CR>", execute_line, {buffer = tagbufnr})
    local function _20_()
      stop_execution_at_line(15)
      return {buffer = tagbufnr}
    end
    vim.keymap.set("n", "\\", _20_)
    local function _21_()
      stop_execution_at_line(9)
      return {buffer = tagbufnr}
    end
    return vim.keymap.set("n", "<C-\\>", _21_)
  else
    return restore_acmetag(tagbufnr)
  end
end
return {["open-tags"] = open_tags}
