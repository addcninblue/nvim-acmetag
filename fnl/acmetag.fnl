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

(local letters [ "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ])

(lambda display-registers []
  (let [bufnr (open-split "topleft")]
    (api.nvim_buf_set_lines bufnr 0 -1 true
                            (icollect [_ letter (ipairs letters)]
                                      (let [reg (f.getreg letter 1)]
                                        (if (not (string.find reg "\n"))
                                          (.. letter ": " reg)))))
    (set vim.bo.bufhidden "hide")
    (set vim.bo.buflisted false)
    (set vim.bo.buftype "nofile")))

{:run run :display_registers display-registers}
