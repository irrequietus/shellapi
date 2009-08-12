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
# @desc Get seconds since epoch
# @echo seconds since 1970
# @warn GNU date specific.
#;
function _dtfs() {
    printf "%s\n" "$(date +%s)"
}

#;
# @desc Get a date - to - the second string with dot separated
#       substrings for every identifier.
# @echo a date string
#;
function _dtff() {
    printf "%s" "$(date +%d.%m.%Y.%H.%M.%S)"
}

#;
# @desc Convert seconds into mixed number time format
# @ptip $1 seconds to process (integer)
# @echo time in mixed number format
#;
function _dtf_mixed_of() {
    local f s="$1"
    _isint $s && {
        f="$((s/86400)):";  ((s%=86400))
        f="$f$((s/3600)):"; ((s%=3600))
        f="$f$((s/60)):";   ((s%=60))
        printf "%s\n" "$f$s"
    } || _fail "${FUNCNAME}: not an integer: $1"
}

#;
# @desc Convert mixed number time format into seconds
# @ptip $1 mixed number time format string
# @echo time in seconds
#;
function _dtf_seconds_of() {
    [[ $1 =~ ([0-9^:]*):([0-9^:]*):([0-9^:]*):([0-9^:]*) ]] && {
        ((${BASH_REMATCH[2]} > 23)) && \
            _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[2]}"
        ((${BASH_REMATCH[3]} > 59)) && \
            _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[3]}"
        ((${BASH_REMATCH[4]} > 59)) && \
            _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[4]}"
        printf "%d\n" \
        $(( ${BASH_REMATCH[1]}*86400 + \
            ${BASH_REMATCH[2]}*3600 + \
            ${BASH_REMATCH[3]}*60 + \
            ${BASH_REMATCH[4]} ))
    } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOFORMAT]}: $1"
}

