function fzf --description "A command-line fuzzy finder"
  if test ! -x $HOME/bin/fzf
    set -l latest_version (curl -s -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/junegunn/fzf/tags | jq -r '.[0].name')
    set -l kernel_name (uname --kernel-name | tr '[:upper:]' '[:lower:]')
    set -l hardware_platform (uname --hardware-platform | tr '[:upper:]' '[:lower:]')

    if string match --quiet "x86_64" $hardware_platform
      set hardware_platform "amd64"
    end

    set hardware_kernel (string join '_' $kernel_name $hardware_platform)

    printf 'Installing fzf into ~/bin/fzf...\n' 1>&2
    curl --silent -fL "https://github.com/junegunn/fzf/releases/download/$latest_version/fzf-$latest_version-$hardware_kernel.tar.gz" | tar zx -C ~/bin -- fzf
  end

  eval $HOME/bin/fzf "$argv"
end
