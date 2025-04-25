#!/bin/bash

bluetoothctl << EQF
pair  #MAC Adress from controller or other bluetooth device
connect  #same here
EQF

read -p "If you want to disconnect just press Enter..." disconnect

bluetoothctl << EQF
disconnect
EQF