#;
# @desc Find the difference between two time instances in mixed number
#       time format and return result in mixed number time format
# @ptip $1  mixed number time format string (lhs)
# @ptip $2  mixed number time format string (rhs)
# @echo time in mixed number time format
#;
function _dtf_mixed_diff() {
    (($# == 2)) && {
        local r
        [[ $1 =~ ([0-9^:]*):([0-9^:]*):([0-9^:]*):([0-9^:]*) ]] && {
            ((${BASH_REMATCH[2]} > 23)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[2]}"
            ((${BASH_REMATCH[3]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[3]}"
            ((${BASH_REMATCH[4]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[4]}"
            r=$(( ${BASH_REMATCH[1]}*86400 + \
                ${BASH_REMATCH[2]}*3600 + \
                ${BASH_REMATCH[3]}*60 + \
                ${BASH_REMATCH[4]} ))
        } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOFORMAT]}: $1"
        [[ $2 =~ ([0-9^:]*):([0-9^:]*):([0-9^:]*):([0-9^:]*) ]] && {
            ((${BASH_REMATCH[2]} > 23)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[2]}"
            ((${BASH_REMATCH[3]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[3]}"
            ((${BASH_REMATCH[4]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[4]}"
            ((r -= ${BASH_REMATCH[1]}*86400 + \
                ${BASH_REMATCH[2]}*3600 + \
                ${BASH_REMATCH[3]}*60 + \
                ${BASH_REMATCH[4]} ))
        } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOFORMAT]}: $2"
        (($r < 0 )) && _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_DT_NEGDIFF]}"
        printf "%s\n" "$r"
    } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#"
}

#;
# @desc Add two different time instances in mixed number time
#       format and return result in mixed number time format
# @ptip $1  mixed number time format string (lhs)
# @ptip $2  mixed number time format string (rhs)
# @echo time in mixed number time format
#;
function _dtf_mixed_plus() {
    (($# == 2)) && {
        local l=0 r=0
        [[ $1 =~ ([0-9^:]*):([0-9^:]*):([0-9^:]*):([0-9^:]*) ]] && {
            ((${BASH_REMATCH[2]} > 23)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[2]}"
            ((${BASH_REMATCH[3]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[3]}"
            ((${BASH_REMATCH[4]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[4]}"
            l=$(( ${BASH_REMATCH[1]}*86400 + \
                ${BASH_REMATCH[2]}*3600 + \
                ${BASH_REMATCH[3]}*60 + \
                ${BASH_REMATCH[4]} ))
        } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOFORMAT]}: $1"
        [[ $2 =~ ([0-9^:]*):([0-9^:]*):([0-9^:]*):([0-9^:]*) ]] && {
            ((${BASH_REMATCH[2]} > 23)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[2]}"
            ((${BASH_REMATCH[3]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[3]}"
            ((${BASH_REMATCH[4]} > 59)) && \
                _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_OUTLIM]}: ${BASH_REMATCH[4]}"
            r=$(( ${BASH_REMATCH[1]}*86400 + \
                ${BASH_REMATCH[2]}*3600 + \
                ${BASH_REMATCH[3]}*60 + \
                ${BASH_REMATCH[4]} ))
        } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOFORMAT]}: $2"
        printf "%s\n" $(_dtf_mixed_of "$((l+r))")
    } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#"
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
function _genf_var_rewire() {
    local x y z="${2//[[:space:]]/}," w r
    while [[ $z =~ ([^=]*)=([^=]*), ]]; do
       y[${#y[@]}]="${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
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
function _genf_hardmsg() {
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
function _genf_fdump_all() {
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

#;
# @desc The standard, silent error accumulator
# @ptip $1  error message to store
#;
function _emsg() {
    SHELLAPI_ERROR[${#SHELLAPI_ERROR[@]}]="$1"
}

#;
# @desc Read input from an XML representation of a bash array / variables
#       and create a function that initializes the datastructures represented
#       there
# @ptip $1  filename with compatible XML layout
# @ptip $2  filename where you want the resulting function to be stored. This
#           is completely optional (stores in temporary when not set)
# @ptip $3  
#;
function _xml2bda() {
    local   _i _n _f _l x u= \
            _c=0 g=() z=0 _p=_ _w= ig= \
            _a="${2:-$(mktemp)}" t1= t2=
    while read -r l; do
        case "$l" in
            \<bashdata\ *)
                [[ $l =~ [[:space:]]*fni[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*fni[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _f="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: fni"
                g=("function $_f() {")
                ;;
            \<var\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _n="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: name"
                [[ $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    u="${BASH_REMATCH[1]}"
                    case "$u" in
                        warn)
                            u="! [[ -z \$$_n ]] && _wmsg \"\${FUNCNAME}: resetting: $_n\" && "
                            ;;
                        ignore)
                            u=
                            ;;
                        fatal)
                            u="! [[ -z \$$_n ]] && _fatal \"\${FUNCNAME}: already set: $_n\" || "
                            ;;
                        *) u=
                            ;;
                    esac
                }
                x=${#g[@]}
                g[${#g[@]}]=" $u$_n=\""
                [[ $l == */\> ]] && {
                    g[$x]="${g[$x]}\""
                    z=0
                } ||  z=1
                ;;
            \</var\>)
                (($x + 1 == ${#g[@]})) \
                    && g[$x]="${g[$x]}\"" \
                    || g[$((${#g[@]}-1))]="${g[$((${#g[@]}-1))]}\""
                z=0
                for x in ${!g[@]}; do
                    printf "%s\n" "${g[$x]}"
                done >> "$_a"
                g=()
                u=
                ;;
            \<array\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _n="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: name"
                [[ $l =~ [[:space:]]*prefixall[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*prefixall[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    _p="_${BASH_REMATCH[1]}_"
                    _n="${BASH_REMATCH[1]}_$_n"
                } || _p=_
                [[ $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    u=${BASH_REMATCH[1]}
                    case "$u" in
                        warn)   _w="_wmsg \"\${FUNCNAME}: already set, resetting"
                                t1="||"
                                t2="&&"
                            ;;
                        ignore) _w=
                            ;;
                        fatal)  _w="_fatal \"\${FUNCNAME}: already set"
                                t1="&&"
                                t2="||"
                            ;;
                        reuse)  _w="_fatal \"\${FUNCNAME}: cannot reuse, because not set"
                                t1="&&"
                                t2="||"
                            ;;
                        *)      _fatal "${FUNCNAME}: value is illegal: ${BASH_REMATCH[1]}"
                                t1="&&"
                                t2="||"
                            ;;
                    esac
                } || {
                    _w="_fatal \"\${FUNCNAME}: already set"
                    t1="&&"
                    t2="||"
                }
                g[${#g[@]}]=" $_n=()"
                ;;
            \<index\> | \<index\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _i="${BASH_REMATCH[1]}" \
                    || _i=
                [[ -z $_i ]] && {
                    g[${#g[@]}]="  $_n[\${#$_n[@]}]=\""
                    z=3
                } || {
                    [[ -z $_w ]] || {
                        [[ $u == reuse ]] \
                            && g[${#g[@]}]=" ! [[ -z \$$_p$_i ]] $t1 {" \
                            || g[${#g[@]}]=" [[ -z \$$_p$_i ]] $t1 {"
                    }
                    [[ $u == reuse ]] \
                        && g[$((x=${#g[@]}))]=" $_n[\$$_p$_i]=\"" \
                        || g[$((x=${#g[@]}))]=" $_n[\$(($_p$_i=\${#$_n[@]}))]=\""
                    [[ $l == */\> ]] && {
                        g[$x]="${g[$x]}\""
                        [[ -z $_w ]] \
                            || g[${#g[@]}]=" } $t2 $_w : $_p$_i\""
                        z=
                    } ||  z=1
                }
                ;;
            \</index\>)
                (($x + 1 == ${#g[@]})) && {
                    g[$x]="${g[$x]}\""
                    [[ -z $_i ]] \
                        || [[ -z $_w ]] \
                        || g[${#g[@]}]=" } $t2 $_w : $_p$_i\""
                } || {
                    g[$((${#g[@]}-1))]="${g[$((${#g[@]}-1))]}\""
                    [[ -z $_i ]] \
                        || [[ -z $_w ]] \
                        || g[${#g[@]}]=" } $t2 $_w : $_p$_i\""
                }
                z=0
                ;;
            \</array\>)
                for x in ${!g[@]}; do
                    printf "%s\n" "${g[$x]}"
                done >> "$_a"
                g=()
                _c=0
                u=
                ;;
            \</bashdata\>)
                u=
                printf "}\n" >> "$_a"
                . "$_a"
                [[ -z $2 ]] && rm -rf "$_a"
                ;;
            \<*)
                _fatal "${FUNCNAME}: unexpected XML element in stream: $l"
                ;;
            *)
                case "$z" in
                    2)  g[${#g[@]}]="$l" ;;
                    1)  g[$x]="${g[$x]}$l"; z=2 ;;
                    3)  z=$((${#g[@]}-1))
                        g[$z]="${g[$z]}$l"
                        z=2
                    ;;
                    4)
                    ;;
                esac
        esac
    done< <(_xmlpnseq "$1")
    [[ -z $2 ]] && rm -rf "$_a" || :
}

#;
# @desc Store a bash array as an XML file
# @ptip $1  bash array to use
# @ptip $2  filename where to store (must exist)
# @ptip $3  alternative name for the array; defaults to $1
#;
function _bda2xml() {
    local a="$1" t="$2" x=0 y=0 z=0
    [[ -e $t ]] || _fatal "${FUNCNAME}: file not found $2"
    {
        printf " <array name=\"%s\">\n" "${3:-$a}" >> "$t"
        for x in $(_xsof "$1"); do
            x="$1[$x]"
            printf "  <index>%s</index>\n" "${!x}" 
        done >> "$t"
        printf " </array>\n" >> $t
    } &> /dev/null \
        || _fatal "${FUNCNAME}: could not write to file: $t"
}

#;
# @desc Dump a bash array from memory to a file
# @ptip $1  bash array to use
# @ptip $2  filename where to store (must exist)
# @ptip $3  alternative name for the array; defaults to $1
#;
function _bda2plain() {
    local a="$1" t="$2" x=0 y=0 z=0
    [[ -e $t ]] || _fatal "${FUNCNAME}: file not found $2"
    {
        printf "%s=(\n" "${3:-$a}" >> $t
        for x in $(_xsof "$a"); do
            x="$1[$x]"
            printf "\"%s\"\n" "${!x//\"/\\\"}"
        done >> $t
        printf ")\n" >> "$t"
    } &> /dev/null \
        || _fatal "${FUNCNAME}: could not write to file: $t"
}

#;
# @desc XML normalizing function: outputs lines in a sequence of tag / non tag
#       data, allowing for parsing by bash functions and subsequent reuse within
#       shellapi. This is the shellapi syscore module version.
# @ptip $1  Valid, well - formed XML file to normalize.
# @note This is one of the variations used at this time, within the shellapi
#       core module; many will follow, based on this one, for shellapi - related
#       tasks.
# @warn Use <,> as &lt; &gt; where applicable. This function is just an aid, it is
#       not meant to be an ultimate solution because there is no need to.
#;
function _xmlpnseq() {
    local li bf cm aw x
    while read -r li; do
        li="$bf$li";
        case "$li" in
            *\<!--*--\>*)
                while [[ $li =~ \<\!--\(.*\)--\> ]]; do
                    li="${li/"${BASH_REMATCH[0]}"/}"
                done
                ;;
            *\<!--*)
                bf="$bf${li/<!--*/}"
                cm=_
                continue
                ;;
            *--\>*)
                cm=
                li="${li/*-->/} "
                ;;
        esac
        [[ -z $aw  ]] && {
            li="${li#"${li%%[! ]*}"}"
            while [[ "$li" =~ \<[^\>]*\> ]]; do
                x=${li%%"${BASH_REMATCH[0]}"*}
                [[ ! -z $x ]] && printf "%s\n" "$x"
                [[ -z $cm ]] && {
                    x="${BASH_REMATCH[0]#"${BASH_REMATCH[0]%%[! ]*}"}"
                    case "$x" in
                        \<\?*) ;;
                        \<!DOCTYPE*) aw=_ ;;
                        \<\!*) ;;
                        '') ;;
                        *) printf "%s\n" "$x" ;;
                    esac
                }
                li="${li#*>}"; 
            done
            bf=
            case "$li" in
                *\<*)   bf="${li#"${li%%[! ]*}"} " ;;
                *\]\>*) aw=; bf="${li#*]>}"   ;;
                '') ;;
                *)      [[ -z $cm$li ]] \
                            || printf "%s\n" "${li#[[:space:]+]}" ;;
            esac
        } || [[ $li = *\]\>* ]] && aw=;
    done < "$1"
}

#;
# @desc Parse a series of XML general entities out of a sequence of DTD
#       general entity statements. Works only with normalized sequences
#       of entities (single line per entity, no comments): to be fixed
# @ptip $1  normalized sequence file
# @note sorted array with (key[[:space:]]value) style entries (associative
#       "emulation" for bash 3.x).
#;
function _xmlgerd() {
    local l g=()
    while read -r l; do
        g[${#g[@]}]="$l"
    done< <(while read -r l; do
            [[  $l =~ \<!ENTITY[[:space:]]*([a-zA-Z0-9\-]*)[[:space:]]*\"([^\"]*)\"[[:space:]]*\> \
            ||  $l =~ \<!ENTITY[[:space:]]*([a-zA-Z0-9\-]*)[[:space:]]*\'([^\']*)\'[[:space:]]*\> \
            ]]  && printf "%s %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        done < "$1" | sort -k1,1 -t\ )
    XML_GE=("${g[@]}")
}

#;
# @desc Expand a general entity
# @ptip $1  entity to look for in the array (key[[:space:]]value)
# @ptip $2  sorted array in which to look for the entity, defaults
#           to XML_GE
#;
function _xmlgeex() {
    local   v="$1" e q="$1" \
            x= r="$1" t="${2:-XML_GE}"
    x=$(_ssbfind "$t" "$1") && {
        v="$t[$x]"
        v="${!v/* /}"
        r="$v"
    } || _fatal "${FUNCNAME}: entity not found!"
    while [[ $v =~ .*\&([^\"\'\&]*)\;.* ]]; do
        e="${BASH_REMATCH[1]}"
        ! [[ $q =~ /$e ]] && {
            x=$(_ssbfind "$t" "$e") && {
                x="$t[$x]"
                r="${r/"&$e;"/${!x#$e *}}"
                v="${v/"&$e;"/${!x#$e *}}"
            } || v="${v/"&$e;"/}"
            q="${q#$e/}"
        } || _fatal "${FUNCNAME}: entity recursion has been detected: $e"
        q="$e/$q"
    done
    printf "%s\n" "$r"
}

#;
# @desc Give an error if a function to be included from a shellapi module
#       is already defined.
# @ptip $1  filename where to read from
#;
function _include_fcheck() {
    local x
    while read -r x; do
        [[ $x =~ ^function(.*)[[:space:]]*\(\)[[:space:]]*\{ ]] && {
            type -t ${BASH_REMATCH[1]} &> /dev/null
            (($?)) && \
                _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_FNSET]}: ${BASH_REMATCH[1]}"
            SHELLAPI_LFUNC[${#SHELLAPI_LFUNC[@]}]="${BASH_REMATCH[1]}"
        }
    done < "$1"
}

#;
# @desc Include a shellapi module by name without requiring full path. This
#       function makes also sure that a module does not get included twice.
# @ptip $1  shellapi module name (excluding extension *.shellapi.bash)
#;
function _include() {
    [[ ${1//[^a-zA-Z0-9]/} != $1 ]] \
        && _fatal "${FUNCNAME}: unsanitized variable: $1"
    [[ -d $SHELLAPI_MODULES_DIR/$1 ]] \
        || _fatal "${FUNCNAME}: does not exist: $1"
    local i="$SHELLAPI_MODULES_DIR/$1/$1.shellapi.bash"
    local l="$SHELLAPI_MODULES_DIR/$1/locales/$1.locale.$SHELLAPI_LOCALE.xml"
    local x="$SHELLAPI_MODULES_DIR/$1/extra/$1.config.xml"
    [[ -e $i ]] && {
        eval "((__LOCK__$1))" && {
            _wmsg "${SHCORE_MSGL[$_SHCORE_ALLRD]}: $1"
            return
        } || {
            SHELLAPI_MODULES[${#SHELLAPI_MODULES[@]}]="$1"
            eval "__LOCK__$1=1"
            [[ -e $l ]] && {
                _xml2bda "$l" # create the locale shell script
                _$1_intl_${SHELLAPI_LOCALE} # call the localizer function
            }
            [[ -e $x ]] && {
                _xml2bda "$x"
                _initglobals_$1
            }
            . "$i"
            _isfunction $1_init && $1_init
            [[ $SHELLAPI_FNOIMP = y ]] && _include_fcheck $i
            _xmsg "${SHCORE_MSGL[$_SHCORE_INCLUDE]}: $1"
            [[ -d ${SHELLAPI_MODULES_DIR}/$1/handlers ]] && {
                local z y x=0
                for z in ${SHELLAPI_MODULES_DIR}/$1/handlers/*.handler.bash; do
                    y="${z##*/$1.}"
                    y="${y%%.*}"
                    _xmsg "{$((x++))} module: $1 <-- handler: $y"
                    . "$z"
                    _${1}_handler_${y}_init
                done
            } || :
        }
    } || _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOINC]}: $1"
}

#;
# @desc Check a hash for a given file and compare it to a known value
# @ptip $1  path of filename to check
# @ptip $2  checksum hash of the file to use for the comparison
#;
function _cfx() {
    (($# != 2)) \
        && _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#" \
        && return 1
    [[ -e $1 ]] && {
        local v=$($SHELLAPI_HASH "$1" 2>&1)
        ((! $?)) && {
            [[ ${v/ */} == $2 ]] \
                || _emsg "${FUNCNAME}: checksum mismatch $1"
        } || _emsg "${FUNCNAME}: $v"
    } || _emsg "file not found: $1"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Shorten long strings before print and add dots if necessary...
# @ptip $1  string to shorten
#;
function _dotstr() {
    local v="${1:0:${SHELLAPI_LDOT-${#1}}}"
    (($SHELLAPI_LDOT < ${#1})) \
        && v="$v..."
    printf "%s\n" "[$v]"
}

#;
# @desc The shellapi core initializer
# @note This function initializes the shellapi core and the various modules 
#       that are marked as active to use within a shellapi script flow. For
#       the time being, there is no reuse of the function cache as generated.
# @warn Do not use in any other occasion but before any other shellapi call
#       is made.
#;
function _init() {
    export LC_ALL=C
    SHCORE_START=$(_dtfs)
    _VERSTR=(alpha beta rc)
    [[ -z $SHELLAPI_HOME ]] \
        && _fatal "${FUNCNAME}: home not set"
    SHELLAPI_MODULES_DIR="${SHELLAPI_HOME}/modules"
    SHELLAPI_LOCALE=${SHELLAPI_LOCALE:-en}
    SHELLAPI_LDOT=${SHELLAPI_LDOT:-10}
    local l="$SHELLAPI_MODULES_DIR/syscore/locales/syscore.locale.$SHELLAPI_LOCALE.xml"
    local f="$SHELLAPI_MODULES_DIR/syscore/extra/syscore.config.xml"
    [[ -e $l ]] \
        || _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOLOCINIT]:-invalid locale}"
    [[ -e $f ]] \
        || _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOGLOBCONF]:-no globals set}"
    [[ -e $SHELLAPI_MODULES_DIR/shellapi.conf ]] \
        || _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOCONFF]:-no config set}: shellapi.conf"
    ((${#SHELLAPI_ERRORS[@]})) && _fatal
    _xml2bda "$l"
    _xml2bda "$f"
    _initglobals_syscore
    _syscore_intl_$SHELLAPI_LOCALE
    _eventdef
    VERSION_OPERATORS=(
        [$(_opsolve "<")]="lt"
        [$(_opsolve ">")]="gt"
        [$(_opsolve ">=")]="gte"
        [$(_opsolve "<=")]="lte"
        [$(_opsolve "!=")]="neq"
        [$(_opsolve "==")]="eqt"
    )
    while read -r l; do
        case "$l" in
            '' | \#*)   ;;
            *)  _include "$l" ;;
        esac
    done < "${SHELLAPI_MODULES_DIR}/shellapi.conf"
    [[ -d ${SHELLAPI_TARGET:=$1} ]] || {
        _wmsg "shellapi runspace >> [$SHELLAPI_TARGET]"
        _setup_layout "$1"
    }
}

#;
# @desc Setup a shellapi runspace layout
# @ptip $1  directory where to setup the layout; must not exist
#;
function _setup_layout() {
    [[ -d $1 ]] && {
        _emsg "${FUNCNAME}: directory exists: $1"
    } || {
        for x in ${!I9KG_DEFS[@]}; do
            mkdir -p "${I9KG_DEFS[$x]}"
        done
        mkdir -p "$POOL_RELAY_CACHE"/{xml,functions}
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc A path guesswork workaround
# @ptip $1  pseudo - or real - path
#;
function _ifnot_jpath() {
    [[ ${1##*/} == ${1} ]] \
        && printf "%s\n" "$2/$1" \
        || printf "%s\n" "$1"
}

#;
# @desc Operator resolution interface
# @note This is a bash 3.x workaround
#;
function _opsolve() {
    case "$1" in
        \>\>)   n=1 ;;
        \>=)    n=2 ;;
        \<=)    n=3 ;;
        \!=)    n=4 ;;
        ==)     n=5 ;;
        \<\<)   n=6 ;;
        \?=)    n=7 ;;
        -\>)    n=8 ;;
        \~\>)   n=9 ;;
        *)      n=0 ;;
    esac
    printf "%d" $n
}

#;
# @desc Define a series of internal event - informing functions
#       to be used by the system.
# @note This function is to be DEPRECATED, in favor of a more generic
#       and highly configurable solution.
#;
function _eventdef() {
    local FORMAT=(
        "printf \"\\\\033[%s%s\\\\033[0m: %%s\\\\n\" \"\$1\";"
        "printf \"%s: %%s\\\\n\" \"\$1\" >> \$SHCORE_MLOG;"
        ) \
    __e=(
        "ckmsg,1;34m,+"
        "eqmsg,1;32m,="
        "imsg,1;36m,i"
        "kmsg,1;30m,c"
        "imsg_start,1;34m,@"
        "imsg_stops,1;34m,="
        "imsg_tstart,1;34m,>"
        "imsg_tstops,1;34m,*"
        "wmsg,1;33m,!"
        "cmsg,1;32m,-"
        "fail,1;35m,x"
        "deco,1;37m,#"
        "nmsg,1;32m,$"
        "xmsg,1;35m,*"
        "lmsg,1;31m,^"
    ) \
    DATE_FORMAT="\$(date +%m:%d:%Y:\(%H.%M.%S\))|" i= \
    f="$(mktemp)"
    for i in ${!__e[@]}; do
        [[ ${__e[$i]} =~ ([^,]*),([^,]*),([^,]*) ]] && {
            printf "_%s() { ${FORMAT[0]}${FORMAT[1]} }\n" \
                "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
                "[${BASH_REMATCH[3]}]" "[$DATE_FORMAT${BASH_REMATCH[3]}]"
        } || _fatal "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOREP]} %s\n" \
                "${__e[$i]}"
    done > "$f"
    . "$f"
    rm -rf "$f"
}

#;
# @desc Get the hash for a particular file, depending on $SHELLAPI_HASH
# @ptip $1  path to file
#;
function _hsof() {
    local v=$($SHELLAPI_HASH "$1")
    printf "%s\n" ${v/ */}
}

#;
# @desc Get the hash of a particular string, depending on $SHELLAPI_HASH
# @ptip $1  string to hash
#;
function _hsos() {
    local x="$(printf "%s" "$1" | $SHELLAPI_HASH -)"
    printf "%s\n" "${x/ */}"
}

#;
# @desc Get array size of a referenced bash array
# @ptip $1  referenced array variable
# @echo array size
#;
function _asof() {
    printf "%s\n" "$(eval printf '${#'"${1}"'[@]}')"
}

#;
# @desc Get array indexes of a referenced bash array
# @ptip $1  referenced array variable
# @echo whitespace separated list of array indexes
#;
function _xsof() {
    local vars="$(eval printf "%b\n" '${!'"${1}"'[@]}')"
    printf "%s\n" "${vars//n/ }"
}

#;
# @desc Find if a variable is an integer
# @ptip $1  bash variable
# @retv 0/1
#;
function _isint() {
    [[ $1 -eq $1 ]] 2>/dev/null 
    return $?
}

#;
# @desc Find if a variable is a string
# @ptip $1  bash variable
# @retv 0/1
#;
function _isstr() {
    ! [[ $1 -eq $1 ]] 2>/dev/null 
    return $?
}

#;
# @desc Check whether a function with a particular name is set
# @ptip $1  name of the function to check for
# @retv 0/1
#;
function _isfunction() {
    [[ $(type -t "$1" 2>&1) = "function" ]] \
        || return 1
}

#;
# @desc Check for availability of a given binary
# @ptip $1 name of the binary to check
# @retv 0/1
#;
function _isavailable() {
    which $1 &> /dev/null \
        || return 1
}

#;
# @desc Transform a string or an array containing newline characters into
#       a new array where each member variable is the result of parsing by \n.
# @ptip $1  name of the array / string global (pass by reference)
# @ptip $2  name of the new array to store the results in (defaults to $1)
# @warn Do not rely on $IFS/$OFS if in need to "reimplement" this function.
#;
function _arraygen_nls() {
    local j a=() b="${2-$1}"
    while read -r j; do
        ! [[ -z $j ]] \
            && a[${#a[@]}]="$j"
    done< <(for j in $(_xsof $1); do
                j="$1[$j]"
                printf "%s\n" "${!j}"
            done)
    eval "$b=(\"\${a[@]}\")"
}

#;
# @desc A fatal exception is raised, complete the error message with a final statement.
# @ptip $1  (optional)  final statement
#;
function _fatal() {
    ((${#SHELLAPI_ERROR[@]} > 0)) && {
        local x
        printf "\033[1;31m[~]\033[0m: ${SHCORE_MSGL[$_SHCORE_FATAL]}:\n"
        for x in ${!SHELLAPI_ERROR[@]};do
            printf "\033[1;34m     {%d} --> \033[0m: %s\n" \
                "$x" \
                "${SHELLAPI_ERROR[$x]}"
        done
    }
    [[ -z $1 ]] \
        || printf "\033[1;31;40m[~]\033[0m: %s\n" "$1"
    exit 1
}

#;
# @desc A fatal exception is raised, complete the error message with a final statement.
# @ptip $1  (optional)  final statement
#;
function _wshow() {
    ((${#SHELLAPI_ERROR[@]} > 0)) && {
        local x
        _wmsg "${SHCORE_MSGL[$_SHCORE_WSHOW]}:"
        for x in ${!SHELLAPI_ERROR[@]};do
            printf "\033[1;34;40m     {%d} --> \033[0m: %s\n" \
                "$x" \
                "${SHELLAPI_ERROR[$x]}"
        done
    }
    [[ -z $1 ]] \
        || _wmsg "$1"
    SHELLAPI_ERROR=()
}

#;
# @desc A sorting algorithm using a function as a comparison predicate
# @ptip $1     comparison predicate (ascending/descending)
# @ptip ${@:2} list of variables to sort
# @devs FIXME: can improve performance in certain scenarios using reference semantics
#              instead of passing by value. Consider non - predicate versions as well.
# @warn not applicable to entries containing whitespace (temporarily)
#;
function _qsx_pred() {
    local l r
    (($# < 3)) && printf "%b\n" ${@:2} || (
        for n in ${@:3}; do
            "$1" "$n" "$2" \
                && r="$r $n" \
                || l="$l $n"
        done
        printf "%b\n" $(_qsx_pred $1 $l) $2 $(_qsx_pred $1 $r) )
}

#;
# @desc Perform a binary search in a sorted array comprised of [[:space:]]
#       separated key,value pairs.
# @ptip $1  array variable upon which to perform the search
# @ptip $2  value to search for
# @echo index where the value was found
#;
function _ssbfind() {
    local   s=$(_asof ${1}) v="${2}" \
            l=0 t=0
    local   h=$s
    while (($l < $h)); do
        t="$1[$((m=$((l+$(($((h-l))/2))))))]"
        t="${!t/ */}"
        [[ ${t} < $v ]] \
            && l=$(($m + 1)) \
            || h=$m
    done
    t="$1[$l]"
    t="${!t/ */}"
    [[ $l < $s && $t = $v ]] \
        || l=-1
    printf "%d\n" $l
    (($l+1)) || return 1
}

#;
# @desc Perform a binary search in a sorted array comprised of [[:space:]]
#       separated key,value pairs. A predicate for greater than (>) comparison
#       must be provided.
# @ptip $1  array variable upon which to perform the search
# @ptip $2  value to search for
# @ptip $3  predicate for greater than (>) comparison
# @echo index where the value was found
#;
function _ssbfind_pred() {
    local   s=$(_asof ${1}) v="${2}" \
            l=0 t=0 p="$3"
    local   h=$s
    while (($l < $h)); do
        t="$1[$((m=$((l+$(($((h-l))/2))))))]"
        $p $v ${!t} \
            && l=$(($m + 1)) \
            || h=$m
    done
    t="$1[$l]"
    [[ $l < $s && ${!t} = $v ]] \
        || l=-1
    printf "%d\n" $l
    (($l+1)) || return 1
}

#;
# @desc Sort a bash array using the sort utility
# @ptip $1 array to sort
# @ptip $2 extra parameters to pass to the sort function
#       works by adding -k1,1 -t\[[:space:]] as default
#;
function _sharray_sort() {
    local   _s="$(eval printf '${#'"${1}"'[@]}')" \
            _l=0 _x=0 t=${2-"-k1,1 -t\ "}
    while read -r _l; do
        eval "${1}"'['"$((_x++))"']="'"${_l}"'"'
    done< <(for _l in $(_xsof $1); do
                _l="$1[$_l]"; printf "%s\n" "${!_l}"
            done | sort $t)
    while (($_x < $_s)); do
        unset ${1}[$((_x++))]
    done
}

#;
# @desc Repeat a certain string for a given amount of times.
# @ptip $1  string to repeat
# @ptip $2  amount of times to repeat, defaults to 1
#;
function _repeat() {
    local x=0 y=${2-1}
    while (($((x++)) < y)); do
        printf "%s\n" "$1"
    done
}

# @desc A default handler for implementation that are not present
#       in public branches but required for functionality
# @ptip $1  function name
function _decoy_this() {
    ! [[ -z $1 ]] \
        && _wmsg "$1: this function is under implementation and the function is reserved" \
        || _emsg "${FUNCNAME}: function name undefined"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc A void function, goes nowhere does nothing
#;
function _void() {
    1>&1
}

#;
# @desc Perform a greater than (>) comparison between two version ids
# @ptip $1  left hand value
# @ptip $2  right hand value
# @retv 0 / 1
#;
function _vers_gt() {
    local a b y x o v=() u t r k=${#_VERSTR[@]} c=() d=()
    for u in 1 2; do
        o=0; t="${!u}"
        for r in ${_VERSTR[@]} ""; do
            [ -z $r  ] && c[$k+$u]=$u || {
                [[ ${t##*.} == *$r* ]] && {
                    d[o]=$((d[o]>$((x=${t##*$r}))?d[o]:x))
                    c[o]="${c[o]} $u"; t="${t/$r/.0.}"; break
                }; ((o++))
            }
        done
        v[$u]="${t//[.-]/ }"
    done
    p=(${!c[@]})
    ((${#c[@]} > 1)) \
        && ((${p[0]} > ${#_VERSTR[@]} ? ((k=0)) : ((k=${p[1]})) ))
    t=0
    for x in ${d[@]}; do
        ((t+=$x))
    done
    a=(${v[1]}) b=(${v[2]})
    x=$((${#a[@]}-${#b[@]}))
    ((x < 0)) \
        && while (($((x++)))); do a[${#a[@]}]=0; done \
        || while (($((x--)))); do b[${#b[@]}]=0; done
    for x in ${!a[@]}; do
        ((${a[$x]} >= ${b[$x]})) && y="1$y"
        ((${a[$x]} > ${b[$x]}))  && break
    done
    (($((k=${c[$k]-0})) == 1))  \
        && ((a[${#a[@]}-1]+=$((++t))))
    ((k == 2)) \
        && ((b[${#b[@]}-1]+=$((++t))))
    ((${a[y=$((((${#y}))?$((${#y}-1)):0))]}>${b[$y]}))
}

#;
# @desc Perform a less than (<) comparison between two version ids
# @ptip $1  left hand value
# @ptip $2  right hand value
# @retv 0/1
#;
function _vers_lt() {
     [[ $1 != $2 ]] \
        && ! _vers_gt "$1" "$2"
}

#;
# @desc Perform a greater than or equal (>=) comparison between two version ids
# @ptip $1  left hand value
# @ptip $2  right hand value
# @retv 0/1
#;
function _vers_gte() {
     [[ $1 == $2 ]] \
        || _vers_gt "$1" "$2"
}

#;
# @desc Perform a less than or equal (>=) comparison between two version ids
# @ptip $1  left hand value
# @ptip $2  right hand value
# @retv 0/1
#;
function _vers_lte() {
     [[ $1 == $2 ]] \
        || ! _vers_gt "$1" "$2"
}
