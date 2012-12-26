#!/bin/bash

# Copyright (C) 2009 - George Makrydakis <irrequietus@gmail.com>

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
    local bv="$1" p l h="$IFS" t v x z=1 o
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
                                o="${BASH_REMATCH[1]}"
                                [[ $o != ../bash-${bv}/* ]] && {
                                    _psplit "$o" "/"
                                    case "${#SPLIT_STRING[@]}" in
                                        3)
                                            t="../bash-$bv/${SPLIT_STRING[2]}"
                                            ;;
                                        *)
                                            v="${o##*/}"
                                            [[ $v = *bash* ]] && {
                                                    t="${o%${v}}"
                                                    t="${t##*bash}"
                                                    t="../bash-$bv/${t#*/}$v"
                                            } || {
                                                    t="${o##*bash}"
                                                    t="../bash-$bv/${t#*/}"
                                            }
                                    esac
                                    printf "%s\n" "${l/$o/$t}" >> $x.patch
                                }
                            } || printf "%s\n" "$l" >> $x.patch
                        done < "$x"
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
    declare -r SHELLAPI_BSTRAPSH=\"\$(pwd)\" SHELLAPI_BSTRAPRN=\"\$p/$y\"
    export SHELLAPI_BSTRAPSH SHELLAPI_BSTRAPRN
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
    pushd \"\$p/$y\" &> /dev/null
    %s \"\$@\"
    p=\$?
    popd &> /dev/null
    exit \$p\n}\n_bstrap \"\$@\"\n__sfx__\n" "$z" > "$x/bstrap.sh"
    {
        local t="$(mktemp -d /tmp/_bstrap_sfx_generate.XXXXXXXXXX)"
        [ "$1" != "$x/$y" ] && {
            pushd "$1" &> /dev/null && \
            cp -ax "." "$t/$y" && \
            pushd "$t" &> /dev/null && \
            tar cjf "$y.sfx.tar.bz2" "$y" && \
            cat "$x/bstrap.sh" "$y.sfx.tar.bz2" > "$x/_bstrap.sfx.$y.sh" && \
            popd &> /dev/null && popd &> /dev/null && l=
        } || return 1
    } && printf "_bstrap.sfx.$y.sh\n"
}

#;
# @desc A function that rewrites other functions by substituting
#       variables found in several expressions within the body
#       of a function within the current function - space of a
#       running bash shell script.
# @ptip $1  function name
# @ptip $2  comma separated list of [name_A]=[name_B] pairs where
#           left side (A) gets substituted by right side(B).
#;
function dvm_genf_var_rewire() {
    local x y z="${2//[[:space:]]/}," w r
    while [[ $z =~ ([^=]*)=([^=]*), ]]; do
       y+=("${BASH_REMATCH[1]} ${BASH_REMATCH[2]}")
       z=${z#*${BASH_REMATCH[2]},}
    done
    while read -r x; do
        r="$x"
        for z in ${!y[@]}; do
            w="${y[$z]/ */}"
            z="${y[$z]/* /}"
            while [[ ${x} =~ \$\{${w}[\#\%\:\{\[\}-] ]]; do
                x="${x//${BASH_REMATCH[0]}/${BASH_REMATCH[0]/$w/$z}}"
                r="$x"
            done
        done
        printf "%s\n" "$r"
    done< <(type "$1" | tail --lines=+2)
}

#;
# @desc Rewrite a function in such a way as to expand the strings involved
#       in it, thus hardcoding it to a particular locale string series
# @ptip $1  function name (function must be already be set within
#           the running script)
# @ptip $2  array variable to use for message expansion
#;
function dvm_genf_hardmsg() {
    (($# == 2)) || _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#"
    _isfunction "$1" && {
        local x y z f="$(mktemp)"
        while read -r x; do
            while [[ ${x} =~ \$\{$2\[(\$[A-Z0-9_-]*)\] ]]; do
                z="$2[$(eval printf "%b" "${BASH_REMATCH[1]}")]"
                y="\${$2\[${BASH_REMATCH[1]}\]\}"
                x="${x//$y/${!z}}"
            done
            printf "%s\n" "$x"
        done< <(type "$1" | tail --lines=+2) > "$f"
        rm -rf "$f"
    } || return 1
}

#;
# @desc Dump all loaded function bodies as referenced by name in SHELLAPI_LFUNC
# @ptip $1  filename where to dump the output
#;
function dvm_genf_fdump_all() {
    local i
    (($# == 1)) && {
        [[ -e $1 ]] && _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_FALRDF]}: $1"
        _isfunction "$1" && {
            for i in ${!SHELLAPI_LFUNC[@]}; do
                type ${SHELLAPI_LFUNC[$i]} | tail --lines=+2
            done > "$1" || _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_FNOWRITE]}: $1"
        } || return 1
    } || _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#"
}
