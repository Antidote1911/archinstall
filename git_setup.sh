#!/usr/bin/env bash

## Setup The Repository

echo "Setting Up Git Repository..."

git init
git config --global user.name "Antidote1911"
git config --global user.email "antidote1911@gmail.com"
sudo git config --system core.editor vim
git config --global credential.helper cache
git config --global credential.helper 'store --file ~/.config/git-credentials'
git config --global push.default simple

echo "Git Repository Setup Complete!"
