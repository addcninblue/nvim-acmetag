(local f vim.fn)
(local api vim.api)
(local cmd vim.cmd)
(local opt vim.opt)
(local Job (require "plenary.job"))

; TODO: add support for `<|>`
; TODO: think about support for opening .tagbar in multiple editor instances?

(var tagbufnr nil)
(var pids {})
(var ns (api.nvim_create_namespace "acmetag"))

(api.nvim_set_hl 0 "TagbarComment" {:ctermfg 11 :fg "Gray" :italic 1 :default true})
(api.nvim_set_hl 0 "TagbarError" {:ctermfg 1 :fg "Red" :italic 1 :default true})
(api.nvim_set_hl 0 "TagbarWarn" {:ctermfg 3 :fg "Orange" :default true})
(api.nvim_set_hl 0 "TagbarOK" {:ctermfg 2 :fg "Green" :default true})

(fn kill-pid [pid killcode?]
  (io.popen (.. "kill -" (or killcode? 9) " " pid)))

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

(lambda open-centered-buf-in-float [bufnr width-proportion height-proportion]
  (let [columns (opt.columns:get)
        lines (- (opt.lines:get) 2)
        width (vim.fn.round (* columns width-proportion))
        height (vim.fn.round (* lines height-proportion))
        row-offset (vim.fn.round (/ (- lines height) 2))
        col-offset (vim.fn.round (/ (- columns width) 2))
        win-id (api.nvim_open_win bufnr true {:relative "editor"
                                              :row row-offset
                                              :col col-offset
                                              :width width
                                              :height height
                                              :border "single"})]
    (api.nvim_win_set_option win-id "winhl" "Normal:")
    (api.nvim_create_autocmd "BufLeave" {:callback (fn [{:buf buf :id id}]
                                                     (if (= buf bufnr)
                                                       (do
                                                         (api.nvim_win_close win-id false)
                                                         (api.nvim_del_autocmd id))))})))

(lambda open-acmetag []
  "Opens acmetag in float."
  (local bufnr (api.nvim_create_buf false false))
  (open-centered-buf-in-float bufnr 0.8 0.8)
  bufnr)

(lambda restore-acmetag [bufnr]
  "Restores acmetag in float."
  (open-centered-buf-in-float bufnr 0.8 0.8))

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
    (api.nvim_buf_get_extmarks 0 ns [(- line-nr 1) 0] [(- line-nr 1) -1] [])))

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

(fn append-lines-to-extmark [bufnr extmark-id newline hl]
  "Appends line to extmark"
  (if newline
    (let [lines (get-lines-at-extmark bufnr extmark-id)]
      (table.insert lines [[newline hl]])
      (set-lines-at-extmark bufnr extmark-id lines))))

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
                      :on_stdout (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "TagbarComment")))
                      :on_stderr (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "TagbarError")))
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
    (do (->> (open-acmetag)
             (set tagbufnr))
      (cmd (.. "edit .tagbar"))
      (vim.keymap.set "n" "<CR>" execute-line {:buffer tagbufnr})
      (vim.keymap.set "n" "\\" (fn [] (stop-execution-at-line 15) {:buffer tagbufnr}))
      (vim.keymap.set "n" "<C-\\>" (fn [] (stop-execution-at-line 9) {:buffer tagbufnr})))
    (restore-acmetag tagbufnr)))

{:open-tags open-tags}
