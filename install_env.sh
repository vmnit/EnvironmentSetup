#!/bin/bash

set -e

# NVIM
## nvim directory
mkdir -p ~/.config/nvim

### plug.vim
#sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
#### PlugInstall in nvim
#
### coc.vim
#### nodejs for coc.vim
#sudo apt install nodejs
#
#### Package manager for node
#sudo apt install npm
#
#### to solve the issue: Current Node.js version v12.22.9 < 16.18.0
#sudo npm cache clean -f
#sudo npm install -g n
#sudo n stable

# tmux package installation
## plugins directory
mkdir -p ~/.tmux/plugins/
mkdir -p ~/.tmux/resurrect/

## tpm - package manager
if [ ! -d ~/.tmux/plugins/tpm ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
    echo "tpm already cloned at ~/.tmux/plugins/tpm, skipping..."
fi

### other plugins using tpm
#### Prefix + I (in tmux)
#
## add ssh key after launching ssh agent
#source ./add_ssh_key_commands
#
## CMake installation
#sudo snap install cmake --classic


while read f;
do
    if [[ ! $f =~ ^#.*$ && ! -z $f ]];
    then
        if [ -e ~/$f ] && cmp -s "$f" ~/"$f"; then
            echo "Skipping " $f" (already up to date)";
        else
            echo "Copying " $f" to ~/"$f "...";
            mkdir -p "$(dirname ~/$f)";
            cp $f ~/$f;
        fi
    fi
done < files.txt

