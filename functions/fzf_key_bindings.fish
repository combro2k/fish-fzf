# Key bindings
# ------------
function fzf_key_bindings

    # Store current token in $dir as root for the 'find' command
    function __fzf_file_widget -d "List files and folders"
        set -l commandline (__fzf_parse_commandline)
        set -l dir $commandline[1]
        set -l fzf_query $commandline[2]

        # "-path \$dir'*/\\.*'" matches hidden files/folders inside $dir but not
        # $dir itself, even if hidden.
        set -q FZF_CTRL_T_COMMAND; or set -l FZF_CTRL_T_COMMAND "
        command find -L \$dir -mindepth 1 \\( -path \$dir'*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' \\) -prune \
        -o -type f -print \
        -o -type d -print \
        -o -type l -print 2> /dev/null | sed 's@^\./@@'"

        set -q FZF_TMUX_HEIGHT; or set FZF_TMUX_HEIGHT 40%
        begin
            set -lx FZF_DEFAULT_OPTS "--height $FZF_TMUX_HEIGHT --reverse $FZF_DEFAULT_OPTS $FZF_CTRL_T_OPTS"
            eval "$FZF_CTRL_T_COMMAND | "(__fzfcmd)' -m --query "\'$fzf_query\'"' | while read -l r; set result $result $r; end
        end
        if [ -z "$result" ]
            commandline -f repaint
            return
        else
            # Remove last token from commandline.
            commandline -t ""
        end
        for i in $result
            commandline -it -- (string escape $i)
            commandline -it -- ' '
        end
        commandline -f repaint
    end

    function __fzf_history_widget -d "Show command history"
        set -q FZF_TMUX_HEIGHT; or set FZF_TMUX_HEIGHT 40%
        begin
            set -lx FZF_DEFAULT_OPTS "--height $FZF_TMUX_HEIGHT $FZF_DEFAULT_OPTS --tiebreak=index --bind=ctrl-r:toggle-sort $FZF_CTRL_R_OPTS +m"

            set -l FISH_MAJOR (echo $version | cut -f1 -d.)
            set -l FISH_MINOR (echo $version | cut -f2 -d.)

            # history's -z flag is needed for multi-line support.
            # history's -z flag was added in fish 2.4.0, so don't use it for versions
            # before 2.4.0.
            if [ "$FISH_MAJOR" -gt 2 -o \( "$FISH_MAJOR" -eq 2 -a "$FISH_MINOR" -ge 4 \) ];
                history merge
                history -z | eval (__fzfcmd) --read0 --print0 -q '\(commandline\)' | read -lz result
                and commandline -- $result
            else
                history merge
                history | eval (__fzfcmd) -q '\(commandline\)' | read -l result
                and commandline -- $result
            end
        end
        commandline -f repaint
    end

    function __fzf_cd_widget -d "Change directory"
        set -l commandline (__fzf_parse_commandline)
        set -l dir $commandline[1]
        set -l fzf_query $commandline[2]

        set -q FZF_ALT_C_COMMAND; or set -l FZF_ALT_C_COMMAND "
        command find -L \$dir -mindepth 1 \\( -path \$dir'*/\\.*' -o -fstype 'sysfs' -o -fstype 'devfs' -o -fstype 'devtmpfs' \\) -prune \
        -o -type d -print 2> /dev/null | sed 's@^\./@@'"
        set -q FZF_TMUX_HEIGHT; or set FZF_TMUX_HEIGHT 40%
        begin
            set -lx FZF_DEFAULT_OPTS "--height $FZF_TMUX_HEIGHT --reverse $FZF_DEFAULT_OPTS $FZF_ALT_C_OPTS"
            eval "$FZF_ALT_C_COMMAND | "(__fzfcmd)' +m --query "\'$fzf_query\'"' | read -l result

            if [ -n "$result" ]
                cd $result

                # Remove last token from commandline.
                commandline -t ""
            end
        end

        commandline -f repaint
    end

    function __fzfcmd
        set -q FZF_TMUX; or set FZF_TMUX 0
        set -q FZF_TMUX_HEIGHT; or set FZF_TMUX_HEIGHT 40%

        if [ $FZF_TMUX -eq 1 ]
            echo "fzf-tmux -d$FZF_TMUX_HEIGHT"
        else
            echo "fzf"
        end
    end

    bind \ct __fzf_file_widget
    bind \cr __fzf_history_widget
    bind \ec __fzf_cd_widget
    bind \t __fzf_complete

    if bind -M insert > /dev/null 2>&1
        bind -M insert \ct __fzf_file_widget
        bind -M insert \cr __fzf_history_widget
        bind -M insert \ec __fzf_cd_widget
        bind -M insert \t __fzf_complete
    end

    function __fzf_parse_commandline -d 'Parse the current command line token and return split of existing filepath and rest of token'
        # eval is used to do shell expansion on paths
        set -l commandline (eval "printf '%s' "(commandline -t))

        if [ -z $commandline ]
            # Default to current directory with no --query
            set dir '.'
            set fzf_query ''
        else
            set dir (__fzf_get_dir $commandline)

            if [ "$dir" = "." -a (string sub -l 1 $commandline) != '.' ]
                # if $dir is "." but commandline is not a relative path, this means no file path found
                set fzf_query $commandline
            else
                # Also remove trailing slash after dir, to "split" input properly
                set fzf_query (string replace -r "^$dir/?" '' "$commandline")
            end
        end

        echo $dir
        echo $fzf_query
    end

    function __fzf_get_dir -d 'Find the longest existing filepath from input string'
        set dir $argv

        # Strip all trailing slashes. Ignore if $dir is root dir (/)
        if [ (string length $dir) -gt 1 ]
            set dir (string replace -r '/*$' '' $dir)
        end

        # Iteratively check if dir exists and strip tail end of path
        while [ ! -d "$dir" ]
            # If path is absolute, this can keep going until ends up at /
            # If path is relative, this can keep going until entire input is consumed, dirname returns "."
            set dir (dirname "$dir")
        end

        echo $dir
    end

    function __fzf_complete -d 'fzf completion and print selection back to commandline'
        set -l cmd (commandline -co) (commandline -ct)
        switch $cmd[1]
            case env sudo
                for i in (seq 2 (count $cmd))
                    switch $cmd[$i]
                        case '-*'
                        case '*=*'
                        case '*'
                            set cmd $cmd[$i..-1]
                            break
                    end
                end
        end
        set -l cmd_lastw $cmd[-1]
        set cmd (string join -- ' ' $cmd)
        set -l initial_query ''
        test -n "$cmd_lastw"; and set initial_query --query="$cmd_lastw"
        set -l complist (complete -C$cmd)
        set -l result
        test -z "$complist"; and return
        set -l compwc (echo $complist | wc -w)
        if test $compwc -eq 1
            set result "$complist"
        else
            set -l query
            string join -- \n $complist \
            | eval (__fzfcmd) (string escape --no-quoted -- $initial_query) --print-query (__fzf_complete_opts) \
            | cut -f1 \
            | while read -l r
                if test -z "$query"
                    set query $r
                else
                    set result $result $r
                end
            end
            if test -z "$query" ;and test -z "$result"
                commandline -f repaint
                return
            end
            if test -z "$result"
                set result $query
            end
        end
        set prefix (string sub -s 1 -l 1 -- (commandline -t))
        for i in (seq (count $result))
            set -l r $result[$i]
            switch $prefix
                case "'"
                    commandline -t -- (string escape -- $r)
                case '"'
                    if string match '*"*' -- $r >/dev/null
                        commandline -t --  (string escape -- $r)
                    else
                        commandline -t -- '"'$r'"'
                    end
                case '~'
                    commandline -t -- (string sub -s 2 (string escape -n -- $r))
                case '*'
                    commandline -t -- $r
            end
            [ $i -lt (count $result) ]; and commandline -i ' '
        end
        commandline -f repaint
    end

    function __fzf_complete_opts_common
        if set -q FZF_DEFAULT_OPTS
            echo $FZF_DEFAULT_OPTS
        end
        echo --cycle --reverse --inline-info
    end

    function __fzf_complete_opts_tab_accepts
        echo --bind tab:accept,btab:cancel
    end

    function __fzf_complete_opts_tab_walks
        echo --bind tab:down,btab:up
    end

    function __fzf_complete_opts_preview
        set -l file (status -f)
        echo --with-nth=1 --preview-window=right:wrap --preview="fish\ '$file'\ __fzf_complete_preview\ '{1}'\ '{2..}'"
    end

    test "$argv[1]" = "__fzf_complete_preview"; and __fzf_complete_preview $argv[2..3]

    function __fzf_complete_opts_0 -d 'basic single selection with tab accept'
        __fzf_complete_opts_common
        echo --no-multi
        __fzf_complete_opts_tab_accepts
    end

    function __fzf_complete_opts_1 -d 'single selection with preview and tab accept'
        __fzf_complete_opts_0
        __fzf_complete_opts_preview
    end

    function __fzf_complete_opts_2 -d 'single selection with preview and tab walks'
        __fzf_complete_opts_1
        __fzf_complete_opts_tab_walks
    end

    function __fzf_complete_opts_3 -d 'multi selection with preview'
        __fzf_complete_opts_common
        echo --multi
        __fzf_complete_opts_preview
    end
    
    function __fzf_complete_opts -d 'fzf options for fish tab completion'
        set -q FZF_COMPLETE; or set -l FZF_COMPLETE 0
        
        switch $FZF_COMPLETE
            case 0
                __fzf_complete_opts_0
            case 1
                __fzf_complete_opts_1
            case 2
                __fzf_complete_opts_2
            case 3
                __fzf_complete_opts_3
            case '*'
                echo $FZF_COMPLETE
        end
        if set -q FZF_COMPLETE_OPTS
            echo $FZF_COMPLETE_OPTS
        end
    end
end
