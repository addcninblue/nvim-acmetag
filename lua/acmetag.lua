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
return {run = run}
