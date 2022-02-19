(local f vim.fn)
(local api vim.api)

(lambda open-split [direction]
  "Opens bottom split terminal at 20% height."
  (let [bufheight (f.floor (/ (f.winheight 0) 5))]
    (vim.cmd (.. direction " " bufheight "split"))
    (local bufnr (api.nvim_create_buf false false))
    (api.nvim_set_current_buf bufnr)
    bufnr))

(lambda run [letter]
  (let [command (-> letter
                    (f.getreg)
                    (string.match "^%s*(.-)%s*$")) ; Delete whitespace
        bufheight (f.floor (/ (f.winheight 0) 5))]
    (if (= command "")
      (print (.. "nothing bound to register '" letter "' !"))
      (do
        (open-split "belowright")
        (f.termopen command)
        (api.nvim_command "startinsert")))))

{:run run}
