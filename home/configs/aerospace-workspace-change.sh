#!/bin/bash

target_ws=$(aerospace list-workspaces --monitor mouse --visible)

window_id=$(aerospace list-windows --monitor all --app-bundle-id co.boomvision.boom.macos | grep -i remote | cut -f 1 -d" ")
aerospace move-node-to-workspace --window-id "$window_id" "$target_ws"

window_id=$(aerospace list-windows --monitor all --app-bundle-id com.cockos.LICEcap | cut -f 1 -d" ")
aerospace move-node-to-workspace --window-id "$window_id" "$target_ws"
