#!/bin/bash

# Project: Modifying RAM SPD Data
# Author: Zak Kemble, contact@zakkemble.co.uk
# Copyright: (C) 2016 by Zak Kemble
# Web: http://blog.zakkemble.co.uk/modifying-ram-spd-data/

# EE1004 code is based on ee1004 driver:
# https://github.com/torvalds/linux/blob/master/drivers/misc/eeprom/ee1004.c

# Licence:
# Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)
# http://creativecommons.org/licenses/by-nc-sa/4.0/

set -uf

ADDRESS=0x50 # RAM module address, usually 0x50 - 0x54
BUS=0 # I2C bus number, usually 0
#OUTFILE="dump.spd"
PAGE0_ADDR=0x36
PAGE1_ADDR=0x37

if [ "$1" ]; then
    BUS="$1"
    if [ "$2" ]; then
        ADDRESS="$2"
    fi
fi

echoErr()
{
	echo "$1" 1>&2
}

#cat /dev/null > ${OUTFILE}

get_page() {
    err="$(i2cget -y "$BUS" "$PAGE0_ADDR" 2>&1)"
    rc=$?
    case "$rc" in
        0) echo 0;;
        2) echo 1;;
        *)
            echoErr ""
            echoErr "Error in i2cget when getting current SPD page:"
            echoErr ""
            echoErr "$err"
            echoErr ""
            exit "$rc"
            ;;
    esac
}

set_page() {
    page="$1"
    if [ "$page" -eq 0 ]; then
        addr="$PAGE0_ADDR"
    else
        addr="$PAGE1_ADDR"
    fi
    err="$(i2cset -y "$BUS" "$addr" 0 2>&1)"
    rc=$?
    case "$rc" in
        0) ;;
        *)
            case "$err" in
                *"Write failed"*)
                    echoErr "Ack'ing page selection..."
                    npage="$(get_page)"
                    if [ "$page" -ne "$npage" ]; then
                        echoErr ""
                        echoErr "Error selecting page $page, current page is $npage"
                        echoErr ""
                        exit 1
                    fi
                    ;;
                *)
                    echoErr ""
                    echoErr "Error in i2cset when selecing page $page:"
                    echoErr ""
                    echoErr "$err"
                    echoErr ""
                    exit "$rc"
                    ;;
            esac
            ;;
    esac
}

read_page() {
    data=""
    for DATAADDR in {0..255}
    do
        echo -en "\rReading: ${DATAADDR}/255" >&2
        HEX=$(i2cget -y ${BUS} ${ADDRESS} ${DATAADDR})

        if [ $? -ne 0 ]; then
            echoErr ""
            echoErr "Error"
            echoErr ""
            exit 1
        fi

        data="$data ${HEX}"
    done
    echoErr ""
    echo "$data"
}

echoErr "Reading..."
echoErr "Bus: ${BUS}"
echoErr "Address: ${ADDRESS}"

SPDDATA=""

# Set page 0
PAGE="$(get_page)"
echoErr "Current page: $PAGE"
if [ "$PAGE" -ne 0 ]; then
    echoErr "Selecting page 0"
    set_page 0
fi

SPDDATA="$(read_page)"

echoErr "Selecting page 1"
set_page 1

SPDDATA="$SPDDATA $(read_page)"

## Return to page 0
#echoErr "Selecting page 0"
#set_page 0

echoErr ""
echoErr "Done"
echoErr ""

echo "${SPDDATA}" | xxd -r -p
#echo -n "${SPDDATA}" | xxd -r -p > ${OUTFILE}
