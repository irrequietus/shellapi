#!/bin/bash

# Copyright (C) 2009, 2010 - George Makrydakis <george@odreex.org>

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
# @desc The shellapi core initializer
# @note This function initializes the shellapi core and the various modules 
#       that are marked as active to use within a shellapi script flow. For
#       the time being, there is no reuse of the function cache as generated.
# @ptip $1  The name of the profile to load, defaults to [shellapi] or uses
#           the shellapi.defaults if none is offered.
# @warn Do not use in any other occasion but before any other shellapi call
#       is made.
# @warn In bash 4.0.x, the VERSION_OPERATORS=( [$(_opsolve ">")]="" ... ) syntax
#       does not work. One of the alternatives is to pass it down value by value
#       in the usual way instead of =(). GNU Bash 4.1 adopts the 3.x approach
#       but the fix must remain when using shellapi with GNU Bash 4.0.x
#;
function _init() {
    [[ -z $SHELLAPI_HOME ]] \
        && _fatal "${FUNCNAME}: home not set"
    export LC_ALL=C
    readonly    SHCORE_START=$(_dtfs) \
                SHCORE_VERSION="0.x-pre5" \
                _VERSTR=(alpha beta rc)
    SHELLAPI_MODULES_DIR="${SHELLAPI_HOME}/modules"
    SHELLAPI_LOCALE=${SHELLAPI_LOCALE:-en}
    SHELLAPI_TARGET="${SHELLAPI_TARGET:-"$(pwd)/$(_uuidg)"}"
    SHELLAPI_LDOT=${SHELLAPI_LDOT:-10}
    VERSION_OPERATORS=()
    VERSION_OPERATORS[$(_opsolve "<")]="lt"
    VERSION_OPERATORS[$(_opsolve ">")]="gt"
    VERSION_OPERATORS[$(_opsolve ">=")]="gte"
    VERSION_OPERATORS[$(_opsolve "<=")]="lte"
    VERSION_OPERATORS[$(_opsolve "!=")]="neq"
    VERSION_OPERATORS[$(_opsolve "==")]="eqt"
    local l="$SHELLAPI_MODULES_DIR/syscore/locales/syscore.locale.$SHELLAPI_LOCALE.xml"
    local f="$SHELLAPI_MODULES_DIR/syscore/extra/syscore.config.xml"
    [[ -e $l ]] \
        || _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOLOCINIT]:-invalid locale}"
    [[ -e $f ]] \
        || _emsg "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_NOGLOBCONF]:-no globals set}"
    ((${#SHELLAPI_ERROR[@]})) && _fatal
    _xml2bda "$l"
    _xml2bda "$f"
    _initglobals_syscore
    _bashok
    _syscore_intl_$SHELLAPI_LOCALE
    l="${1:-shellapi}"
    [[ -e ${SHELLAPI_MODULES_DIR}/$l.profile ]] && {
        f="${SHELLAPI_MODULES_DIR}/$l.profile"
        l="loading profile: $l"
    } || {
        [[ $l != shellapi ]] && _fatal "${FUNCNAME}: profile does not exist: $1"
        [[ -e ${SHELLAPI_MODULES_DIR}/shellapi.defaults ]] \
            && f="${SHELLAPI_MODULES_DIR}/shellapi.defaults" \
            || _fatal "${FUNCNAME}: shellapi configuration defaults missing"
        l="loading configuration defaults"
    }
    _imsg "$(_emph "shellapi"): $l"
    while read -r l; do
        case "$l" in
            '' | \#*)   ;;
            *)  _include "$l" ;;
        esac
    done < "$f"
    [[ -d ${SHELLAPI_TARGET} ]] || {
        _wmsg "shellapi runspace >> [${SHELLAPI_TARGET##*/}]"
        _setup_layout "${SHELLAPI_TARGET}"
    }
}

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
# @desc The standard, silent error accumulator
# @ptip $1  error message to store
#;
function _emsg() {
    SHELLAPI_ERROR+=("$@")
}

#;
# @desc Read input from an XML representation of a bash array / variables
#       and create a function that initializes the datastructures represented
#       there
# @ptip $1  filename with compatible XML layout
# @ptip $2  filename where you want the resulting function to be stored. This
#           is completely optional (stores in temporary when not set)
#;
function _xml2bda() {
    local   i= n= f= l= x= u= \
            c=0 g=() z=0 p=_ w= \
            a="${2:-$(mktemp)}" t1= t2=
    while read -r l; do
        case "$l" in
            \<bashdata\ *)
                [[ $l =~ [[:space:]]*fni[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*fni[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && f="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: fni"
                g=("function $f() {")
                ;;
            \<var\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && n="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: name"
                [[ $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    u="${BASH_REMATCH[1]}"
                    case "$u" in
                        warn)
                            u="! [[ -z \$$n ]] && _wmsg \"\${FUNCNAME}: resetting: $n\" && "
                            ;;
                        ignore)
                            u=
                            ;;
                        fatal)
                            u="! [[ -z \$$n ]] && _fatal \"\${FUNCNAME}: already set: $n\" || "
                            ;;
                        *) u=
                            ;;
                    esac
                }
                x=${#g[@]}
                g+=(" $u$n=\"")
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
                done >> "$a"
                g=()
                u=
                ;;
            \<array\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && n="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute not found: name"
                [[ $l =~ [[:space:]]*prefixall[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*prefixall[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    p="_${BASH_REMATCH[1]}_"
                    n="${BASH_REMATCH[1]}_$n"
                } || p=_
                [[ $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*check[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    u=${BASH_REMATCH[1]}
                    case "$u" in
                        warn)   w="_wmsg \"\${FUNCNAME}: already set, resetting"
                                t1="||"
                                t2="&&"
                            ;;
                        ignore) w=
                            ;;
                        fatal)  w="_fatal \"\${FUNCNAME}: already set"
                                t1="&&"
                                t2="||"
                            ;;
                        reuse)  w="_fatal \"\${FUNCNAME}: cannot reuse, because not set"
                                t1="&&"
                                t2="||"
                            ;;
                        *)      _fatal "${FUNCNAME}: value is illegal: ${BASH_REMATCH[1]}"
                                t1="&&"
                                t2="||"
                            ;;
                    esac
                } || {
                    w="_fatal \"\${FUNCNAME}: already set"
                    t1="&&"
                    t2="||"
                }
                g+=(" $n=()")
                ;;
            \<index\> | \<index\ *)
                [[ $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                   $l =~ [[:space:]]*name[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && i="${BASH_REMATCH[1]}" \
                    || i=
                [[ -z $i ]] && {
                    g+=("  $n[\${#$n[@]}]=\"")
                    z=3
                } || {
                    [[ -z $w ]] || {
                        [[ $u == reuse ]] \
                            && g+=(" ! [[ -z \$$p$i ]] $t1 {") \
                            || g+=(" [[ -z \$$p$i ]] $t1 {")
                    }
                    [[ $u == reuse ]] \
                        && g[$((x=${#g[@]}))]=" $n[\$$p$i]=\"" \
                        || g[$((x=${#g[@]}))]=" $n[\$(($p$i=\${#$n[@]}))]=\""
                    [[ $l == */\> ]] && {
                        g[$x]="${g[$x]}\""
                        [[ -z $w ]] \
                            || g+=(" } $t2 $w : $p$i\"")
                        z=
                    } ||  z=1
                }
                ;;
            \</index\>)
                (($x + 1 == ${#g[@]})) && {
                    g[$x]="${g[$x]}\""
                    [[ -z $i ]] \
                        || [[ -z $w ]] \
                        || g+=(" } $t2 $w : $p$i\"")
                } || {
                    g[$((${#g[@]}-1))]="${g[$((${#g[@]}-1))]}\""
                    [[ -z $i ]] \
                        || [[ -z $w ]] \
                        || g+=(" } $t2 $w : $p$i\"")
                }
                z=0
                ;;
            \</array\>)
                for x in ${!g[@]}; do
                    printf "%s\n" "${g[$x]}"
                done >> "$a"
                g=()
                c=0
                u=
                ;;
            \</bashdata\>)
                u=
                printf "}\n" >> "$a"
                ;;
            \<*)
                _fatal "${FUNCNAME}: unexpected XML element in stream: $l"
                ;;
            *)
                case "$z" in
                    2)  g+=("$l") ;;
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
    . "$a"
    [[ -z $2 ]] && rm -rf "$a" || :
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
# @desc XML "primers" for use where necessary.
#;
function __xmlapi_init() {
    SHELLAPI_XMLGDF=(
        '^[[:space:]]+([[:alnum:]_-]+)[[:space:]]+"([^"]*)"[[:space:]]*>'
        "^[[:space:]]+([[:alnum:]_-]+)[[:space:]]+'([^']*)'[[:space:]]*>"
        '^[[:space:]]+%[[:space:]]+([[:alnum:]_-]+)[[:space:]]+(SYSTEM|PUBLIC)[[:space:]]+"([^"]*)"[[:space:]]*>'
        "^[[:space:]]+%[[:space:]]+([[:alnum:]_-]+)[[:space:]]+(SYSTEM|PUBLIC)[[:space:]]+'([^']*)'[[:space:]]*>"
        "^[[:space:]]+([[:alnum:]_-]+)[[:space:]]+["
        '^[[:space:]]+([[:alnum:]_-]+)[[:space:]]+(SYSTEM|PUBLIC)[[:space:]]+"([^"]*)"[[:space:]]+\['
        "^[[:space:]]+([[:alnum:]_-]+)[[:space:]]+(SYSTEM|PUBLIC)[[:space:]]+'([^']*)'[[:space:]]+\[" )
}

#;
# @desc XML DTD expression parser
# @ptip $1  ...[internally passed, do not call directly]
#;
function __xmlapi_preseq() {
    local y= v= s= k= dkt=0 f="$1" x= m=
    SHELLAPI_XML_SGE=() SHELLAPI_XML_MGE=()
    SHELLAPI_XML_SPE=() SHELLAPI_XML_MPE=()
    while [[ $f =~ ^[[:space:]]*(\<!--|\<![A-Z]*|%[[:alnum:]_\-]+\;) ]]; do
        case ${BASH_REMATCH[1]} in
            %*\;)
                m=${BASH_REMATCH[1]#?}
                _xmlapi_entq "${m%?}" "%" SHELLAPI_XML_SPE SHELLAPI_XML_MPE MYVAR && {
                    f="${f/"%${m%?};"/${MYVAR}}"
                } || { _emsg "${FUNCNAME}: DTD failure..."; return 1; }
            ;;
            \<!DOCTYPE)
                ((dkd)) && { _emsg "${FUNCNAME}(): $(_emph doctype) : is corrupt"; return 1; } || {
                    f="${f#*E}"
                    [[  $f =~ ${SHELLAPI_XMLGDF[4]} \
                    ||  $f =~ ${SHELLAPI_XMLGDF[5]} \
                    ||  $f =~ ${SHELLAPI_XMLGDF[6]} ]] && {
                        ((${#BASH_REMATCH[@]} == 2)) \
                            && { f="${f#*[}"; dkt=1; } \
                            || { f="${f#*${BASH_REMATCH[3]}?*[}"; dkt=1; }
                    }
                }
                ;;
            \<!ENTITY)
                f="${f#*Y}"
                [[  $f =~ ${SHELLAPI_XMLGDF[0]} \
                ||  $f =~ ${SHELLAPI_XMLGDF[1]} \
                ||  $f =~ ${SHELLAPI_XMLGDF[2]} \
                ||  $f =~ ${SHELLAPI_XMLGDF[3]} ]] && {
                    ((${#BASH_REMATCH[@]} == 3)) && {
                        m="${#SHELLAPI_XML_SGE[@]}"
                        SHELLAPI_XML_SGE+=("${BASH_REMATCH[2]}")
                        SHELLAPI_XML_MGE+=("${BASH_REMATCH[1]} $m")
                        f="${f#*${BASH_REMATCH[2]}*>}"
                    } || {
                        s="${BASH_REMATCH[1]}"; x="${BASH_REMATCH[3]}"; f="${f#*$x*>}"
                        [[ ${BASH_REMATCH[2]} == SYSTEM ]] && {
                            m="$(_pathget "$(pwd)" "$x")" && {
                                m="$(< "$m")"
                                while [[ $m =~ \<!-- ]]; do y+="${m/\<!--*/}"; m="${m#*-->}"; done
                                m="${y#*\?>}$m"; y="${#SHELLAPI_XML_SPE[@]}"
                                SHELLAPI_XML_SPE+=("$m"); SHELLAPI_XML_MPE+=("$s $y")
                                _sharray_sort SHELLAPI_XML_MPE SHELLAPI_XML_MPE
                            }
                        } || _omsg "${FUNCNAME}(): valid, but not supported yet."
                    }
                }
            ;;
            \<!--)
                f="${f#*-->}"
            ;;
            \<!NOTATION|\<!ELEMENT|\<!ATTLIST)
                f="${f#*>}" # FIXME: ...
            ;;
        esac
    done
    [[ $f =~ ^[[:space:]]*\][[:space:]]*\> ]] && {
        _sharray_sort SHELLAPI_XML_MGE SHELLAPI_XML_MGE
        f="${f#*>}"
        __XMLDTD_TERM__=$((${#1}-${#f}))
    } || {
        _emsg "${FUNCNAME}(): $(_emph doctype) : is corrupt"
        return 1 
    }
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
    local l= b= c= a= x=
    while read -r l; do
        l="$b$l";
        case "$l" in
            *\<!--*--\>*)
                while [[ $l =~ \<\!--\(.*\)--\> ]]; do
                    l="${l/"${BASH_REMATCH[0]}"/}"
                done
                ;;
            *\<!--*)
                b="$b${l/<!--*/}"
                c=_
                continue
                ;;
            *--\>*)
                c=
                l="${l/*-->/} "
                ;;
        esac
        [[ -z $a  ]] && {
            l="${l#"${l%%[! ]*}"}"
            while [[ "$l" =~ \<[^\>]*\> ]]; do
                x="${l%%"${BASH_REMATCH[0]}"*}"
                [[ ! -z $x ]] && printf "%s\n" "$x"
                [[ -z $c ]] && {
                    x="${BASH_REMATCH[0]#"${BASH_REMATCH[0]%%[! ]*}"}"
                    case "$x" in
                        \<\?*) ;;
                        \<!DOCTYPE*) a=_ ;;
                        \<\!*) ;;
                        '') ;;
                        *) printf "%s\n" "$x" ;;
                    esac
                }
                l="${l#*>}"; 
            done
            b=
            case "$l" in
                *\<*)   b="${l#"${l%%[! ]*}"} " ;;
                *\]\>*) a=; b="${l#*]>}"   ;;
                '') ;;
                *)      [[ -z $c$l ]] \
                            || printf "%s\n" "${l#[[:space:]+]}" ;;
            esac
        } || [[ $l = *\]\>* ]] && a=;
    done < "$1"
}

#;
# @desc Process a valid XML document including certain of the elements in the DTD
#       like entities (general, parameter) and on request file loading for them.
# @ptip $1  Absolute, full path to file. This _must_ be a valid XML document.
# @ptip $2  Expand entities or not (0/1)
# @note This function is used as a duo with __xmlapi_preseq(), eventually it will
#       deprecate _xmlpnseq() which has been used since the initial commit. Results
#       are stored to a series of global arrays.
#;
function __xmlapi_aftseq() {
    __xmlapi_init
    local f= fn="$1" n= x=() y= v= s= k= \
          dkt=0 dkd=0 x= q="${2:-0}"
    [[ -e $fn ]] && f="$(< "$1")" \
        || { _emsg "${FUNCNAME}(): file not valid: $1"; return 1; }
    while [[ $f =~ ^[[:space:]]*(\<[[:alnum:]_:-]*|\</[[:alnum:]]*|\<![A-Z]*|\<!--|[^\<]*) ]]; do
        case "${BASH_REMATCH[1]}" in
            \<!--) f="${f#*-->}" ;;
            \</*)  XML_AFTSEQ+=("${f/>*/}>"); f="${f#*>}" ;;
            \<[a-zA-Z]*)
                n="${BASH_REMATCH[1]} "
                f="${f#*${BASH_REMATCH[1]}}"
                while [[ $f =~ ^[[:space:]]+([[:alnum:]]*)[[:space:]]*=[[:space:]]*([\"\']) ]]; do
                    f="${f#*${BASH_REMATCH[2]}}"; x="${f/${BASH_REMATCH[2]}*/}"
                    [[ ${x/</} == $x ]] || { _emsg "${FUNCNAME}: spurious < encountered"; return 1; }
                    n+="${BASH_REMATCH[1]}=${BASH_REMATCH[2]}$x${BASH_REMATCH[2]} "
                    f="${f#*${BASH_REMATCH[2]}}"
                done
                [[ $f =~ ^[[:space:]]*(/\>|\>) ]] \
                    && f="${f#*${BASH_REMATCH[1]}}" \
                    || { _emsg " -?- "; return 1; }
                XML_AFTSEQ+=("${n%?}${BASH_REMATCH[1]}")
                ;;
            \<!DOCTYPE)
                ((dkd)) \
                    && { _emsg "${FUNCNAME}(): $(_emph doctype) : is corrupt"; return 1; } \
                    || { __xmlapi_preseq "$f" || return 1; dkd=1; f="${f:$__XMLDTD_TERM__}"; }
                ;;
            \<*)
                _emsg "${FUNCNAME}: illegal instruction: ${BASH_REMATCH[1]} ..."
                return 1
                ;;
            '') return ;;
            *)
                x="${BASH_REMATCH[1]%${BASH_REMATCH[1]##*[![:space:]]}}"
                [[ -z $x ]] || {
                    (($q)) && {
                        XML_AFTSEQ+=("$(_xmlapi_eex "$x")") || {
                            printf "%s\n" "${XML_AFTSEQ[${#XML_AFTSEQ[@]}-1]}"
                            _emsg "${FUNCNAME}: xml entity was not found"
                            return 1
                        }
                    } || XML_AFTSEQ+=("$x")
                }
                f="${f#*${BASH_REMATCH[1]}}"
            ;;
        esac
    done
}

