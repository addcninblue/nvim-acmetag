# Nvim-Acmetag

This plugin started with inspiration the Plan9 Acme editor, which has this cool
concept of "text as actions". This concept allows one to drag text from the
editor into the toolbar, which allows them to execute the text as if it were a
button.

In Neovim, we can abuse the register system to do something similar. For
example, we might run `make test` often, so we might want this as a "button in
our toolbar".

For this usecase, we can use Nvim-Acmetag as follows:

* yank the following into the `a` register: `make test`
* execute `make test` by running `lua require("acmetag").run("a")`

We can streamline this by `nnoremap`ping `-a` to that function above, letting
execute `make test` with `-a`. Here is the config that I use:

```lua
;;;; Vim-Acmetag
(let [letters [ "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ]
      acmetag (require "acmetag")]
  (each [_ letter (ipairs letters)]
    (vimp.nnoremap ["silent"] (.. "-" letter)
                   (lambda [] (acmetag.run letter))))
  (vimp.nnoremap ["silent"] "--" acmetag.display_registers)
  (vimp.nnoremap ["silent"] "- " acmetag.yank_line_to_register)
  )
```

You may notice that there are two extra functions bound in there:
`display_registers` and `yank_line_to_register`. These are helper functions
that embellish the main functionality:
* `display_registers`, bound to `--`, will open a horizontal split showing all
  bound registers that do not contain newlines.
* `yank_line_to_register`, bound to `- `, when executed inside the
  `display_registers` output, will copy the text on that line to the register.

For example, `display_registers` may show something like this:

```
a: echo hi
b: python3 -i
c: make test
```

We can change this to the following:

```
a: echo bye
b: python3 -i
c: make test
```

If we move our cursor to the first line and execute `yank_line_to_register`, or
`- `, this will yank `echo bye` to our `a` register. Then, executing `-a` will
execute `echo bye` in a split.
