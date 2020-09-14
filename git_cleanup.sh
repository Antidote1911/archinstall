#!/usr/bin/env bash

# Repository cleanup

echo "Cleaning up repository..."

# Backup config & remove git dir
echo "Backing up config & deleting git dir..."
mv .git/config config
rm -rf .git

# Setup git 
echo "Setting up git repository..."
git init
git config --global user.name "Antidote1911"
git config --global user.email "antidote1911@gmail.com"
sudo git config --system core.editor vim
git config --global credential.helper cache
git config --global credential.helper 'cache --timeout=250000'
git config --global push.default simple
echo "Git repository setup complete!"

# Move config to git again & push changes to repository
echo "Moving config to git dir & push changes..."
mv config .git/config
git add --all .
git commit -m "Repository Is Online"
git push origin master --force

echo "Clean up completed."
