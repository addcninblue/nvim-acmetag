local f = vim.fn
local api = vim.api
local function open_split(direction)
  _G.assert((nil ~= direction), "Missing argument direction on fnl/acmetag.fnl:4")
  local bufheight = f.floor((f.winheight(0) / 5))
  vim.cmd((direction .. " " .. bufheight .. "split"))
  local bufnr = api.nvim_create_buf(false, false)
  api.nvim_set_current_buf(bufnr)
  return bufnr
end
local function run(letter)
  _G.assert((nil ~= letter), "Missing argument letter on fnl/acmetag.fnl:12")
  local command = string.match(f.getreg(letter), "^%s*(.-)%s*$")
  local bufheight = f.floor((f.winheight(0) / 5))
  if (command == "") then
    return print(("nothing bound to register '" .. letter .. "' !"))
  else
    open_split("belowright")
    f.termopen(command)
    return api.nvim_command("startinsert")
  end
end
local letters = {"a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"}
local function display_registers()
  local bufnr = open_split("topleft")
  local function _2_()
    local tbl_15_auto = {}
    local i_16_auto = #tbl_15_auto
    for _, letter in ipairs(letters) do
      local val_17_auto
      do
        local reg = f.getreg(letter, 1)
        if not string.find(reg, "\n") then
          val_17_auto = (letter .. ": " .. reg)
        else
          val_17_auto = nil
        end
      end
      if (nil ~= val_17_auto) then
        i_16_auto = (i_16_auto + 1)
        do end (tbl_15_auto)[i_16_auto] = val_17_auto
      else
      end
    end
    return tbl_15_auto
  end
  api.nvim_buf_set_lines(bufnr, 0, -1, true, _2_())
  vim.bo.bufhidden = "hide"
  vim.bo.buflisted = false
  vim.bo.buftype = "nofile"
  return nil
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
local function yank_line_to_register()
  local line = get_line_at_cursor()
  if (#line > 3) then
    local letter = string.sub(line, 1, 1)
    local contents = string.sub(line, 4)
    f.setreg(letter, contents)
    return print(("Yanked to register " .. letter))
  else
    return nil
  end
end
return {run = run, display_registers = display_registers, yank_line_to_register = yank_line_to_register}
