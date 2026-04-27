#!/bin/bash

window_id=$(aerospace list-windows --monitor all --app-bundle-id co.boomvision.boom.macos | grep -i remote | cut -f 1 -d" ")
target_ws=$(aerospace list-workspaces --monitor mouse --visible)

aerospace move-node-to-workspace --window-id "$window_id" "$target_ws"
aerospace move-node-to-workspace --window-id "$window_id" "$target_ws"
