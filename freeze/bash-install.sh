#!/bin/bash -eu

###
# bash environment install
###

# Make sure only root can run our script
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

source config.sh


function setupBash {
    
    echo "Setting up bash profile"

    rm /home/$USERNAME/.profile > /dev/null
    rm /home/$USERNAME/.bashrc > /dev/null
    
    
    cat << EOF > /home/$USERNAME/.profile
# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "\$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "\$HOME/.bashrc" ]; then
    . "\$HOME/.bashrc"
    fi
fi
EOF

    cat << EOF > /home/$USERNAME/.bashrc
###
# git settings
###
function parse_git_deleted {
 [[ \$(git status 2> /dev/null | grep deleted:) != "" ]] && echo -ne "\033[0;31m-\033[0m"
}

function parse_git_added {
 [[ \$(git status 2> /dev/null | grep "Untracked files:") != "" ]] && echo -ne "\033[0;34m+\033[0m"
}

function parse_git_modified {
 [[ \$(git status 2> /dev/null | grep modified:) != "" ]] && echo -ne "\033[0;33m*\033[0m"
}

function parse_git_dirty {
 # [[ \$(git status 2> /dev/null | tail -n1) != "nothing to commit (working directory clean)" ]] && echo "  "
 echo "\$(parse_git_added)\$(parse_git_modified)\$(parse_git_deleted)"
}

function parse_git_branch {
 git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/ [\1 \$(parse_git_dirty)] /"
}

function eh {
    echo "Commands to take advantage of bash's Emacs Mode:"
    echo "  ctrl-a    Move cursor to beginning of line"
    echo "  ctrl-e    Move cursor to end of line"
    echo "  meta-b    Move cursor back one word"
    echo "  meta-f    Move cursor forward one word"
    echo "  ctrl-w    Cut the last word"
    echo "  ctrl-u    Cut everything before the cursor"
    echo "  ctrl-k    Cut everything after the cursor"
    echo "  ctrl-y    Paste the last thing to be cut"
    echo "  ctrl-_    Undo"
    echo ""
    echo "NOTE: ctrl- = hold control, meta- = hold meta (where meta is usually the alt or escape key)."
    echo ""
}


# If not running interactively, don't do anything
[ -z "\$PS1" ] && return

# History settings
HISTCONTROL=erasedups:ignorespace
export HISTSIZE=10000
export HISTIGNORE="ls:cd:history:kali"
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Load bash aliases if they exist
if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# Load local aliases if they exist
if [ -f ~/.local_bash_aliases ]; then
    source ~/.local_bash_aliases
fi

# Update PATH for local bin
export PATH=~/bin:\$PATH

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "\$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "\$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=\$(cat /etc/debian_chroot)
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# Extra environments
if [ -f ~/.java_environment ]; then
    source ~/.java_environment
fi

# Set Emacs mode in BASH
set -o emacs

export PS1='\[\033]0;\u@\h: \w\007\]\n\[\033[0;36m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$(parse_git_branch)\n\[\e[0;33m\][hist: \!] \\$\[\033[0m\] '

EOF

    cat << EOF > /home/$USERNAME/.bash_aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ls='ls --color=auto'
alias lsd='ls -r --sort=time --color=auto'

alias home='ssh emil@home.emibre.com'

alias emacs='emacs -nw'

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
EOF
    
    # Create bin directory for scripts
    mkdir -p /home/$USERNAME/bin

    # Fix ownership
    chown -R $USERNAME:$USERNAME /home/$USERNAME

    # Fix executables in bin
    #chmod +x /home/$USERNAME/bin/*
     
}

setupBash

echo "bash environment install complete"