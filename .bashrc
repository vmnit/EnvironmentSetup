# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines 
# See bash(1) for more options
HISTCONTROL=ignorespace:erasedups

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=10000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

export N_PREFIX="$HOME/n"; [[ :$PATH: == *":$N_PREFIX/bin:"* ]] || PATH+=":$N_PREFIX/bin"  # Added by n-install (see http://git.io/n-install-repo).

###############################################################
# Functions start from here
###############################################################
function set_prompt
{
    #------------------------------------------------------------------------
    # PROMPT
    #------------------------------------------------------------------------
    # \a     an ASCII bell character (07)
    # \d     the date in "Weekday Month Date" format (e.g., "Tue May 26")
    # \D{format}
    #        the  format is passed to strftime(3) and the result is inserted into the prompt string; an empty format results in
    #        a locale-specific time representation.  The braces are required
    # \e     an ASCII escape character (033)
    # \h     the hostname up to the first '.'
    # \H     the hostname
    # \j     the number of jobs currently managed by the shell
    # \l     the basename of the shell's terminal device name
    # \n     newline
    # \r     carriage return
    # \s     the name of the shell, the basename of $0 (the portion following the final slash)
    # \t     the current time in 24-hour HH:MM:SS format
    # \T     the current time in 12-hour HH:MM:SS format
    # \@     the current time in 12-hour am/pm format
    # \A     the current time in 24-hour HH:MM format
    # \u     the username of the current user
    # \v     the version of bash (e.g., 2.00)
    # \V     the release of bash, version + patch level (e.g., 2.00.0)
    # \w     the current working directory, with $HOME abbreviated with a tilde
    # \W     the basename of the current working directory, with $HOME abbreviated with a tilde
    # \!     the history number of this command
    # \#     the command number of this command
    # \$     if the effective UID is 0, a #, otherwise a $
    # \nnn   the character corresponding to the octal number nnn
    # \\     a backslash
    # \[     begin a sequence of non-printing characters, which could be used to embed a terminal  control  sequence  into  the
    #        prompt
    # \]     end a sequence of non-printing characters

    ## PS1="\u @ \h > "

    ## PS1="\[\e]0;\h:\w\a\]$PS1"
    ## PS2='> '

    ## PS1="\n[ \w ]\n\u@\h $SHLVL \A tty-\l \!> "
    ## PS1="\n[\[\e[01;34m\] \w/ \[\e[0m\]]\n\u@\h $SHLVL \A tty-\l \!> "

    ## PS1="\n[\[\e[01;34m\] \w/ \[\e[0m\]]\n\[\e[01;32m\]\u\[\e[0m\]@\[\e[01;33m\]\h\[\e[0m\] \[\e[01;35m\]\A\[\e[0m\] \[\e[01;31m\]\! > \[\e[0m\]"
    PS1="\n[ \[\e[01;35m\]\A\[\e[0m\] \[\e[01;36m\]tty-\l\[\e[0m\] \[\e[01;34m\]\w/ \[\e[0m\]]\n\[\e[01;32m\]\u\[\e[0m\]@\[\e[01;33m\]\h\[\e[0m\] \[\e[01;31m\]\! > \[\e[0m\]"
    PS2=
}

##############################
# history related cmds
##############################
# Avoid duplicates
export HISTTIMEFORMAT="%h %d %H:%M:%S "
PROMPT_COMMAND='history -a'

shopt -s expand_aliases  

set_prompt
