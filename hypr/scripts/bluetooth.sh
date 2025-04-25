#!/bin/bash

bluetoothctl << EQF
pair 7C:66:EF:4A:1E:0C #MAC Adress from PS5 Controller
connect 7C:66:EF:4A:1E:0C
EQF

read -p "If you want to disconnect just press Enter..." disconnect

bluetoothctl << EQF
disconnect
EQF
