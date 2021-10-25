#!/bin/bash

export PATH=$PATH:~/.local/bin
cp -r $HOME/$PROJECTNAME/dotfiles/* $HOME/.config/
pip install konsave
konsave -i $HOME/$PROJECTNAME/kde.knsv
sleep 1
konsave -a kde
