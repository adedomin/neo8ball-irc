#!/bin/bash

inotifywait -m /home/mike/uploads -e create -e moved_to |
    while read path action file; do
        echo ":m http://ghetty.space/teleirc_files/$file"
    done
