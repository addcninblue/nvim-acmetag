local f = vim.fn
local api = vim.api
local cmd = vim.cmd
local opt = vim.opt
local Job = require("plenary.job")
local tagbufnr = nil
local input = nil
local visual_marks = nil
local selection_type = nil
local last_buffer = nil
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
  _G.assert((nil ~= height_proportion), "Missing argument height-proportion on fnl/acmetag.fnl:39")
  _G.assert((nil ~= width_proportion), "Missing argument width-proportion on fnl/acmetag.fnl:39")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:39")
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
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:65")
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
  _G.assert((nil ~= value), "Missing argument value on fnl/acmetag.fnl:76")
  _G.assert((nil ~= table), "Missing argument table on fnl/acmetag.fnl:76")
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
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:83")
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:83")
  do end (pids)[status_extmark_id] = pid
  return nil
end
local function remove_pid(pid)
  _G.assert((nil ~= pid), "Missing argument pid on fnl/acmetag.fnl:86")
  local index = get_index(pids, pid)
  do end (pids)[index] = nil
  return nil
end
local function get_pid_by_status_extmark(status_extmark_id)
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:90")
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
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:108")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:108")
  local function _11_()
    return ((api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[3]).virt_lines
  end
  return (_11_() or {})
end
local function get_row_at_extmark(bufnr, extmark_id)
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:115")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:115")
  return (api.nvim_buf_get_extmark_by_id(bufnr, ns, extmark_id, {details = true}))[1]
end
local function set_lines_at_extmark(bufnr, extmark_id, lines)
  _G.assert((nil ~= lines), "Missing argument lines on fnl/acmetag.fnl:119")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:119")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:119")
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
  _G.assert((nil ~= hl), "Missing argument hl on fnl/acmetag.fnl:131")
  _G.assert((nil ~= text), "Missing argument text on fnl/acmetag.fnl:131")
  _G.assert((nil ~= extmark_id), "Missing argument extmark-id on fnl/acmetag.fnl:131")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:131")
  local line_nr = get_row_at_extmark(bufnr, extmark_id)
  return api.nvim_buf_set_extmark(bufnr, ns, line_nr, 0, {id = extmark_id, virt_text = {{text, hl}}})
end
local function process_command(command)
  _G.assert((nil ~= command), "Missing argument command on fnl/acmetag.fnl:136")
  if (string.len(command) < 1) then
    return nil
  else
    local first_char = string.sub(command, 1, 1)
    local remainder = string.sub(command, 2, -1)
    if (first_char == ">") then
      return {input = true, command = remainder, output = false}
    elseif (first_char == "<") then
      return {command = remainder, output = true, input = false}
    elseif (first_char == "|") then
      return {input = true, command = remainder, output = true}
    else
      return {command = command, output = false, input = false}
    end
  end
end
local function calculate_positions(_15_, selection_type0)
  local _arg_16_ = _15_
  local _arg_17_ = _arg_16_[1]
  local _ = _arg_17_[1]
  local start_row = _arg_17_[2]
  local start_col = _arg_17_[3]
  local _start_off = _arg_17_[4]
  local _arg_18_ = _arg_16_[2]
  local _0 = _arg_18_[1]
  local end_row = _arg_18_[2]
  local end_col = _arg_18_[3]
  local _end_off = _arg_18_[4]
  local _let_19_ = api.nvim_buf_get_lines(last_buffer, (end_row - 1), end_row, true)
  local current_last_line = _let_19_[1]
  local last_line_length = string.len(current_last_line)
  if selection_type0 then
    if (end_col > last_line_length) then
      return {(start_row - 1), (start_col - 1), (end_row - 1), last_line_length}
    else
      return {(start_row - 1), (start_col - 1), (end_row - 1), end_col}
    end
  else
    if (0 == last_line_length) then
      return {(start_row - 1), start_col, (end_row - 1), end_col}
    else
      return {(start_row - 1), (start_col + 1), (end_row - 1), (end_col + 1)}
    end
  end
end
local function create_job(_23_, bufnr, output_extmark_id, status_extmark_id)
  local _arg_24_ = _23_
  local input_3f = _arg_24_["input"]
  local command = _arg_24_["command"]
  local output_3f = _arg_24_["output"]
  _G.assert((nil ~= status_extmark_id), "Missing argument status-extmark-id on fnl/acmetag.fnl:159")
  _G.assert((nil ~= output_extmark_id), "Missing argument output-extmark-id on fnl/acmetag.fnl:159")
  _G.assert((nil ~= bufnr), "Missing argument bufnr on fnl/acmetag.fnl:159")
  _G.assert((nil ~= command), "Missing argument command on fnl/acmetag.fnl:159")
  _G.assert((nil ~= input_3f), "Missing argument input? on fnl/acmetag.fnl:159")
  _G.assert((nil ~= output_3f), "Missing argument output? on fnl/acmetag.fnl:159")
  local tempfile = vim.fn.tempname()
  local inputfile = (tempfile .. "+input")
  local outputfile = (tempfile .. "+output")
  local line
  local function _25_()
    if input_3f then
      return ("cat " .. inputfile .. " | ")
    else
      return ""
    end
  end
  local function _26_()
    if output_3f then
      return ("> " .. outputfile)
    else
      return ""
    end
  end
  line = (_25_() .. command .. _26_())
  local _let_27_ = calculate_positions(visual_marks, selection_type)
  local start_row = _let_27_[1]
  local start_col = _let_27_[2]
  local end_row = _let_27_[3]
  local end_col = _let_27_[4]
  local function _28_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "TagbarComment")
  end
  local function _29_(_, data)
    return append_lines_to_extmark(bufnr, output_extmark_id, data, "TagbarError")
  end
  local function _30_(j, retval)
    _G.assert((nil ~= retval), "Missing argument retval on fnl/acmetag.fnl:174")
    _G.assert((nil ~= j), "Missing argument j on fnl/acmetag.fnl:174")
    remove_pid(j.pid)
    if output_3f then
      api.nvim_buf_set_text(last_buffer, start_row, start_col, end_row, end_col, f.readfile(outputfile))
    else
    end
    local function _32_()
      if ((0 ~= j.code) or (0 ~= j.signal)) then
        return "TagbarError"
      else
        return "TagbarOK"
      end
    end
    return set_extmark(bufnr, status_extmark_id, "\226\150\160", _32_())
  end
  return {inputfile = inputfile, outputfile = outputfile, job = Job:new({command = "/bin/sh", args = {"-c", line}, on_stdout = vim.schedule_wrap(_28_), on_stderr = vim.schedule_wrap(_29_), on_exit = vim.schedule_wrap(_30_)})}
