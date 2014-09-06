" Set a variable to use as an anchor to find the necessary perl module.
let g:PERLMODOP_HOME=expand('<sfile>:p:h:h')

" Tests whether perl can be executed
function! perlmodop#TestExec()
  if has("perl")
    :perl <<EOF
#EOF
      use strict;
      VIM::Msg("Was able to execute via Perl");
EOF
  endif
endfunction


" Finds perl modules on the line where the cursor currently rests,
" and opens them in new tabs to the right of the current tab.
function! perlmodop#OpenPerlSourceFile()
  if has("perl")
    if &filetype == "perl"
      :perl <<EOF
#EOF
        use strict;
        my $vim_utils = VIM::Eval("g:PERLMODOP_HOME") . "/lib";
        return unless(-e $vim_utils);
        unshift(@INC, $vim_utils);
        require ModOp;
        my $vt = ModOp->new(curwin => $main::curwin);
        $vt->openSourceFile();
EOF
    endif
  endif
endfunction


" Finds perl modules on the line where the cursor currently rests,
" loads them into the tagslist, and then opens the tagslist
function! perlmodop#LoadPerlSourceFile()
  if has("perl")
    if &filetype == "perl"
      :perl <<EOF
#EOF
        use strict;
        my $vim_utils = VIM::Eval("g:PERLMODOP_HOME") . "/lib";
        return unless(-e $vim_utils);
        unshift(@INC, $vim_utils);
        require ModOp;
        my $vt = ModOp->new(curwin => $main::curwin);
        $vt->loadSourceFile();
EOF
    endif
  endif
endfunction


" Shows the current @INC.
function! perlmodop#ShowPerlINC()
  if has("perl")
    :perl <<EOF
#EOF
      use strict;
      my $vim_utils = VIM::Eval("g:PERLMODOP_HOME") . "/lib";
      return unless(-e $vim_utils);
      unshift(@INC, $vim_utils);
      require ModOp;
      my $vt = ModOp->new(curwin => $main::curwin);
      my $str = join(', ', $vt->getINC());
      VIM::Msg($str);
EOF
  endif
endfunction
