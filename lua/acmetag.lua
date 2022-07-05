local f = vim.fn
local api = vim.api
local cmd = vim.cmd
local Job = require("plenary.job")
local tagbufnr = nil
local pids = {}
local ns = api.nvim_create_namespace("acmetag")
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
local function open_vert_split(direction)
  _G.assert((nil ~= direction), "Missing argument direction on fnl/acmetag.fnl:31")
  local bufheight = f.floor((f.winwidth(0) / 3))
  vim.cmd((direction .. " " .. bufheight .. "vsplit"))
  local bufnr = api.nvim_create_buf(false, false)
  api.nvim_set_current_buf(bufnr)
  return bufnr
end
local function restore_vert_split(direction, bufnr)
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:39")
  _G.assert((nil ~= direction), "Missing argument direction on fnl/acmetag.fnl:39")
  print("Restored existing split.")
  local bufheight = f.floor((f.winwidth(0) / 3))
  vim.cmd((direction .. " " .. bufheight .. "vsplit"))
  return api.nvim_set_current_buf(bufnr)
end
local function get_line_at_cursor()
  local function _1_(_241)
    return (_241)[1]
  end
  local function _2_(_241)
    return api.nvim_buf_get_lines(0, (_241 - 1), _241, true)
  end
  local function _3_(_241)
    return (_241)[1]
  end
  return _1_(_2_(_3_(api.nvim_win_get_cursor(0))))
end
local function get_index(table, value)
  _G.assert((nil ~= value), "Missing argument value on fnl/acmetag.fnl:53")
  _G.assert((nil ~= table), "Missing argument table on fnl/acmetag.fnl:53")
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
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:60")
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:60")
  do end (pids)[status_extmark_id] = pid
  return nil
end
local function remove_pid(pid)
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:63")
  local index = get_index(pids, pid)
  do end (pids)[index] = nil
  return nil
end
local function get_pid_by_status_extmark(status_extmark_id)
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:67")
  return pids[status_extmark_id]
end
local function get_extmarks_at_line()
  local line_nr = (api.nvim_win_get_cursor(0))[1]
  return api.nvim_buf_get_extmarks(0, ns, {(line_nr - 1), 0}, {(line_nr - 1), 0}, {})
end
local function clear_extmarks_at_line()
  local extmarks = get_extmarks_at_line()
  for _, _5_ in ipairs(extmarks) do
    local _each_6_ = _5_
    local extmark_id = _each_6_[1]
    local _0 = _each_6_[2]
    local _1 = _each_6_[3]
    api.nvim_buf_del_extmark(0, ns, extmark_id)
  end
  return nil
end
local function create_extmark_at_line()
  return api.nvim_buf_set_extmark(0, ns, ((api.nvim_win_get_cursor(0))[1] - 1), 0, {})
end
local function get_lines_at_extmark(bufnr, extmark_id)
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:85")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:85")
  local function _7_()
    return ((api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[3]).virt_lines
  end
  return (_7_() or {})
end
local function get_row_at_extmark(bufnr, extmark_id)
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:92")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:92")
  return (api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[1]
end
local function set_lines_at_extmark(bufnr, extmark_id, lines)
  _G.assert((nil ~= lines), "Missing argument lines on fnl/acmetag.fnl:96")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:96")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:96")
  local line_nr = get_row_at_extmark(bufnr, extmark_id)
  return api.nvim_buf_set_extmark(bufnr, ns, line_nr, 0, {id = extmark_id, virt_lines = lines})
end
local function append_lines_to_extmark(bufnr, extmark_id, newline, hl)
  _G.assert((nil ~= hl), "Missing argument hl on fnl/acmetag.fnl:101")
  _G.assert((nil ~= newline), "Missing argument newline on fnl/acmetag.fnl:101")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:101")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:101")
  local lines = get_lines_at_extmark(bufnr, extmark_id)
  table.insert(lines, {{newline, hl}})
  return set_lines_at_extmark(bufnr, extmark_id, lines)
end
local function set_extmark(bufnr, extmark_id, text, hl)
  _G.assert((nil ~= hl), "Missing argument hl on fnl/acmetag.fnl:107")
  _G.assert((nil ~= text), "Missing argument text on fnl/acmetag.fnl:107")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:107")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:107")
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
  local function _8_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "Comment")
  end
  local function _9_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "Error")
  end
  local function _10_(j, retval)
    _G.assert((nil ~= retval), "Missing argument retval on fnl/acmetag.fnl:122")
    _G.assert((nil ~= j), "Missing argument j on fnl/acmetag.fnl:122")
    remove_pid(j.pid)
    local function _11_()
      if ((0 ~= j.code) or (0 ~= j.signal)) then
        return "DiagnosticVirtualTextError"
      else
        return "DiagnosticVirtualTextHint"
      end
    end
    return set_extmark(bufnr, status_extmark_id, "\226\150\160", _11_())
  end
  job = Job:new({command = "/bin/sh", args = {"-c", line}, on_stdout = vim.schedule_wrap(_8_), on_stderr = vim.schedule_wrap(_9_), on_exit = vim.schedule_wrap(_10_)})
  set_extmark(bufnr, status_extmark_id, "\226\150\160", "DiagnosticVirtualTextWarn")
  job:start()
  return add_pid(status_extmark_id, job.pid)
end
local function stop_execution_at_line(signal)
  _G.assert((nil ~= signal), "Missing argument signal on fnl/acmetag.fnl:133")
  for _, _12_ in ipairs(get_extmarks_at_line()) do
    local _each_13_ = _12_
    local extmark_id = _each_13_[1]
    local _0 = _each_13_[2]
    local _1 = _each_13_[3]
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
    tagbufnr = open_vert_split("belowright")
    cmd("edit .tagbar")
    vim.keymap.set("n", "<CR>", execute_line, {buffer = tagbufnr})
    local function _15_()
      stop_execution_at_line(15)
      return {buffer = tagbufnr}
    end
    vim.keymap.set("n", "\\", _15_)
    local function _16_()
      stop_execution_at_line(9)
      return {buffer = tagbufnr}
    end
    return vim.keymap.set("n", "<C-\\>", _16_)
  else
    return restore_vert_split("belowright", tagbufnr)
  end
end
return {["open-tags"] = open_tags}
