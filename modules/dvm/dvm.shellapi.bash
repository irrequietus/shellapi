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
# @desc Retrieve upstream materials for a given bash series (3.0, 3.1, ...)
# @ptip $1  GNU Bash series to build (from .0 to current .x)
# @ptip $2  The path to the directory where all operations take place
#;
function dvm_bashbseq() {
    local bv="$1" p=() l h="$IFS" t v x z=1
    [[ -z $2 ]] && {
        _emsg "${FUNCNAME}: target directory not set"
        return 1
    }
    pushd "$2" &> /dev/null || {
        _emsg "${FUNCNAME}: cannot change to target: $2"
        return 1
    }
    rm -rf bash-${bv}*
    _omsg "get: bash-${bv}.tar.gz"
    wget -q -c http://ftp.gnu.org/gnu/bash/bash-${bv}.tar.gz
    _omsg "got: bash-${bv}.tar.gz"
    mkdir bash-$bv-patches
    pushd bash-$bv-patches &> /dev/null
    while read -r -d\> l; do
        [[  $l =~ \<a[[:space:]]*href[[:space:]]*=[[:space:]]*\"([^\"\<\>]*)\" \
        ||  $l =~ \<a[[:space:]]*href[[:space:]]*=[[:space:]]*\'([^\'\<\>]*)\' ]] \
            &&  case "${BASH_REMATCH[1]}" in
                    bash${bv//./}-???)
                        x="${BASH_REMATCH[1]}"
                        _omsg "get: bash-${bv}.tar.gz"
                        wget -q -c http://ftp.gnu.org/gnu/bash/bash-${bv}-patches/$x
                        _omsg "got: bash-${bv}.tar.gz"
                        IFS="$(printf "\n")"
                        while read -r l; do
                            [[ $l =~ ^\*\*\*[[:space:]]*([\./][^[:space:]]*) ]] && {
                                [[ ${BASH_REMATCH[1]} != ../bash-${bv}/* ]] && {
                                    _split "${BASH_REMATCH[1]}" "/"
                                    case "${#SPLIT_STRING[@]}" in
                                        3)
                                            t="../bash-$bv/${SPLIT_STRING[2]}"
                                            ;;
                                        *)
                                            v="${BASH_REMATCH[1]##*/}"
                                            [[ $v = *bash* ]] && {
                                                    t="${BASH_REMATCH[1]%${v}}"
                                                    t="${t##*bash}"
                                                    t="../bash-$bv/${t#*/}$v"
                                            } || {
                                                    t="${BASH_REMATCH[1]##*bash}"
                                                    t="../bash-$bv/${t#*/}"
                                            }
                                    esac
                                    printf "%s\n" "${l/${BASH_REMATCH[1]}/$t}" >> $x.patch
                                }
                            } || printf "%s\n" "$l" >> $x.patch
                        done < $x
                        IFS="$h"
                        popd &> /dev/null
                        tar zxf bash-${bv}.tar.gz
                        pushd bash-$bv-patches &> /dev/null
                        _omsg "patching: bash-$bv -> bash-$bv.$z"
                        for x in *.patch; do
                            patch -p0 < $x
                        done > /dev/null
                        _omsg "patched : bash-$bv -> bash-$bv.$z"
                        popd &> /dev/null
                        find ./bash-$bv -regextype posix-egrep -regex ".*\.orig|.*~" -exec rm '{}' \;
                        mv bash-$bv bash-$bv.$((z++))
                        pushd bash-$bv-patches &> /dev/null
                        ;;
                esac
    done < <(wget -q -O - http://ftp.gnu.org/gnu/bash/bash-${bv}-patches/)
    popd &> /dev/null
    tar zxf bash-${bv}.tar.gz
    _omsg "creating incremental patches $bv.0 -> $bv.$((z-1))"
    for((x=1;x<z;++x)); do
        {
            printf "notice   : Aggregate of versions %s.0 to %s.%s\n" "$bv" "$bv" "$x"
            printf "origin   : Automatically generated from the official bash patches\n"
            printf "generator: The dvm_bashbseq() shellapi function (http://odreex.org)\n"
            printf "generated: %s\n\n" "$(date -R)"
            diff -Naur bash-$bv bash-$bv.$x
        } > bash-${bv}.$x.patch
    done
    popd &> /dev/null
}