end
local function execute_line()
  clear_extmarks_at_line()
  local output_extmark_id = create_extmark_at_line()
  local status_extmark_id = create_extmark_at_line()
  local bufnr = f.bufnr()
  local processed
  do
    local _33_ = get_line_at_cursor()
    if (nil ~= _33_) then
      processed = process_command(_33_)
    else
      processed = _33_
    end
  end
  local _let_35_ = processed
  local needs_input = _let_35_["input"]
  local needs_output = _let_35_["output"]
  local _let_36_ = create_job(processed, bufnr, output_extmark_id, status_extmark_id)
  local inputfile = _let_36_["inputfile"]
  local outputfile = _let_36_["outputfile"]
  local job = _let_36_["job"]
  if (nil ~= job) then
    if needs_input then
      if input then
        vim.fn.writefile(input, inputfile)
      else
        print("Error: Needed input but did not send.")
      end
    else
    end
    set_extmark(bufnr, status_extmark_id, "\226\150\160", "TagbarWarn")
    job:start()
    return add_pid(status_extmark_id, job.pid)
  else
    return nil
  end
end
local function stop_execution_at_line(signal)
  _G.assert((nil ~= signal), "Missing argument signal on fnl/acmetag.fnl:207")
  for _, _40_ in ipairs(get_extmarks_at_line()) do
    local _each_41_ = _40_
    local extmark_id = _each_41_[1]
    local _0 = _each_41_[2]
    local _1 = _each_41_[3]
    local pid = get_pid_by_status_extmark(extmark_id)
    if (nil ~= pid) then
      kill_pid(pid, signal)
    else
    end
  end
  return nil
end
local function save_vars_and_open_tags(new_input, new_visual_marks, new_selection_type)
  input = new_input
  visual_marks = new_visual_marks
  selection_type = new_selection_type
  last_buffer = vim.api.nvim_get_current_buf()
  vim.pretty_print(last_buffer)
  vim.pretty_print(tagbufnr)
  if (last_buffer ~= tagbufnr) then
    if ((tagbufnr == nil) or not f.bufexists(tagbufnr)) then
      tagbufnr = open_acmetag()
      cmd("edit .tagbar")
      local function _43_()
        return execute_line()
      end
      vim.keymap.set("n", "<CR>", _43_, {buffer = tagbufnr})
      local function _44_()
        return stop_execution_at_line(15)
      end
      vim.keymap.set("n", "\\", _44_, {buffer = tagbufnr})
      local function _45_()
        return stop_execution_at_line(9)
      end
      return vim.keymap.set("n", "<C-\\>", _45_, {buffer = tagbufnr})
    else
      return restore_acmetag(tagbufnr)
    end
  else
    return nil
  end
end
local function open_tags()
  local _let_48_ = api.nvim_win_get_cursor(0)
  local row = _let_48_[1]
  local col = _let_48_[2]
  local col0 = col
  local start = {0, row, col0, 0}
  local _end = {0, row, col0, 0}
  return save_vars_and_open_tags(nil, {start, _end}, nil)
end
local function pipe_to_tags(selection_type0)
  if (selection_type0 == nil) then
    vim.o.opfunc = "v:lua.require'acmetag'.pipe_to_tags"
    return "g@"
  else
    local sel_save = vim.o.selection
    local reg_save = f.getreginfo("\"")
    local cb_save = vim.o.clipboard
    local visual_marks_save = {f.getpos("'<"), f.getpos("'>")}
    local commands = {line = "'[V']y", char = "`[v`]y", block = api.nvim_replace_termcodes("`[<c-v>`]y", true, true, true)}
    vim.o.clipboard = ""
    vim.o.selection = "inclusive"
    vim.cmd(("noautocmd keepjumps normal! " .. commands[selection_type0]))
    do
      local input0 = f.getreg("\"", " ", true)
      local visual_marks0 = {f.getpos("'<"), f.getpos("'>")}
      save_vars_and_open_tags(input0, visual_marks0, selection_type0)
    end
    f.setreg("\"", reg_save)
    f.setpos("'<", visual_marks_save[1])
    f.setpos("'>", visual_marks_save[2])
    vim.o.clipboard = cb_save
    vim.o.selection = sel_save
    return nil
  end
end
return {open_tags = open_tags, pipe_to_tags = pipe_to_tags}
