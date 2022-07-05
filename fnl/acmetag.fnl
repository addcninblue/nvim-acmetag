(local f vim.fn)
(local api vim.api)
(local cmd vim.cmd)
(local Job (require "plenary.job"))

; TODO: add support for `<|>`
; TODO: think about support for opening .tagbar in multiple editor instances?

(var tagbufnr nil)
(var pids {})
(var ns (api.nvim_create_namespace "acmetag"))

(api.nvim_set_hl 0 "TagbarError" {:ctermfg 1 :fg "Red" :default true})
(api.nvim_set_hl 0 "TagbarWarn" {:ctermfg 3 :fg "Orange" :default true})
(api.nvim_set_hl 0 "TagbarOK" {:ctermfg 2 :fg "Green" :default true})

(fn kill-pid [pid killcode?]
  (io.popen (.. "kill -" (or killcode? 9) " " pid))) ;; NOTE: use nicer way to terminate maybe?

(lambda kill-all-running-processes []
  (each [_ pid (pairs pids)]
    (kill-pid pid)))

(api.nvim_create_autocmd "VimLeavePre" {:callback kill-all-running-processes})

; (lambda open-split [direction]
;   "Opens bottom split terminal at 20% height."
;   (let [bufheight (f.floor (/ (f.winheight 0) 5))]
;     (vim.cmd (.. direction " " bufheight "split"))
;     (local bufnr (api.nvim_create_buf false false))
;     (api.nvim_set_current_buf bufnr)
;     bufnr))

(lambda open-vert-split [direction]
  "Opens vertical split terminal at 33% width"
  (let [bufheight (f.floor (/ (f.winwidth 0) 3))]
    (vim.cmd (.. direction " " bufheight "vsplit"))
    (local bufnr (api.nvim_create_buf false false))
    (api.nvim_set_current_buf bufnr)
    bufnr))

(lambda restore-vert-split [direction bufnr]
  "Opens bottom split terminal at 33% height."
  (print "Restored existing split.")
  (let [bufheight (f.floor (/ (f.winwidth 0) 3))]
    (vim.cmd (.. direction " " bufheight "vsplit"))
    (api.nvim_set_current_buf bufnr)))

(lambda get-line-at-cursor []
  (->
    (api.nvim_win_get_cursor 0)
    (#(. $1 1))
    (#(api.nvim_buf_get_lines 0 (- $1 1) $1 true))
    (#(. $1 1))))

(lambda get-index [table value]
  (var index nil)
  (each [t-ind t-val (pairs table)]
    (if (= t-val value)
      (set index t-ind)))
  index)

(lambda add-pid [status-extmark-id pid]
  (tset pids status-extmark-id pid))

(lambda remove-pid [pid]
  (let [index (get-index pids pid)]
    (tset pids index nil)))

(lambda get-pid-by-status-extmark [status-extmark-id]
  (. pids status-extmark-id))

(lambda get-extmarks-at-line []
  (let [line-nr (. (api.nvim_win_get_cursor 0) 1)]
    (api.nvim_buf_get_extmarks 0 ns [(- line-nr 1) 0] [(- line-nr 1) 0] [])))

(lambda clear-extmarks-at-line []
  (let [extmarks (get-extmarks-at-line)]
    (each [_ [extmark-id _ _] (ipairs extmarks)]
      (api.nvim_buf_del_extmark 0 ns extmark-id))))

(lambda create-extmark-at-line []
  "Creates extmark and returns its id"
  (api.nvim_buf_set_extmark 0 ns (- (. (api.nvim_win_get_cursor 0) 1) 1) 0 {}))

; {row col {:hl_eol true ... virt_lines [[["text" "Comment"]]]}}
; https://github.com/neovim/neovim/pull/17076
(lambda get-lines-at-extmark [bufnr extmark-id]
  (or (-> (api.nvim_buf_get_extmark_by_id bufnr ns extmark-id {:details true})
          (. 3)
          (. :virt_lines)
          )
      []))

(lambda get-row-at-extmark [bufnr extmark-id]
  (-> (api.nvim_buf_get_extmark_by_id bufnr ns extmark-id {:details true})
      (. 1)))

(lambda set-lines-at-extmark [bufnr extmark-id lines]
  (let [line-nr (get-row-at-extmark bufnr extmark-id)]
    (api.nvim_buf_set_extmark bufnr ns line-nr 0 {:id extmark-id
                                                  :virt_lines lines})))

(lambda append-lines-to-extmark [bufnr extmark-id newline hl]
  "Appends line to extmark"
  (let [lines (get-lines-at-extmark bufnr extmark-id)]
    (table.insert lines [[newline hl]])
    (set-lines-at-extmark bufnr extmark-id lines)))

(lambda set-extmark [bufnr extmark-id text hl]
  (let [line-nr (get-row-at-extmark bufnr extmark-id)]
    (api.nvim_buf_set_extmark bufnr ns line-nr 0 {:id extmark-id
                                                  :virt_text [[text hl]]})))

(lambda execute-line []
  (clear-extmarks-at-line)
  (let [line (get-line-at-cursor)
        output-extmark-id (create-extmark-at-line)
        status-extmark-id (create-extmark-at-line)
        bufnr (f.bufnr)
        job (Job:new {:command "/bin/sh"
                      :args ["-c" line]
                      :on_stdout (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "Comment")))
                      :on_stderr (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "Error")))
                      :on_exit (vim.schedule_wrap (lambda [j retval] (do
                                                                       (remove-pid j.pid)
                                                                       (set-extmark bufnr status-extmark-id "■"
                                                                                    (if (or (~= 0 j.code) (~= 0 j.signal))
                                                                                      "TagbarError"
                                                                                      "TagbarOK")))))})]
    ; TODO: set start and end times
    (set-extmark bufnr status-extmark-id "■" "TagbarWarn")
    (: job "start")
    (add-pid status-extmark-id job.pid)))

(lambda stop-execution-at-line [signal]
  (each [_ [extmark-id _ _] (ipairs (get-extmarks-at-line))]
    (let [pid (get-pid-by-status-extmark extmark-id)]
      (if (~= nil pid)
        (kill-pid pid signal)))))

(lambda open-tags []
  (if (or (= tagbufnr nil) (not (f.bufexists tagbufnr)))
    (do (->> (open-vert-split "belowright")
             (set tagbufnr))
      (cmd (.. "edit .tagbar"))
      (vim.keymap.set "n" "<CR>" execute-line {:buffer tagbufnr})
      (vim.keymap.set "n" "\\" (fn [] (stop-execution-at-line 15) {:buffer tagbufnr}))
      (vim.keymap.set "n" "<C-\\>" (fn [] (stop-execution-at-line 9) {:buffer tagbufnr})))
    (restore-vert-split "belowright" tagbufnr)))

{:open-tags open-tags}
