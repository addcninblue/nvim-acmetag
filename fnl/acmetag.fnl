(local f vim.fn)
(local api vim.api)
(local cmd vim.cmd)
(local opt vim.opt)
(local Job (require "plenary.job"))

; TODO: think about support for opening .tagbar in multiple editor instances?

(var tagbufnr nil)
(var input nil)
(var visual-marks nil)
(var selection-type nil)
(var last-buffer nil)
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

(lambda process-command [command]
  (if (< (string.len command) 1)
    nil
    (let [first-char (string.sub command 1 1)
          remainder (string.sub command 2 -1)]
      (if (= first-char ">") {:input true :command remainder :output false}
          (= first-char "<") {:input false :command remainder :output true}
          (= first-char "|") {:input true :command remainder :output true}
          {:input false :command command :output false}))))

(fn calculate-positions
  [[[_ start-row start-col _start-off] [_ end-row end-col _end-off]]
   selection-type]
  (let [[ current-last-line ] (api.nvim_buf_get_lines last-buffer (- end-row 1) end-row true)
        last-line-length (string.len current-last-line)]
    (if selection-type
      (if (> end-col last-line-length) ;; Selection (visual-mode or motion)
        [(- start-row 1) (- start-col 1) (- end-row 1) last-line-length] ; Clamp
        [(- start-row 1) (- start-col 1) (- end-row 1) end-col])
      (if (= 0 last-line-length) ;; No selection
            [(- start-row 1) start-col (- end-row 1) end-col]
            [(- start-row 1) (+ start-col 1) (- end-row 1) (+ end-col 1)]))))

(lambda create-job [{:input input? :command command :output output?} bufnr output-extmark-id status-extmark-id]
  (let [tempfile (vim.fn.tempname)
        inputfile (.. tempfile "+input")
        outputfile (.. tempfile "+output")
        line
        (.. (if input? (.. "cat " inputfile " | ") "")
            command
            (if output? (.. "> " outputfile) ""))
        [start-row start-col end-row end-col] (calculate-positions visual-marks selection-type)]
    {:inputfile inputfile
     :outputfile outputfile
     :job (Job:new {:command "/bin/sh"
                    :args ["-c" line]
                    :on_stdout (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "TagbarComment")))
                    :on_stderr (vim.schedule_wrap (fn [_ data] (append-lines-to-extmark bufnr output-extmark-id data "TagbarError")))
                    :on_exit (vim.schedule_wrap (lambda [j retval]
                                                  (do
                                                    (remove-pid j.pid)
                                                    (if output?
                                                      (api.nvim_buf_set_text last-buffer start-row start-col end-row end-col (f.readfile outputfile)))
                                                    (set-extmark bufnr status-extmark-id "■"
                                                                 (if (or (~= 0 j.code) (~= 0 j.signal))
                                                                   "TagbarError"
                                                                   "TagbarOK")))))})}))

(fn execute-line []
  (clear-extmarks-at-line)
  (let [output-extmark-id (create-extmark-at-line)
        status-extmark-id (create-extmark-at-line)
        bufnr (f.bufnr)
        processed (-?> (get-line-at-cursor)
                       (process-command))
        {:input needs_input
         :output needs_output} processed
        {:inputfile inputfile
         :outputfile outputfile
         :job job} (create-job processed bufnr output-extmark-id status-extmark-id)]
    ; TODO: set start and end times
    (if (~= nil job)
      (do
        (if needs_input
          (if input
            (vim.fn.writefile input inputfile)
            (print "Error: Needed input but did not send."))) ;; TODO: Figure out how to throw exception
        (set-extmark bufnr status-extmark-id "■" "TagbarWarn")
        (: job "start")
        (add-pid status-extmark-id job.pid)))))

(lambda stop-execution-at-line [signal]
  (each [_ [extmark-id _ _] (ipairs (get-extmarks-at-line))]
    (let [pid (get-pid-by-status-extmark extmark-id)]
      (if (~= nil pid)
        (kill-pid pid signal)))))

(fn save-vars-and-open-tags [new-input new-visual-marks new-selection-type]
  (set input new-input)
  (set visual-marks new-visual-marks)
  (set selection-type new-selection-type)
  (set last-buffer (vim.api.nvim_get_current_buf))
  (vim.pretty_print last-buffer)
  (vim.pretty_print tagbufnr)
  (if (~= last-buffer tagbufnr)
    (if (or (= tagbufnr nil) (not (f.bufexists tagbufnr)))
      (do (->> (open-acmetag)
               (set tagbufnr))
        (cmd (.. "edit .tagbar"))
        (vim.keymap.set "n" "<CR>" #(execute-line) {:buffer tagbufnr})
        (vim.keymap.set "n" "\\" #(stop-execution-at-line 15) {:buffer tagbufnr})
        (vim.keymap.set "n" "<C-\\>" #(stop-execution-at-line 9) {:buffer tagbufnr}))
      (restore-acmetag tagbufnr))))

(lambda open-tags []
  (let [[row col] (api.nvim_win_get_cursor 0)
        col col
        start [0 row col 0]
        end [0 row col 0]]
    (save-vars-and-open-tags nil [start end] nil)))

(fn pipe-to-tags [selection-type]
  (if (= selection-type nil)
    (do
      (set vim.o.opfunc "v:lua.require'acmetag'.pipe_to_tags")
      "g@")
    (let [sel-save vim.o.selection
          reg-save (f.getreginfo "\"")
          cb-save vim.o.clipboard
          visual-marks-save [(f.getpos "'<") (f.getpos "'>")]
          commands {"line" "'[V']y"
                    "char" "`[v`]y"
                    "block" (api.nvim_replace_termcodes "`[<c-v>`]y" true true true)}]
      (set vim.o.clipboard "")
      (set vim.o.selection "inclusive")
      (vim.cmd (.. "noautocmd keepjumps normal! " (. commands selection-type)))

      (let [input (f.getreg "\"" " " true)
            visual-marks [(f.getpos "'<") (f.getpos "'>")]]
        (save-vars-and-open-tags input visual-marks selection-type))

      ; Restore original variables
      (f.setreg "\"" reg-save)
      (f.setpos "'<" (. visual-marks-save 1))
      (f.setpos "'>" (. visual-marks-save 2))
      (set vim.o.clipboard cb-save)
      (set vim.o.selection sel-save))))

{:open_tags open-tags
 :pipe_to_tags pipe-to-tags}