#;
# @desc JSON normalizing function: stores processed json into a bash array
#       with particular semantics. While operational, this is very experimental.
# @ptip $1  A bash string containing valid json.
# @ptip $2  A variable where the normalized transform is to be stored.
# @devs A practical usage example:
#
# $ [ ... you have initialized shellapi ... ]
# _jsonpnseq "$(< "path/to/yourfile.json")" \
#       && _omsg "$(_emph "json"): parsed successfully" || _fatal
# _for_each SPNSEQ_JSON echo
#
#;
function _jsonpnseq() {
    local x="$1" c= _j=("") n= s=
    while [[ $x =~ ^[[:space:]]*([\]\",\}\{:\[0-9\+\-]|null|true|false) ]]; do
        c="${BASH_REMATCH[1]}"
        case "$c" in
            \")
                x="${x#*$c}"; s=
                while [[ $x =~ ^([^\\\"]*)([\"\\]) ]]; do
                    n=$((${#BASH_REMATCH[1]}+1))
                    [[ ${BASH_REMATCH[2]} == \" ]] && {
                        s+="${BASH_REMATCH[1]}"
                        break
                    } || {
                        [[ ${x:$n:1}  == \" ]] && ((n++))
                        s+="${x:0:$n}"
                    }
                    x="${x:$n}"
                done
                _j+=("$s")
                ;;
             \{|\}|:|\[|\]|,)
                _j[0]+="$c"
                ;;
             null|true|false)
                x="${x#${BASH_REMATCH[1]}}"
                ;;
             [0-9\+\-])
                [[ $x =~ ^[[:space:]]*([0-9eE\+\.]*) ]] && {
                    x="${x#*${BASH_REMATCH[1]}}"
                } || {
                    _emsg "$(_emph "json"): invalid json"
                    return 1
                }
                ;;
             *) _emsg "$(_emph "json"): invalid json"
                return 1
                ;;
        esac
        x="${x#*$c}"
    done
    [[ $x =~ [^[:space:]] ]] && {
        _emsg "$(_emph "json"): invalid json"
        return 1
    } || eval "${2:-SPNSEQ_JSON}=(\"\${_j[@]}\")"
}

#;
# @desc XML entity query interface; bimodal call convention compatible $() / &&
# @ptip $1  Entity to query for
# @ptip $2  Type identifier (& | %)
# @ptip $3  Entity storage array
# @ptip $4  Entity metaindex array
# @ptip $5  Variable where to store result
# @echo String with entities resolved / stores to "$5" while caching.
# @retn 0 / 1
#;
function _xmlapi_entq() {
    local   v="$1" e= q="$4" u="$2" \
            x= r="$1" t="$3" i=0 f="$5"
    i=$(_sharray_find $q $v) && {
        v="$q[$i]"; v="${!v#* }"; v="$t[$v]"; v="${!v}"; r="$v" 
    } || { _emsg "${FUNCNAME}: $1 : not found!"; return 1; }
    while [[ $v =~ $u([[:alnum:]_-]*)\; ]]; do
        e="${BASH_REMATCH[1]}"
        [[ $e == $1 ]] && {
            _emsg "${FUNCNAME}(): $(_emph entity): $e is recursive!"
            return 1
        }
        x=$(_sharray_find $q $e) && {
            x="$q[$x]"; x="${!x#* }"; x="$t[$x]"
            r="${r/"$u$e;"/${!x}}"; v="${v/"$u$e;"/${!x}}"
        } || {
            ((__XMLAPI_ALLOW_NDE__)) && v="${v/"$u$e;"/}" || {
                _emsg "${FUNCNAME}(): $(_emph entity): $e was not found!" \
                      "${FUNCNAME}(): $(_emph entity): $e requested by: $1"
                return 1
            }
        }
    done
    ! [[ -z $f ]] && {
        x="$q[$i]"; x="$t[${!x#* }]"
        eval "$f=\"\$r\";$x=\"\$r\""
    } || printf "%s\n" "$r"
}

#;
# @desc Creates cached, fully expanded general XML entities
# @ptip $1  Entity storage array
# @ptip $2  Entity metaindex array
# @retn 0 / 1
#;
function __xmlapi_entfprep() {
    local __x= __y=$1 __z=$2 __e=
    local __XMLAPI_ALLOW_NDE__=1
    for __x in $(_xsof $__z); do
        __x="$__z[$__x]"
        _xmlapi_entq "${!__x/ */}" \& $__y $__z __e || {
            _emsg "${FUNCNAME}(): could not cache correctly"
            return 1
        }
    done
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
    local l= g=()
    while read -r l; do
        g+=("$l")
    done< <(while read -r l; do
            [[  $l =~ \<!ENTITY[[:space:]]*([a-zA-Z0-9\-]*)[[:space:]]*\"([^\"]*)\"[[:space:]]*\> \
            ||  $l =~ \<!ENTITY[[:space:]]*([a-zA-Z0-9\-]*)[[:space:]]*\'([^\']*)\'[[:space:]]*\> \
            ]]  && printf "%s %s\n" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        done < "$1" | sort -k1,1 -t\ )
    XML_GE=("${g[@]}")
}

#;
# @desc A general entity resolution wrapper for XML input
# @ptip $1  String containing entities to resolve
# @ptip $2  Type identifier (& | %)
# @ptip $3  Entity storage array
# @ptip $4  Entity metaindex array
# @echo String with entities resolved
# @retn 0 / 1
#;
function _xmlapi_eex() {
    local x="$1" y= z=$3 o=$4 __e=
    while [[ $x =~ $2([[:alnum:]\-]*)\; ]]; do
        y=${BASH_REMATCH[1]}
        _xmlapi_entq "${BASH_REMATCH[1]}" "$2" $z $o __e \
            && x="${x//&$y;/$MYVAR}" \
            || { return 1; }
    done
    printf "%s\n" "$x"
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
            SHELLAPI_LFUNC+=("${BASH_REMATCH[1]}")
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
            SHELLAPI_MODULES+=("$1")
            eval "__LOCK__$1=1"
            [[ -e $l ]] && {
                _xml2bda "$l"
                _isfunction _$1_intl_$SHELLAPI_LOCALE \
                        && _$1_intl_$SHELLAPI_LOCALE
            }
            [[ -e $x ]] && {
                _xml2bda "$x"
                _isfunction _initglobals_$1 \
                    && _initglobals_$1
            }
            . "$i"
            _isfunction $1_init && $1_init
            [[ $SHELLAPI_FNOIMP = y ]] && _include_fcheck "$i"
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
# @desc Split string into an array, using a particular character as delimiter
# @ptip $1  string to split
# @ptip $2  optional, character to use as delimiter (defaults to comma)
# @note Stores results to the SPLIT_STRING global array, it is quote/double quote
#       sensitive.
#;
function _qsplit() {
    SPLIT_STRING=()
    local x="$1${2:-,}" y="${2:-,}" z t
    while [[ $x =~ (^[[:space:]]*)([^$y\"\']*)([$y\"\']) ]]; do
        t="${BASH_REMATCH[3]}"
        case "$t" in
            \"|\')
                x="${x#*"$t"}"
                z+="${BASH_REMATCH[2]}$t${x/$t*/}$t"
                ;;
            "$y")
                SPLIT_STRING+=("$z${BASH_REMATCH[2]}")
                z=
                ;;
        esac
        x="${x#*"$t"}"
    done
}

#;
# @desc A simple C - style comment remover
# @ptip Any /* */ enclosed character sequence, provided it is not
#       nested within paired quotes.
# @note Should eventually consider optimizing _qsplit() with it as well.
#;
function _ccrem() {
    local x="$1" l= s= t=
    while [[ $x =~ (/\*|[\'\"]|\*/) ]]; do
        t="${BASH_REMATCH[1]}"
        case "$t" in
            \"|\')
                l="${x#*$t}"
                s+="${x/$t*/}$t${l/$t*/}$t"
                x="${x#*$t*$t}"
                ;;
             /\*)
                x="${x/\/\**/}${x#*\*/}"
                ;;
             \*/)
                _emsg "${FUNCNAME}: stray comment - aborting"
                return 1
                ;;
        esac
    done
    s+="$x"
    printf "%s\n" "$s"
}

#;
# @desc Split string into an array, using a particular character as delimiter
# @ptip $1  string to split
# @ptip $2  optional, character to use as delimiter (defaults to comma)
# @note This is the plain version (does not care about quotes).
#;
function _psplit() {
    local x="${1}" y="${2:-,}"
    x="$x$y"
    SPLIT_STRING=()
    while read -r -d "$y" x; do
        SPLIT_STRING+=("$x")
    done< <(printf "%s\n" "$x")
}

#;
# @desc Retrieve an uuid from /proc/sys/kernel/random/uuid
# @echo An uuid value
#;
function _uuidg() {
    printf "%s\n" "$(< "/proc/sys/kernel/random/uuid")"
}

#;
# @desc Allowing execution only if certain conditions are met
# @warn Because certain VALID constructs have bugs in bash 4.x, a warning was added.
#
#       ALWAYS USE LATEST PATCHES FOR BASH 4.0.x BECAUSE BASH 4.0.x COULD STILL HAVE
#       ISSUES OF ITS OWN IN SIMPLE CONSTRUCTS WHERE 3.2.x DOES ABSOLUTELY FINE.
#
#       The 4.x warning will be waived once 4.x port will commence but until then it
#       is "won't fix" if reporting a bug from 4.0.x without all the latest patches
#       used.
#;
function _bashok() {
    local x=
    ((${BASH_VERSINFO[0]} > 3)) && \
    x="odreex::(shellapi) : Using GNU Bash ${BASH_VERSINFO[0]}.x (3.2.10+ compliant code)" || {
        ((${BASH_VERSINFO[0]} == 3))  && \
        ((${BASH_VERSINFO[1]} >= 2))  && \
        ((${BASH_VERSINFO[2]} >= 10)) || \
            _fatal "odreex::(shellapi) : your GNU bash version is not compatible (< 3.2.10)"
    }
    _eventdef
    _imsg "odreex::(shellapi -> [$SHCORE_VERSION])"
    [[ -z $x ]] || _wmsg "$x"
    case "$(shopt -q compat31 2>&1)" in
        '') (($?)) || _fatal "compat31 is set to on, aborting"
        ;;
        *) _wmsg "for GNU bash: ${BASH_VERSION}: assuming compat31 = off"
        ;;
    esac
}

#;
# @desc A relatively simple stopwatch, returning a whitespace separated
#       list of real|user|sys times.
# @ptip $@  Function / expression to execute.
#;
function _time() {
    local x=($( (time "$@" > /dev/null) 2>&1)) y z
    unset -v x[0] x[2] x[4]
    for x in ${!x[@]}; do
        z=${x[$y]#*m}
        z="${z/.*/}"
        z=$((z+${x[$y]/m*/}*60)).${x[$y]#*.}
        x[$y]=${z%?}
    done
    printf "%s\n" "${x[@]}"
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
# @desc Deduce the absolute path given a relative path and the absolute
#       one it is related to.
# @ptip $1  Absolute path
# @ptip $2  Relative path to $1
# @echo Absolute path of $2
#;
function _pathget() {
    local x="$1" y="$2"
    { [[ -z $y ]] || [[ $y == [[:alnum:]_-]* ]]; } && y="./$y"
    x="$({ cd "$1" && cd "${y%/*}/" && pwd; } 2>/dev/null)/${y##*/}" \
        && [[ -e $x ]] \
        && printf "%s\n" "$x"
}

#;
# @desc Operator resolution interface
# @note This is a bash 3.x workaround, but it is to remain in use
#       for the time being. Despite used within $() n gets initialized
#       as a local before getting proper assignment; matter of guideline.
#;
function _opsolve() {
    local n=
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
        \>)     n=10;;
        \<)     n=11;;
        \?\>)   n=12;;
        \?\?)   n=13;;
        \!\?)   n=14;;
        \!\!)   n=15;;
        \<-)    n=16;;
        \<\>)   n=17;;
        :=)     n=18;;
        ::=)    n=19;;
        =)      n=20;;
        ++)     n=21;;
        --)     n=22;;
        %=)     n=23;;
        %%=)    n=24;;
        \<%-)   n=25;;
        -%\>)   n=26;;
        *)      n=0 ;;
    esac
    printf "%d" $n
}

#;
# @desc Define a series of internal event - informing functions
#       to be used by the system.
#;
function _eventdef() {
    local FORMAT=(
        "printf \"\\\\033[%s%s\\\\033[0m: %%s\\\\n\" \"\$1\";"
        "printf \"%s: %%s\\\\n\" \"\$1\" >> \$SHCORE_MLOG;"
        ) \
    __e=(
        "ckmsg,1;34m,+"
        "eqmsg,1;32m,="
        "omsg,1;36m,O"
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
# @desc         A "for each" for global arrays         
# @ptip $1      The global array we work with
# @ptip ${@:2}  Function to apply
#;
function _for_each() {
    local n
    for n in $(_xsof "$1"); do
        n="$1[$n]"
        "${@:2}" "${!n}"
    done
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
# @desc Apply a [[ -z ]] operation to any global variable
# @ptip $1  Global variable name reference
# @note This is an interesting idiom; it can be used within function bodies
#       for their local variables who by default, cannot be passed to this
#       function.
#;
function _isnullref() {
    [[ -z ${!1} ]]
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
            && a+=("$j")
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
    if ((${#SHELLAPI_ERROR[@]})); then
        local x=
        printf "\033[1;31m[~]\033[0m: ${SHCORE_MSGL[$_SHCORE_FATAL]}:\n"
        for x in ${!SHELLAPI_ERROR[@]};do
            printf "\033[1;34m     {%d} --> \033[0m: %s\n" \
                "$x" \
                "${SHELLAPI_ERROR[$x]}"
        done
        [[ -z $1 ]] \
            || printf "\033[1;31m[~]\033[0m: %s\n" "$1"
    else
        printf "\033[1;31m[~]\033[0m: %s\n" "${1:-...undefined error}"
    fi
    exit 1
}

#;
# @desc A fatal exception is raised, complete the error message with a final statement.
# @ptip $1  (optional)  final statement
#;
function _wshow() {
    ((${#SHELLAPI_ERROR[@]} > 0)) && {
        local x=
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
# @desc A simple message intensifier
# @ptip Argument to intensify in printout
#;
function _emph() {
    printf "\033[1;37m[%s]\033[0m" "$1"
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
    local l= r=
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
# @ptip $1  Array variable upon which to perform the search
# @ptip $2  Value to search for
# @ptip $4  Size correction factor (metaindex / compound)
# @echo index where the value was found
#;
function _sharray_find() {
    local   _s=$(($(_asof ${1})/$((((${3-1}>0))?${3-1}:1))))
    local   _h=$_s _v="$2" _l=0 _t=0 _m=0
    while ((_l < _h)); do
        _t="$1[$((_m=((_l+((((_h-_l))/2))))))]"
        [[ ${!_t/[[:space:]]*/} < $_v ]] && ((_l=_m+1)) || _h=$_m
    done
    { _t="$1[$_l]"; ((_l < _s)) && [[ ${!_t/[[:space:]]*/} = $_v ]]; } || _l=-1
    printf "%d\n" $_l
    ((_l+1)) || return 1
}

#;
# @desc Perform a binary search in a sorted array comprised of [[:space:]]
#       separated key,value pairs. A predicate for greater than (>) comparison
#       must be provided.
# @ptip $1  Array variable upon which to perform the search
# @ptip $2  Value to search for
# @ptip $3  Predicate for greater than (>) comparison
# @ptip $4  Size correction factor (metaindex / compound)
# @echo index where the value was found
#;
function _sharray_find_pred() {
    local   _s=$(($(_asof ${1})/$((((${4-1}>0))?${4-1}:1))))
    local   _h=$_s _v="$2" _l=0 _t=0 _m=0 _p=$3
    while ((_l < _h)); do
        _t="$1[$((_m=((_l+((((_h-_l))/2))))))]"
        $_p "$_v" "${!_t/[[:space:]]*/}" && ((_l=_m+1)) || _h=$_m
    done
    { _t="$1[$_l]"; ((_l < _s)) && [[ ${!_t/[[:space:]]*/} = $_v ]]; } || _l=-1
    printf "%d\n" $_l
    ((_l+1)) || return 1
}

#;
# @desc Sort a bash array using the sort utility
# @ptip $1  Array to sort.
# @ptip $2  Array variable where to store the result.
# @ptip $3  Extra parameters to pass to the sort function
#       works by adding -k1,1 -t\[[:space:]] as default
#;
function _sharray_sort() {
    local   _s= _l=0 _x=0 _y="$2" \
            _t=${3:-"-k1,1 -t\ "} _n=()
    while read -r _l; do
        _n[$((_x++))]="${_l}"
    done< <(for _l in $(_xsof $1); do
                _s="$1[$_l]"; printf "%s\n" "${!_s/ */} $((_x++))"
            done | sort $t)
    eval "$_y=(\"\${_n[@]}\")"
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
# @desc The __*_p() function aliaser
# @ptip $@  A list of __*_p() function prototypes
#;
function _wexp_this() {
    local x=
    for x in $@; do
        _isfunction "__${x}_p" && {
            eval "$x(){ local x=\"\$(_emph \"\${FUNCNAME}()\")\"
                _wmsg \"\$x: *** you are using an experimental feature...\"
                _wmsg \"\$x: *** unexpected behaviour should be expected!\"
                __\${FUNCNAME}_p \"\$@\" ; }"
        } || _emsg "${FUNCNAME}: cannot process because __${x}_p() is not defined"
    done
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
    local a= b= y= x= o= v=() u= t= r= k=${#_VERSTR[@]} c=() d=()
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
        && while (($((x++)))); do a+=(0); done \
        || while (($((x--)))); do b+=(0); done
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
