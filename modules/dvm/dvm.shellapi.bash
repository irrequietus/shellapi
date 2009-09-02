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
# @desc A specialized, developer - oriented bash binaries builder which
#       also installs the resulting binary to a "bashpit" folder
# @ptip $1  directory where the bash source is located
# @ptip $2  full path of where the bashpit is to be created
#;
function dvm_bash_b2pit() {
    local x="$1" t="$2/bashpit"
    mkdir -p "$t/buildlogs"
    _nmsg "* $(_emph $x) is being prepared"
    pushd "$x" > /dev/null
    {
        ./configure --prefix="$t/${x#*-}" && \
        make && \
        make install
    } &> "$t/buildlogs/build.$x.log" || {
        _fail "$(_emph $x) failed -> $t/buildlogs/build.$x.log"
        popd > /dev/null
        return 1
    }
    popd > /dev/null
    _cmsg "* $(_emph $x) was placed into the bashpit"
}

#;
# @desc The serial bash binary builder; give it a series to build and it
#       will happily end up creating all the necessary patches as well
#       as placing the resulting binaries to the "bashpit"
# @ptip $1  The bash series to build (3.0, 3.1, ..., 4.0, ...)
# @ptip $2  The directory where you want all the operations to take place
#;
function dvm_bash_sbuilder() {
    (($# != 2)) && _fatal "${FUNCNAME}: wrong number of arguments: $#"
    dvm_bash_pseq "$1" "$2" keepall && {
        local x
        pushd "$2" &> /dev/null
        for x in bash-$1*; do
            [[ $x != *.tar.* ]] && {
                dvm_bash_b2pit "$x" "$2" \
                    || _emsg "${FUNCNAME}: failed for series: $1"
            }
        done
        popd &> /dev/null
    }
}

#;
# @desc Retrieve upstream materials for a given bash series (3.0, 3.1, ...).
#       Once all the patches have been created, a compressed tarball is created
#       containing all of them.
# @ptip $1  GNU Bash series to build (from .0 to current .x)
# @ptip $2  The path to the directory where all operations take place
# @ptip $3  [keepall|keep|clean] : choose whether to keep everything, only the patches or
#           clean everything from the target directory. Defaults to [keep].
# @devs This technique can be adjusted to serve patch series creation for
#       other packages as well. Possible abstraction target.
#;
function dvm_bash_pseq() {
    local bv="$1" p l h="$IFS" t v x z=1
    [[ $1 =~ ^[3-4]?\.[0-9]? ]] \
        || _fatal "${FUNCNAME}: $bv is an invalid series identifier"
    [[ -z $2 ]] && {
        _emsg "${FUNCNAME}: target directory not set"
        return 1
    }
    pushd "$2" &> /dev/null || {
        _emsg "${FUNCNAME}: cannot change to target: $2"
        return 1
    }
    _omsg "$(_emph bash-$bv.x): creating patch series"
    rm -rf bash-${bv}* bash-patches-$bv
    _omsg "* get: bash-${bv}.tar.gz"
    wget -q -c http://ftp.gnu.org/gnu/bash/bash-${bv}.tar.gz \
        && _omsg "* got: bash-${bv}.tar.gz" \
        || _fatal "${FUNCNAME}: $bv is an invalid series identifier"
    mkdir bash-patches-$bv
    pushd bash-patches-$bv &> /dev/null
    while read -r -d\> l; do
        [[  $l =~ \<a[[:space:]]*href[[:space:]]*=[[:space:]]*\"([^\"\<\>]*)\" \
        ||  $l =~ \<a[[:space:]]*href[[:space:]]*=[[:space:]]*\'([^\'\<\>]*)\' ]] \
            &&  case "${BASH_REMATCH[1]}" in
                    bash${bv//./}-???)
                        x="${BASH_REMATCH[1]}"
                        p="bash-${bv}.$z"
                        _omsg "* get patch: $p"
                        wget -q -c http://ftp.gnu.org/gnu/bash/bash-${bv}-patches/$x
                        _omsg "* got patch: $p"
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
                        pushd bash-patches-$bv &> /dev/null
                        _omsg "* patching: bash-$bv -> $p"
                        for x in *.patch; do
                            patch -p0 < $x
                        done > /dev/null
                        _omsg "* patched : bash-$bv -> $p"
                        popd &> /dev/null
                        find ./bash-$bv -regextype posix-egrep -regex ".*\.orig|.*~" -exec rm '{}' \;
                        mv bash-$bv bash-$bv.$((z++))
                        pushd bash-patches-$bv &> /dev/null
                        ;;
                esac
    done < <(wget -q -O - http://ftp.gnu.org/gnu/bash/bash-${bv}-patches/)
    popd &> /dev/null
    tar zxf bash-${bv}.tar.gz
    _omsg "* creating incremental patches $bv.0 -> $bv.$((z-1))"
    rm -rf bash-patches-$bv/*
    for((x=1;x<z;++x)); do
        {
            printf "notice   : Aggregate of versions %s.0 to %s.%s\n" "$bv" "$bv" "$x"
            printf "origin   : Automatically generated from the official bash patches\n"
            printf "generator: The ${FUNCNAME}() shellapi function (http://odreex.org)\n"
            printf "generated: %s\n\n" "$(date -R)"
            diff -Naur bash-$bv bash-$bv.$x
        } > bash-patches-$bv/bash-${bv}.$x.patch
    done
    tar cjf bash-patches-$bv.$((--x)).tar.bz2 bash-patches-$bv
    z="$(_emph "bash $bv.x")"
    _omsg "$z: patch total: $x -> bash-patches-$bv.$x.tar.bz2"
    _omsg "$z: * $SHELLAPI_HASH -> $(_hsof bash-patches-$bv.$x.tar.bz2)"
    case "${3:-keep}" in
        keep)   rm -rf bash-$bv* bash-patches-$bv.$x ;;
        clean)  rm -rf bash-$bv* bash-patches-$bv*   ;;
        keepall) ;;
        *) _wmsg "${FUNCNAME}: ignoring: $3, reverting to keepall"
    esac
    _omsg "$z housekeeping complete"
    popd &> /dev/null
}

#;
# @desc Create a "self - extracting" bash script.
# @ptip $1  directory from where to include materials
# @ptip $2  (optional) script to run after extraction, must exist in $1
# @ptip $3  (optional) working directory root
# @echo     Name of the sfx created or error encountered
# @retv     0/1
#;
function dvm_sfx_build() {
    local x="${3:-$(pwd)}/__sfx__" y="$RANDOM" z
     ! [[ -z $2 ]] && {
        z="./$2"
        chmod +x "$1/$2"
     }
    mkdir -p "$x/$y" &> /dev/null || {
        printf "%s\n" "${FUNCNAME}: could not create: $x"
        return 1
    }
    printf "#!/bin/bash\n_bstrap() {
    local l m=\"\$(pwd)\" n=0 o=$y p=\"\$(mktemp -d /tmp/_bstrap_sfx.XXXXXXXXXX)\"
    printf \"\\\\033[1;36m[>]\\\\033[0m: extraction in progress\\\\n\"
    while read -r l; do
        [[ \$l = __sfx__ ]] && break;
        ((n++))
    done < \"\$0\"
    [[ \$l = __sfx__ ]] && {
        tail -n+\$((n+2)) \$0 | tar xj -C \"\$p\"
    } &> /dev/null || {
        printf \"\\\\033[1;35m[~]\\\\033[0m: extraction failed\\\\n\"
        exit 1
    }
    printf \"\\\\033[1;36m[+]\\\\033[0m: extraction complete\\\\n\"
    unset _bstrap
    cd \"\$p/$y\"
    %s
    p=\$?
    cd \"\$m\"
    exit \$p\n}\n_bstrap\n__sfx__\n" "$z" > "$x/bstrap.sh"
    {
        pushd "$1" && \
        cp -ax "." "$x/$y" && \
        pushd "$x" && \
        tar cjf "$y.sfx.tar.bz2" "$y" && \
        cat "$x/bstrap.sh" "$y.sfx.tar.bz2" > "$x/_bstrap.sfx.$y.sh" && \
        popd && popd && l=
    }  &> /dev/null \
        && printf "_bstrap.sfx.$y.sh\n"
    [[ -z $l ]]
}
