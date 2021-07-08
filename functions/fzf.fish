function fzf --description "A command-line fuzzy finder"
  if test ! -x $HOME/bin/fzf
    printf 'Installing fzf into ~/bin/fzf...\n' 1>&2
    curl --silent -fL https://github.com/junegunn/fzf/releases/download/0.27.2/fzf-0.27.2-linux_amd64.tar.gz | tar zx -C ~/bin -- fzf
  end

  eval $HOME/bin/fzf "$argv"
end
