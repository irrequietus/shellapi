#!/bin/bash

# Copyright (C) 2009 - George Makrydakis <george@odreex.org>

# This file is part of shellapi; shellapi is free software: you can
# redistribute it and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation, either
# version 3 (three) of the License, or (at your option) any later
# version.

# shellapi is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with shellapi. If not, see <http://www.gnu.org/licenses/>.


#;
# @desc Initialize the handler by setting the array variable
#       with all sourceforge mirrors keywords.
#;
function _odsel_handler_sforge_init() {
    SFORGE_MSET=(
        "biznetnetworks"
        "dfn"
        "fastbull"
        "freefr"
        "garr"
        "heanet"
        "hivelocity"
        "internap"
        "internode"
        "iweb"
        "jaist"
        "kent"
        "mesh"
        "nchc"
        "ncu"
        "nfsi"
        "ovh"
        "puzzle"
        "softlayer"
        "sunet"
        "superb-east"
        "superb-west"
        "surfnet"
        "switch"
        "transact"
        "ufpr"
        "voxel"
        "waix")
        [[ -z $SFORGE_MR ]] && SFORGE_MR=${SFORGE_MSET[$(($RANDOM%${#SFORGE_MSET[@]}))]} || {
            local x
            for((x=0;x<${#SFORGE_MSET[@]};x++)); do
                [[ ${SFORGE_MR} == ${SFORGE_MSET[$x]} ]] && break
            done
            ((x==${#SFORGE_MSET[@]})) \
                && SFORGE_MR=${SFORGE_MSET[$(($RANDOM%${#SFORGE_MSET[@]}))]} \
                && _wmsg "${FUNCNAME}: SFORGE_MR = $SFORGE_MR"
        }
}

#;
# @desc The default handling event, form a sourceforge download link.
# @ptip $1  a link in the sforge://[address] format.
#;
function _odsel_handler_sforge() {
    printf "%s %s?use_mirror=%s\n" \
        "${POOL_DGET:-"wget -c"}" \
        "${1/sforge:\/\//http://downloads.sourceforge.net/}" \
        "${SFORGE_MR:=${SFORGE_MSET[$(($RANDOM%${#SFORGE_MSET[@]}))]}}"
}

