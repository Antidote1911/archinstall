#!/bin/bash

user_pw="$1"

echo "$1" | sudo -Sv
yes | makepkg -si
