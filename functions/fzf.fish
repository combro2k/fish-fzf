function fzf --description "A command-line fuzzy finder"
  if test ! -x $HOME/bin/fzf
    printf 'Installing fzf into ~/bin/fzf...\n' 1>&2
    curl --silent -fL https://github.com/junegunn/fzf-bin/releases/download/0.20.0/fzf-0.20.0-linux_amd64.tgz | tar zx -C ~/bin -- fzf
  end

  eval $HOME/bin/fzf "$argv"
end
