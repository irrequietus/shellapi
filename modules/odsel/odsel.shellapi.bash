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
# @desc odsel_vsi prototype (to deprecate ununified means)
# @ptip $1  A valid odsel expression
#;
function odsel_vsi() {
    _bsplit "${1}" \; || {
        _emsg "${FUNCNAME}: cannot parse expression"
        return 1
    }
    local x y z
    local g=("${SPLIT_STRING[@]}")
    for x in ${!g[@]}; do
        y="${g[$x]/[[:space:]]*/}"
        z="${g[$x]#"$y"}"
        z="${z//[[:space:]]/}"
        case "$y" in
            new|del|load|delc|newc|sim)
                case "${z:0:1}" in
                    :)
                        _omsg "$(_emph implicit): assuming [$y] is used as i9kg expression prefix (:)"
                        _omsg "$(_emph i9kg): ${g[$x]//[[:space:]]/}"
                        _odsel_i9kg_i "${g[$x]//[[:space:]]/};"
                    ;;
                    '')
                    ;;
                    *)
                        x="${y//[[:space:]]/}"
                        y="odsel_$x"
                        _omsg "$(_emph pool): $(odsel_whatis $x) : $z"
                        $y "$z"
                    ;;
                esac
                ;;
            @*)
                y="${g[$x]//[[:space:]]/}"
                _omsg "$(_emph rpli): $y"
                _odsel_rpli_i "${y:1}"
                ;;
            *://*)
                _odsel_i9kg_i "${g[$x]//[[:space:]]/};"
                ;;
        esac
        ((${#SHELLAPI_ERROR[@]})) && return 1 || :
    done
}

#;
# @desc A practical, odsel group expression expander in bash (component of the future odsel_vsi)
#       for multiple, en block odsel expression interpretation during instruction / metadata
#       navigation in the arrays.
# @ptip $1  odsel block statement to interpret.
# @ptip $2  array to store the block statement sequence, defaults to ODSEL_EXPBLOCK. First
#           element is the hash identifier of the target i9kg file.
#;
function odsel_scli() {
    local   _ft="${2:-ODSEL_EXPBLOCK}" \
            _l="${1//[[:space:]]/}" \
            _c=0 _p= _r= _b=() h=
    _p="$_l"
    _l="${_l/:*/}"
    i9kgoo_load "$_l" || {
        _emsg "${FUNCNAME}: could not load: $_l"
        return 1
    }
    h=($(_odsel_i9kg_header "$_l"))
    h="${h[2]}"
    _l="${_l/\[*[!:]/}:${_p#*:}"
    local   lhs="${_p%[*}" \
            rhs="${_l/*]/}" \
            vhs="${_l#*[}"
    vhs="${vhs%%:*}"
    case "${rhs:1}" in
        install\; | install\(*\)\;)
            odsel_presets_install
            ;;
        remove\; | remove\(*\)\;)
            odsel_presets_remove
            ;;
        code\; | code\(*\)\; | \
        text\; | text\(*\)\;)
            odsel_presets_all
            ;;
        *)
            _fatal "${FUNCNAME}: could not interpret requested block: ${rhs}"
            ;;
    esac
    rhs="${rhs%;}"
    case "$_l" in
        *\[*:\{@*)
            [[ $_l =~ ${ODSEL_REGEXP[0]} ]] \
                && _l="${BASH_REMATCH[1]}," \
                || _fatal "${FUNCNAME}: could not intepret: $_l"
            while [[ $_l =~ ${ODSEL_REGEXP[1]}  ]]; do
                _p="${BASH_REMATCH[1]}"
                case "$_p" in
                    *-\>*)
                        _r="${I9KG_PRESETS[@]}"
                        [[ $_p =~ ${ODSEL_REGEXP[2]} ]] && {
                            _r="${_r#*${BASH_REMATCH[2]/(*/}}"
                            _r="${_r%${BASH_REMATCH[3]/(*/}*}"
                            _b+=("${lhs}[${vhs}@${BASH_REMATCH[1]}:${BASH_REMATCH[2]}]${rhs}")
                            for _c in ${_r}; do
                                 _b+=("${lhs}[${vhs}@${BASH_REMATCH[1]}:$_c]${rhs}") 
                            done
                             _b+=("${lhs}[${vhs}@${BASH_REMATCH[1]}:${BASH_REMATCH[3]}]${rhs}")
                        }
                    ;;
                    *\>*)
                        _fatal "${FUNCNAME}: incorrect syntax"
                    ;;
                    *)
                         _b+=("${lhs}[${vhs}${BASH_REMATCH[1]}]${rhs}")
                    ;;
                esac
                _l=${_l#*"$_p",}
            done
            ;;
        *\[*@*:*)
                [[ $_l =~ ${ODSEL_REGEXP[3]} ]] \
                    &&   _b+=("${lhs}[${BASH_REMATCH[1]}@${BASH_REMATCH[2]}]${rhs}") \
                    || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
        *\[*:*\]*)
                [[ $_l =~ ${ODSEL_REGEXP[4]} ]] \
                    &&  _b+=("${lhs}[${BASH_REMATCH[1]}@stable:${BASH_REMATCH[2]}]${rhs}") \
                    || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
        *\[*\]*)
                [[ $_l =~ ${ODSEL_REGEXP[5]} ]] && {
                    for _c in ${I9KG_PRESETS[@]}; do
                        _b+=("${lhs}[${BASH_REMATCH[1]}@stable:$_c]${rhs}") 
                    done
                } || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
            *)
                _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
    esac
    eval "${_ft}=(\"$h\" \"\${_b[@]}\")"
}

#;
# @desc Load an i9kg XML file describing the various instances of a "package"
#       into an array, complete with the dependency query metadata, build
#       instruction sequences etc. The resulting array is
# @ptip $1  The path to the i9kg XML file to process
# @ptip $2  The array where to store the odsel cache (defaults to ODSEL_XMLA global)
#;
function odsel_xmla() {
    local   v_sn= v_an= v_in= v_iv= x= l= \
            v=0 i=0 p=0 q=0 \
            t=() c=() k=() y=() r=() n=() \
            _A=() _D=() _NB=() _NR=() _DB=() _DR=()
    while read -r l; do
        y+=("$l")
        case "$l" in
            \<code\> | \<text\>)
                v=${#y[@]}
                ;;
            \</code\> | \</text\>)
                q=$((${#y[@]}-1))
                p=${#r[@]}
                [[ $l == \</code\> ]] \
                    && k+=("c$p") \
                    || k+=("t$p")
                x="${y[$v]//\$/\\\$}"
                x="${x//\`/\\\`}"
                r[$p]="${x//\"/\\\"}"
                ((v++))
                for((;v<$q;v++)); do
                    x="${y[$v]//\$/\\\$}"
                    x="${x//\`/\\\`}"
                    r[$p]="${r[$p]}$(printf "\n%s" "${x//\"/\\\"}")"
                done
                ;;
            \<action\ *)
                [[  $l =~ [[:space:]]*mode[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*mode[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_an="${BASH_REMATCH[1]}" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: mode"; return 1; }
                ;;
            \</action\>)
                ((${#k[*]})) && {
                    _A+=("${v_in}[${v_iv}@${v_sn}:${v_an}] ${k[*]}")
                    k=()
                }
                ;;
            \<instance\ *)
                [[  $l =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_iv="${BASH_REMATCH[1]}" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: version"; return 1; }
                [[  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_in="${BASH_REMATCH[1]}" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: alias"; return 1; }
                    n="$n$(printf "\n%s" "$v_in[$v_iv]")"
                ;;
            \<rpli\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _D[$i]="${_D[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
                ;;
            \<dbld\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DB[$i]="${_DB[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
                ;;
            \<drun\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DR[$i]="${_DR[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
                ;;
            \<nbld\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NB[$i]="${_NB[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
                ;;
            \<nrun\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NR[$i]="${_NR[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
                ;;
            \<sequence\ *)
                [[  $l =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_sn="${BASH_REMATCH[1]}" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: variant"; return 1; }
                ;;
            \</instance\>)
                _D[$i]="${_D[$i]:1}"
                _DB[$i]="${_DB[$i]:1}"
                _DR[$i]="${_DR[$i]:1}"
                _NB[$i]="${_NB[$i]:1}"
                _NR[$i]="${_NR[$i]:1}"
                ((i++))
                ;;
            \</sequence\> | \<i9kg\ * | \</i9kg\> | \<materials\> | \</materials\>) ;;
            \<*)
                _emsg "${FUNCNAME}: invalid i9kg XML : $l"
                _emsg "${FUNCNAME}: invalid i9kg file: $1"
                return 1
                ;;
        esac
    done< <(_xmlpnseq "$1")
    y=()
    while read -r l; do
        y+=("$l")
    done< <(for l in ${!_A[@]}; do
                printf "%s\n" "${_A[$l]}"
            done | sort -k1,1 -t\ )
    eval "${2:-ODSEL_XMLA}=( \"\$((\${#y[@]}+1)) \$((\${#r[@]}+\${#y[@]}+1))\"
            \"\${y[@]}\"
            \"\${r[@]}\"
            \"\${n:1}\"
            \"\${_D[@]}\" \"\${_DB[@]}\" \"\${_DR[@]}\" \"\${_NB[@]}\" \"\${_NR[@]}\") "
}

#;
# @desc Read a file with ppli links and preprocess it
# @ptip $1  path to file
#;
function odsel_pppli() {
    local   _pre_l=() \
    _pos_l=() l \
    z=0 \
    _entry= \
    _updt_target= \
    _version= \
    _alias= \
    _idf= _cksum= _hpag= \
    o=0 a=() x= _tagged= k=() q=()
    while read -r l; do
        case "$l" in
            \<pli\ * | \<pli\ */\>)
            [[  $l =~ [[:space:]]*entry[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                $l =~ [[:space:]]*entry[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    _entry="${BASH_REMATCH[1]}"
                    [[ -z $_entry ]] && { _emsg "${FUNCNAME}: $l has an empty entry?"; return 1; }
                    [[  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                        $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                        && _alias="${BASH_REMATCH[1]}"
                    [[  $l =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                        $l =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                        && _version="${BASH_REMATCH[1]}"
                    [[  $l =~ [[:space:]]*sha1sum[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                        $l =~ [[:space:]]*sha1sum[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                        && _cksum="${BASH_REMATCH[1]}"
                    [[  $l =~ [[:space:]]*tagged[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                        $l =~ [[:space:]]*tagged[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                        && _tagged="${BASH_REMATCH[1]}"
                    [[  $l =~ [[:space:]]*idf[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                        $l =~ [[:space:]]*idf[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                        && _idf="${BASH_REMATCH[1]}" \
                        || { _emsg "${FUNCNAME}: attribute not found: idf"; return 1; }
            } || { _emsg "${FUNCNAME}: entry attribute not found in: $l"; return 1; }
            [[ $l = */\> ]] && {
                _version="${_version:+":$_version"}"
                b=${#a[@]}
                a[$((b+$_CHECKSUM))]="$_cksum"
                a[$((b+$_HPAGE))]="$_hpag"
                a[$((b+$_ENTRY))]="$_entry"
                a[$((b+$_PREGET))]=""
                a[$((b+$_POSTGET))]=""
                a[$((b+$_UPDATE))]=""
                case "$_idf" in
                    primary)
                        odsel_ispli_repo "$_entry" \
                            && _version="clone/$_alias$_version|0" \
                            || {
                                _version="pristine/$_alias$_version|0"
                                [[ -z $_tagged ]] \
                                    || _tagged="pristine/$_alias|0"
                               }
                    ;;
                    mirror)
                        odsel_ispli_repo "$_entry" \
                            && _version="clone/$_alias$_version|1" \
                            || _version="pristine/$_alias$_version|1"
                    ;;
                    snapshot)
                        _version="snapshot/$_alias$_version"
                        ;;
                esac
                q+=("$_version $b")
                [[ -z $_tagged ]] || {
                    q+=("$_tagged $b")
                    k+=($b)
                    _tagged=
                }
                _cksum=
                _version=
            } && continue
            ;;
            \<preget\>)   z=${_PREGET} ;;
            \<postget\>)  z=${_POSTGET} ;;
            \<update\ *)
                z=${_UPDATE}
                [[  $l =~ [[:space:]]*target[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                    $l =~ [[:space:]]*target[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _updt_target="${BASH_REMATCH[1]}"
                ;;
            \</update\>)  z=; _updt_l[0]="cd ${updt_target:=.}" ;;
            \</preget\> | \</postget\>) z= ;;
            \</pli\>)   z=z;;
            \<block\ *\>)
                [[  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                    $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _alias="${BASH_REMATCH[1]}"
                [[  $l =~ [[:space:]]*hpage[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                    $l =~ [[:space:]]*hpage[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _hpag="${BASH_REMATCH[1]}"
                ;;
            \</block\>)
                z=zzz
                ;;
            \<rpool\> | \<rpool\ *\>) ;;
            \</rpool\>)
                z=zz
                ;;
            \<*)
                _emsg "${FUNCNAME}: unexpected tag in stream: $l"
                return 1
                ;;
            esac
        case "$z" in
            $_PREGET)  _pre_l+=("$l")   ;;
            $_POSTGET) _post_l+=("$l") ;;
            $_UPDATE)  _updt_l+=("$l") ;;
            z)
                unset _pre_l[0]
                unset _post_l[0]
                _version="${_version:+":$_version"}"
                case "$_idf" in
                    primary)
                        odsel_ispli_repo "$_entry" \
                            && _version="clone/$_alias$_version|0" \
                            || _version="pristine/$_alias$_version|0"
                    ;;
                    mirror)
                        odsel_ispli_repo "$_entry" \
                            && _version="clone/$_alias$_version|1" \
                            || _version="pristine/$_alias$_version|1"
                    ;;
                    snapshot)
                        _version="snapshot/$_alias$_version"
                        ;;
                esac
                b=${#a[@]}
                a[$((b+$_CHECKSUM))]="$_cksum"
                a[$((b+$_HPAGE))]="$_hpag"
                a[$((b+$_ENTRY))]="$_entry"
                l=$((b+$_PREGET))
                for o in ${!_pre_l[@]}; do
                    a[$l]="${a[$l]}$(printf "\n%s" "${_pre_l[$o]}")"
                done
                a[$l]="${a[$l]:1}"
                l=$((b+$_POSTGET))
                for o in ${!_post_l[@]}; do
                    a[$l]="${a[$l]}$(printf "\n%s" "${_post_l[$o]}")"
                done
                a[$((b+$_UPDATE))]=""
                a[$l]="${a[$l]:1}"
                _pre_l=()
                _post_l=()
                q+=("$_version $b")
            ;;
            zz)
                break;
            ;;
        esac
    done< <(_xmlpnseq "$1")
    z=0
    while read -r x; do
        q[$((z++))]="$x"
    done< <(for x in ${!q[@]}; do
                printf "%s\n" "${q[$x]}"
            done | sort -k1,1 -t\|)
    k="${k[@]}"
    eval "${2:-QPOOL_RLA}=(\"\$k\" \"\${q[@]}\" \"\${a[@]}\")"
}

#;
# @desc The odsel rpli instruction decoy
# @ptip $1  The rpli instruction to process, as passed by odsel_vsi
#;
function _odsel_rpli_i() {
    local x= y="$1"
    [[ $y = \{*\}* ]] && {
            x="${y/\}*/}"
            _split "${x:1}"
            x="${SPLIT_STRING[*]}"
            x=${x// /,}
            x="${x//[()]/}"
            y="_${y#*\}}"
    }
    [[  "$y" =~ ([^=\~\>\<\-]*):\((.*)\)([=\~\>\<\-][\>-])([^=\~\>\<\-]*):\((.*)\) || \
        "$y" =~ ([^=\~\>\<\-]*):\((.*)\)([=\~\>\<\-][\>-])([^=\~\>\<\-]*) || \
        "$y" =~ ([^=\~\>\<\-]*)([=\~\>\<\-][\>\<-])([^=\~\>\<\-]*) || \
        "$y" =~ ([^=\~\>\<\-]*):\((.*)\) || \
        "$y" =~ ([^=\~\>\<\-]*) ]] && {
            case "$((${#BASH_REMATCH[@]}-1))" in
                5 | 4)
                    _odsel_${ODSEL_OPRT[$(_opsolve "${BASH_REMATCH[3]}")]} \
                        ${BASH_REMATCH[@]:1:2} "" ${BASH_REMATCH[@]:4:5} "" || {
                        _emsg "${FUNCNAME}: $1 : is not a valid expression"
                        return 1
                    }
                    ;;
                3)
                    _odsel_${ODSEL_OPRT[$(_opsolve "${BASH_REMATCH[2]}")]} \
                        ${x:-${BASH_REMATCH[1]}} "" ${BASH_REMATCH[3]} "" || {
                        _emsg "${FUNCNAME}: $1 : is not a valid expression"
                        return 1
                    }
                    ;;
                2 | 1)
                    _emsg "single block instruction error"
                    return 1
                    ;;
                *) ;;
            esac
    }
}

#;
# @desc The odsel i9kg instruction decoy
# @ptip $1  The i9kg instruction to process, as passed by odsel_vsi
#;
function _odsel_i9kg_i() {
    odsel_scli "${1//[[:space:]]/}" && {
        local x=${ODSEL_EXPBLOCK[0]} y
        unset ODSEL_EXPBLOCK[0]
        for y in ${!ODSEL_EXPBLOCK[@]}; do
            odsel_exprseq "${ODSEL_EXPBLOCK[$y]}" $x || return 1
        done
    }
}

#;
# @desc Check if a pli is a http(s) / ftp link
# @ptip $1  pli metalink
# @retv 0/1
#;
function odsel_ispli_ball() {
    case "${1/:*/}" in
        http | https | ftp) ;;
        *) return 1 ;;
    esac
}

#;
# @desc Check if a pli is actually a repository metalink
# @ptip $1  pli metalink
# @retv 0/1
#;
function odsel_ispli_repo() {
    case "${1/:*/}" in
        git | svn | cvs | hg | bzr) ;;
        *) return 1 ;;
    esac
}

#;
# @desc Transform an ungrouped odsel expression into the sequence of commands
#       or text or whatever it refers to, for the pool it refers to and the
#       i9kg file containing the particular instance it has been mapped for.
# @ptip $1  odsel expression
# @ptip $2  i9kg rcache hash identifier it requires; may deduce it on its own
#           but as always, the rcache array must be already initialized.
#;
function odsel_exprseq() {
    local x="${1//[[:space:]]/}" a r=1 m=0 t=0 z
    [[ -z $2 ]] && {
        [[ "${x/:*/}" =~ ([a-zA-Z0-9_-]*)\[([^[:space:]]*)\] ]] \
                && a=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]:-prime}") \
                || a=("${x/:*/}" "prime")
        a=__i9kg_rcache_$(_hsos "${a[0]}[${a[1]}]")
    } || a="__i9kg_rcache_$2"
    x="${x#*://}"
    case "${z:=${x##*\]:}}" in
        code)   z=t ;;
        text)   z=c ;;
        *)  _emsg "${FUNCNAME}: ${1//[[:space:]]/} is not a valid odsel expression"
            return 1
            ;;
    esac
    x="${x%:*}"
    local b="$a[0]"
    local h="${!b/ */}" v="${!b/ */}"
    local s=$h
    while (($r<$h)); do
        t="$a[$((m=$((r+$(($((h-r))/2))))))]"
        [[ "${!t/ */}" < "$x" ]] && r=$((m+1)) || h=$m
    done
    t="$a[$r]"
    (($r < $s)) && [ "${!t/ */}" == "$x" ] && {
        t=(${!t#* })
        t="${t[@]/$z*/}"
        for x in $t; do
            x="$a[${x#?}+$v]"
            printf "%s\n" "${!x}"
        done
    }
}

#;
# @desc Keyword message definition
# @ptip $1  The odsel keyword for which we want to find the message
#;
function odsel_whatis() {
    local x
    case "$1" in
        new)  x="creating a new pool"   ;;
        del)  x="erasing from poolset"  ;;
        load) x="loading pool"          ;;
        newc) x="caching"               ;;
        delc) x="deleting cache"        ;;
        '')                             ;;
        *)    x="unknown"               ;;
    esac
    printf "%s\n" "$x"
}

#;
# @desc The init implementation for this module
# @warn Same fix as in _init for _opsolve (bash 4.x related)
#;
function odsel_init() {
    POOL_CACHE=()
    POOL_REPORT=()
    POOL_TARGUESS=()
    POOL_BUILDSPACE=()
    POOL_DGET="wget -c"
    ODSEL_XMLA=()
    ODSEL_REGEXP=( ':[{]([^}]*)[}]\]'
                   '([^,]*),'
                   '@([^@]*):([^->]*)->([^->]*)'
                   '\[([^@{}>,-]*)@([^@{}>,-]*)\]'
                   '\[([^@{}>,-]*):([^@{}>,-]*)\]'
                   '\[([^@{}>,:]*)\]' )
    ODSEL_OPRT=()
    ODSEL_OPRT[$(_opsolve "->")]="pm"
    ODSEL_OPRT[$(_opsolve "~>")]="rm"
    ODSEL_OPRT[$(_opsolve "<-")]="lm"
}

#;
# @desc A dependency querying mechanism compatible with an i9kg rcache
#       array. The purpose here is to get a whitespace separated list
#       of dependencies of a specific type: {rpli,dbld,drun,nbld,nrun}.
# @ptip $1  instance expression to query
# @ptip $2  [] enclosed string out of {rpli,dbld,drun,nbld,nrun}
# @ptip $3  hash id of the i9kg rcache (optional)
# @note The i9kg rcache used must be initialized.
#;
function odsel_depquery() {
    local x y q=0 k=0 f=0
    [[ -z $3 ]] && {
        y=($(_odsel_i9kg_header "$1"))
        y=__i9kg_rcache_${y[$_I9KG_RHID]}
    } || y=__i9kg_rcache_$3
    x="$y[0]"
    x="$y[$((q=${!x/* /}))]"
    case "${2:-[rpli]}" in
        \[\] | \[rpli\]);;
        \[dbld\])   f=1 ;;
        \[drun\])   f=2 ;;
        \[nbld\])   f=3 ;;
        \[nrun\])   f=4 ;;
        *)  printf "%s\n" "?= undefined end: $1"
            return 1
        ;;
    esac
    ((q+=$(($(($(_asof $y)-$((++q))))*f/5))))
    for x in ${!x}; do
        [ "$x" == "${1#*//}" ] && {
            x="$y[$((q+k))]"
            printf "%s\n" "${!x}"
            return
        }
        ((k++))
    done
    printf "%s\n" "${FUNCNAME}: undefined error"
    return 1
}

#;
# @desc Calculate the number of entries in a pool rcache array
#       of a particular pool.
# @ptip $1  Name of the pool, required.
# @ptip $2  When set, overrides $1 as __pool_relay_* lock.
# @note The pool must already be included and initialized in runspace,
#       with __pool_relay_* array having valid entries.
#;
function odsel_prc_num() {
    local x="__pool_relay_${2:-$(odsel_gph "${1:-prime}")}[$_RPLI]" y=
    y="${!x}[0]";y=(${!y})
    printf "%d\n" "$(($(_asof ${!x})/7+${#y[@]}+1))"
}

#;
# @desc Retrieve a particular pool item from the pool relay and store
#       the result into the POOL_ITEM global array; the pool relay must
#       be initialized.
# @ptip $1  odsel rpli target to retrieve
# @ptip $2  pool relay hash identifier
#;
function odsel_ifind() {
    local x="$1" a="__pool_relay_${2:-"$(odsel_gph "prime")"}[$_RPLI]"\
        r=1 m=0 t=0 f= o= n=
    a="${!a}"
    f="$a[0]"
    f=(${!f})
    local h="$(($(_asof $a)/7+${#f[@]}+1))"
    local s=$h
    POOL_ITEM=()
    while (($r<$h)); do
        t="$a[$((m=$((r+$(($((h-r))/2))))))]"
        [[ "${!t/|*/}" < "$x" ]] && r=$((m+1)) || h=$m
    done
    t="$a[$r]"
    t="${!t/|*/}"
    (( $r < $s )) && [[ "${t/|*/}" == $x ]] && {
        o=$r
        t="$a[o]"
        n="$a[$((r++))]"
        n="${!n/|*/}"
        if [[ $n == $x ]]; then
            m=("$n")
        else
            m=()
            while [[ ${n%:*} == $x || $n == $x ]]; do
                m+=("${n#*:}")
                n="$a[$((r++))]"
                n="${!n/|*/}"
            done
        fi
        ((${#m[@]} != 1)) && {
            for h in ${m[@]}; do
                _emsg "${FUNCNAME}: non - unique version for $x --> ${h#*/}"
            done
            _emsg "${FUNCNAME}: unique version identifier (uvid) is not set: $x:?"
            return 1
        }
        r=$((s+${!t/* /}))
        for x in $_HPAGE $_CHECKSUM $_ENTRY $_UPDATE $_PREGET $_POSTGET; do
            t="$a[$((r+x))]"
            POOL_ITEM[$x]="${!t}"
        done
    }
}

#;
# @desc Initialize a series of utility space containers
# @ptip $@  series of utility space containers to initialize
# @errv stored in SHELLAPI_ERROR array
#;
function odsel_uspaceinit() {
    local x y z="${I9KG_UTILSPACE[$_LOCATION]}"
    for x in ${@}; do
        [[ -d $z/$x ]] \
            && _emsg "${FUNCNAME}: already there: $x" \
            || mkdir -p "$z"/"$x"/{build,cdump,logs,source} \
                2> /dev/null \
                || _emsg "${FUNCNAME}: could not create: $x"
    done
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc The internal event handler for the -> operator for rpli instructions
# @ptip $@  The array "passed" through _odsel_rpli_i
#;
function _odsel_pm() {
    local x=("${@}") y="" z
    [[ ${x[0]} = \[*\] ]] \
        && _emsg "odsel: in A -> B with A=\"${x[0]}\" is not in context"
    case "${x[z=$((${#x[@]}>4?3:2))]}" in
        \[\])
            ;;
        \[*\])
            [[ "${x[$z]//[\[\]]/}" =~ ^(\$|\&|@|%|pristine|snapshot|build|clone) ]] \
                || _emsg "${FUNCNAME}: in A -> B with B=\"${x[$z]}\" is not in context"
            y="${BASH_REMATCH[1]}"
            ;;
        *)
            _emsg "${FUNCNAME}: expression has no meaning"
        ;;
    esac
    ((${#SHELLAPI_ERROR[@]})) \
        && return 1
    _split "${x[0]}"
    case "$y" in
        \$|pristine|'')
            _ckmsg "requested to put into pristine"
             y=("${SPLIT_STRING[@]/#/pristine/}")
            ;;
        \&|snapshot)
            _ckmsg "requested to make a snapshot"
            y=
            ;;
        @|build)
            _ckmsg "materials put into buildspace"
            y=
            ;;
        %|clone)
            _ckmsg "creating a clone of the repository"
            y=("${SPLIT_STRING[@]/#/clone/}")
            ;;
    esac
    y="${y[@]}"
    y="${y// /,}"
    [[ -z $y ]] \
        && _wmsg "operation valid but not active yet" \
        || odsel_getfn "$y"
}

#;
# @desc Default handler for undefined operators
#;
function _odsel_() {
    _emsg "${FUNCNAME}*: operator not defined"
    return 1
}

#;
# @desc Decide the target of a retrieved resource
# @ptip $1  The pli link identifying the resource within a pool
# @ptip $2  Hash identifier for the pool of the resource, defaults
#           to [prime] if none is set
# @echo Prints the path where odsel_getfn gets executed
#;
function odsel_rtarg() {
    local x= y="__pool_relay_${2:-$(odsel_gph "prime")}"
    case "${1//[[:space:]]/}" in
        pristine/*) x="$y[$_PRISTINE]"  ;;
        clone/*)    x="$y[$_CLONES]"    ;;
        snapshot/*) x="$y[$_SNAPSHOTS]" ;;
    esac
    [[ -z ${!x} ]] || {
        [[ -d ${!x} ]] && {
            printf "%s\n" "${!x}"
            return
        }
    }
    ! :
}

#;
# @desc Create an pool function cache initializer "object"
# @ptip $1  Variable containing pool structural data
# @echo outputs a complete function body
#;
function odsel_pobjc() {
    local x y="$1[$_RPLI]" z="$1[$_RHID]"
    local l=${!y}
    printf "function _init_pool_%s() {\n" "${!z}"
    printf " __pool_relay_%s=(\n" "${!z}"
    for x in ${I9KG_ALIASES[@]}; do
        printf "  [\$_%s]=\"%s\"\n" \
            "$x" "$(eval printf "%b" "\${$1[\$_$x]}")"
    done
    printf " ) \n __pool_rcache_%s=(\n" "${!z}"
    z="$(_asof $l)"
    for((y=0;y<z;y++)); do
        x="$l[$y]"
        printf "  \"%s\"\n" "${!x}"
    done
    printf " )\n}\n"
}

#;
# @desc Create an i9kg function cache initializer "object"
# @ptip $1  Variable containing pool structural data
# @echo outputs a complete function body
#;
function odsel_i9kg_objc() {
    local x y="$1" z="$2"
    local l=${y}
    printf "function __i9kg_init_%s() {\n" "${z}"
    printf "__i9kg_rcache_%s=(\n" "${z}"
    z="$(_asof $1)"
    for((y=0;y<z;y++)); do
        x="$l[$y]"
        printf "  \"%s\"\n" "${!x}"
    done
    printf " )\n}\n"
}

#;
# @desc Create a i9kg "object" header hash
# @ptip $1  an odsel expression
#;
function _odsel_i9kg_header() {
    local a="$1" v=
    [[ "${a/:*/}" =~ ([a-zA-Z0-9_-]*)\[([^[:space:]]*)\] ]] \
            && a=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]:-prime}") \
            || a=("${a/:*/}" "prime")
    v="$(_hsos "${a[0]}[${a[1]}]")"
    printf "%s\n%s\n%s\n" "${a[0]}" "${a[1]}" "$v" "$(odsel_gph "${a[1]}")" "${1#*://}"
}

#;
# @desc Get the pool hash identifier
# @ptip $1  pool name or location
#;
function odsel_gph() {
    printf "%s\n" "$(_hsos "$(_ifnot_jpath "$1" "${I9KG_POOLSPACE}")")"
}

#;
# @desc Enable an odreex pool for use by shellapi
# @ptip $1  pool relay to activate
#;
function odsel_load() {
    local x= y= z= n=
    _split "${1//[[:space:]]/}"
    for n in ${!SPLIT_STRING[@]}; do
        n=${SPLIT_STRING[$n]}
        x=$(odsel_gph "$n")
        y="__pool_relay_$x"
        _isfunction "_init_pool_$x" && _init_pool_$x || {
            if [[ -e $POOL_RELAY_CACHE/functions/$x.poolconf.bash ]]; then
                _imsg "@[$n]: loading configuration cache $(_dotstr "$x")"
                . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash"
                _init_pool_$x &> /dev/null || {
                    _emsg "${FUNCNAME}: for pool [$1]"
                    _emsg "${FUNCNAME}: invalid cache: $(_dotstr "$x")"
                    return 1
                }
                eval "__pool_relay_${x}[\$_RHID]=\"$x\"
                    __pool_relay_${x}[\$_RPLI]=\"__pool_rcache_$x\""
            else
                _nmsg "@[$n]: caching xml relay : $(_dotstr "$x")"
                [[ -e ${POOL_RELAY_CACHE}/xml/$x.poolconf.xml ]] && {
                    _xml2bda "${POOL_RELAY_CACHE}/xml/$x.poolconf.xml"
                    _init_pool_$x
                    z="__pool_relay_$x[$_METABASE]"
                    eval "$y=(\"\${__pool_relay_$x[@]}\"
                                [\$_RHID]=\"$x\"
                                [\$_RPLI]=\"__pool_rcache_$x\")"
                    odsel_pppli "${!z}/metabase.xml" __pool_rcache_$x \
                        && odsel_pobjc $y > "$POOL_RELAY_CACHE/functions/$x.poolconf.bash"
                    . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash"
                    _init_pool_$x
                } || {
                    _emsg "${FUNCNAME}: for pool [$n]"
                    _emsg "${FUNCNAME}: pool configuration relay invalid or missing: $(_dotstr "$x")"
                    return 1
                }
                _cmsg "@[$n]: caching complete  : $(_dotstr "$x")"
            fi
        }
    done
}

#;
# @desc Simulation handler
# @ptip $1  pool identifier
#;
function odsel_sim() {
    [[ -z $1 ]] && {
        _emsg "${FUNCNAME}: pool identifier not set"
        return 1
    }
    local x=
    _split "$1"
    for x in ${SPLIT_STRING[@]}; do
        odsel_ispool "$x" && {
            _emsg "${FUNCNAME}: cannot run a simulation on an already existing pool"
            break
        } || {
            odsel_new "${x}[]" \
                && i9kgoo_sim_metabase_xml "$x" \
                || break
        }
    done
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Check if a pool exists.
# @ptip $1  pool identifier
# @retv 0/1
# @note Commodity function
#;
function odsel_ispool() {
    local x="$(_ifnot_jpath "$1" "${I9KG_POOLSPACE}")"
    [[ -d $x ]] \
        && [[ -e $POOL_RELAY_CACHE/xml/$(_hsos "$x").poolconf.xml ]]
}

#;
# @desc Create a pool, either within the poolset or at a path of your
#       option. A function cache is created for the XML description file
#       as well. If a pool is followed by the [] operator, retrieval of
#       the metabase and its processing takes place. The pool gets enabled
#       on creation (in a way similar to odsel_load)
# @ptip $1  Comma separated pool list
#;
function odsel_new() {
    local x y z f l t k h a
    _split "${1//[[:space:]]/}"
    a=("${SPLIT_STRING[@]}")
    for y in ${a[@]}; do
        [[ "$y" = *\[\] ]] \
            && k=("${y/\[*/}" 1) \
            || k=("$y" 0)
        y="$(_ifnot_jpath "${k[0]}" "${I9KG_POOLSPACE}")"
        h=$(_hsos "$y")
        f="$POOL_RELAY_CACHE/xml/$h.poolconf.xml"
        t="$POOL_RELAY_CACHE/functions/$h.poolconf.bash"
        [[ -e $f ]] \
            && _emsg "${FUNCNAME}: xml pool description already available: $(_dotstr "$h")" \
            && return 1
        ! mkdir "$y" 2> /dev/null &&  {
             [[ -d $y ]] \
                && _emsg "${FUNCNAME}: already available: $y" \
                || _emsg "${FUNCNAME}: could not create: $y"
                return 1
        } || {
            printf  "<bashdata fni=\"_init_pool_$h\">
 <array name=\"%s\" check=\"reuse\">\n" \
                    "__pool_relay_$h"
            z=("${I9KG_PRIME[$_RHID]}" "${I9KG_PRIME[$_RPLI]}")
            unset I9KG_PRIME[$_RPLI] I9KG_PRIME[$_RHID]
            for x in ${!I9KG_PRIME[@]}; do
                l="${I9KG_PRIME[$x]##*/prime}"
                mkdir -p "$y$l"
                printf  "  <index name=\"%s\">%s</index>\n" \
                        "${I9KG_ALIASES[$x]}" \
                        "$y$l"
            done 2> /dev/null
            printf  "  <index name=\"RPLI\">__pool_rcache_%s</index>
  <index name=\"RHID\">%s</index>\n </array>\n</bashdata>\n" \
                    "$h" "$h"
            I9KG_PRIME[$_RHID]="${z[0]}"
            I9KG_PRIME[$_RPLI]="${z[1]}"
        } > "$f" 2> /dev/null || {
            _emsg "${FUNCNAME}: could not create: $y"
            rm -rf "$f"
        }
        ! [[ -e $t ]] \
            && _xml2bda "$f" "$t" \
            && _init_pool_$h || {
                _emsg "${FUNCNAME}: function cache already present: $t"
                return 1
            }
        ((${k[1]})) && {
            z="__pool_relay_$h[$_METABASE]"
            rm -rf "${!z}"
            _nmsg "@[${k[0]}]: retrieving metabase"
             wget http://odreex.org/metabase/metabase.xml --directory-prefix="${!z}" &> /dev/null \
                && _eqmsg "@[${k[0]}]: metabase retrieved" \
                || {
                    _emsg "${FUNCNAME}: could not retrieve metabase"
                    return 1
                }
            _imsg "@[${k[0]}]: updating, reloading configuration cache $(_dotstr "$h")"
            odsel_pppli "${!z}/metabase.xml" __pool_rcache_$h \
                && odsel_pobjc __pool_relay_$h > "$POOL_RELAY_CACHE/functions/$h.poolconf.bash"
            . "$POOL_RELAY_CACHE/functions/$h.poolconf.bash"
            _init_pool_$h
        }
    done
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Remove a series of pools from the runspace
# @ptip $1  comma separated list of pool names
#;
function odsel_del() {
    local x y a
    _split "${1//[[:space:]]/}"
    a=("${SPLIT_STRING[@]}")
    for x in ${!a[@]}; do
        x="${a[$x]}"
        case "$x" in
            \* | '')
                _emsg "${FUNCNAME}: \$1 must be set to a specific pool"
                return 1
            ;;
            *)
                y=$(odsel_gph "$x")
                rm -rf  "$POOL_RELAY_CACHE/xml/$y.poolconf.xml" \
                        "$POOL_RELAY_CACHE/functions/$y.poolconf.bash" \
                        "${I9KG_DEFS[$_POOLSETS]}/$x"
            ;;
        esac
    done
}

#;
# @desc Extract name / version information out of a tarball
# @ptip $1  path to the tarball or name of the tarball
#;
function odsel_targuess() {
    POOL_TARGUESS=()
    local x s="${1##*/}" v n i
    [[ $s =~ \-([^.-]*)\. ]] \
        && x=${BASH_REMATCH[1]}
    n="${s%-${x}.*}"
    case "$s" in
        *.tar.bz2 | *.tar.gz | \
        *.tar.lzma | *.tgz | *.tbz2)
            v="${s%.t*}"
            v="${v#*$n-}"
        ;;
        *)
            _emsg "${FUNCNAME}: cannot deduce from: $s"
            return 1
        ;;
    esac
    [[ ${v/\.*/} == snapshot ]] \
        && i="snapshot" \
        || i="pristine"
    # name - version - identity - original name - sha1sum
    POOL_TARGUESS=("$n" "$s" "$v" "$i" "$(_hsof "$1")")
}

#;
# @desc Expand a rpli metalink into the actual retrieval expression
# @ptip $1  rpli metalink
#;
function odsel_ifetch() {
    local e
    case "$1" in
        http\://* | \
        ftp\://* | \
        https\://*)
            e="${POOL_DGET} $1"
            ;;
        git\://http\://* | \
        git\:https\://*)
            e="git clone ${1#git\://}"
            ;;
        git\://*)
            e="git clone $1"
            ;;
        svn\://http\://* | \
        svn\://https\://*)
            e="svn co ${1#svn\://}"
            ;;
        svn\://*)
            e="svn co $1"
            ;;
        hg\://*)
            e="hg clone $1"
            ;;
        cvs\://*)
            e="cvs -z9 -d:pserver:${1#cvs\://}"
            ;;
        bzr\://http\://* | \
        bzr\://https\://*)
            e="bzr branch ${1#bzr\://}"
            ;;
        bzr\://*)
            e="bzr branch $1"
            ;;
        *)
            _isfunction "_odsel_handler_${1/:\/\/*/}" \
                && e=$(_odsel_handler_${1/:\/\/*/} "$1") \
                || return 1
            ;;
    esac
    printf "%s\n" "$e"
    ! ((${#SHELLAPI_ERRORS[@]}))
}

#;
# @desc Generate and use a function for retrieving a particular
#       set of resources.
# @ptip $1  comma separated list of pli resources
# @ptip $2  pool hash identifier, defaults to using prime
#;
function odsel_getfn() {
    local x f o a
    FNPREP_ARRAY=()
    _split "${1//[[:space:]]/}"
    a=("${SPLIT_STRING[@]}")
    for x in ${!a[@]}; do
        x="${a[$x]}"
        odsel_ifind "$x" "${2:-$(odsel_gph "prime")}" && {
            o="_odself_$(_hsos "$x")"
            while read -r j; do
                [[ -z $j ]] \
                    || FNPREP_ARRAY+=("$j")
            done< <(printf "%s\n%s\n%s\n" \
                    "${POOL_ITEM[$_PREGET]}" \
                    "$(odsel_ifetch "${POOL_ITEM[$_ENTRY]}")"\
                    "${POOL_ITEM[$_POSTGET]}")
            f="$(mktemp)"
            [[ -z ${POOL_ITEM[$_CHECKSUM]} ]] \
                || FNPREP_ARRAY+=(\
"_cfx ${POOL_ITEM[$_ENTRY]##*/} ${POOL_ITEM[$_CHECKSUM]} && \\\
fnapi_msg \"checking hash of ${POOL_ITEM[$_ENTRY]##*/} : \
\$(_dotstr "${POOL_ITEM[$_CHECKSUM]}") : ok\"")
            fnapi_genblock "$o" "pool request: $x" \
                FNPREP_ARRAY "pool request: $x" fatal > "$f"
            unset FNPREP_ARRAY
            . "$f"
            rm -rf "$f"
            f="$(odsel_rtarg "$x" "${2:-$(odsel_gph "prime")}")" && {
                pushd "$f" &> /dev/null
                $o
                popd &> /dev/null
            } || { _emsg "${FUNCNAME}: could not deduce retrieval target: $x"; return 1; }
        } || { _emsg "${FUNCNAME}: [function()] --> $x ?"; return 1; }
    done
}

#;
# @desc Transform a directory or any tarball into a tarball with the default payload
#       option, putting it into [snapshots] or [payload] directory by default, or
#       storing it at a specified, existing path in the filesystem.
# @ptip $1  A valid filesystem path (file or directory)
# @ptip $2  A valid filesystem path where to store the result or a [] enclosed pool
#           identifier. This identifier is used to deduce payload, snapshot directories;
#           in all other scenarios, gets treated as a plain path.
#;
function odsel_recoil() {
    local x="$1" y="${2:-[prime]}" z= r= s= t=
    POOL_REPORT=() POOL_TARGUESS=()
    case "$y" in
        \[*\] | '')
            y=${y:1:$((${#y}-2))}
            z=$(odsel_gph "$y")
            r="__pool_relay_$z[$_PAYLOAD]"
            s="__pool_relay_$z[$_SNAPSHOTS]"
            s="${!s}"; r="${!r}"; z=
            ;;
        *)
            [[ -d $y ]] || {
                _emsg "${FUNCNAME}: not a valid directory: $y"
                return 1
            }
            s="$y"; r="$y"
            ;;
    esac
    case "$x" in
        *.tar.bz2 | *.tbz)  z="bzip2 -dc" ;;
        *.tar.gz | *.tgz)   z="gzip -dc"  ;;
        *.tar.lzma)         z="lzma -dc"  ;;
        *)
            [[ -d $x ]] || {
                _emsg "${FUNCNAME}: directory does not exist: $s"
                return 1
            }
        ;;
    esac
    ! [[ -z $z ]] && {
        [[ -e $x ]] && {
            t="${1##*/}"
            t="$r/${t%.t*}.tar.${SHELLAPI_PAYLOAD//[ip]/}"
            _omsg "payload: $x -> ${t##*/}"
            {
                $z "$x" | $SHELLAPI_PAYLOAD --best > "$t"
            } &> /dev/null || {
                _emsg "conversion failed: $x"
                return 1
            }
        } || {
            [[ -d $x ]] \
                && _emsg "${FUNCNAME}: directory to consider as file?: $x"
            _emsg "${FUNCNAME}: file does not exist: $x"
            return 1
        }
    } || {
        [[ -d $x ]] && {
            t="$s/${x##*/}-snapshot.$(_dtff).tar.${SHELLAPI_PAYLOAD//[ip]/}"
            _omsg "snapshot: $x -> ${t##*/}"
            {
                pushd "${x%/*}"
                [[ ${x##*/} = $x ]] && x="."
                tar cf - "${x##*/}" | ${SHELLAPI_PAYLOAD} --best -c - > "$t"
                popd
            } &> /dev/null || {
                _emsg "${FUNCNAME}: could not perform conversion for: $1"
                return 1
            }
        } || {
            _emsg "${FUNCNAME}: directory does not exist: $x"
            return 1
        }
    }
    odsel_targuess "$t" && {
        [[ -z $x ]] \
            && POOL_REPORT="snapshot/${POOL_TARGUESS[0]}:${POOL_TARGUESS[2]#*.}" \
            || POOL_REPORT="payload/${POOL_TARGUESS[0]}:${POOL_TARGUESS[2]}"
        POOL_REPORT=("$POOL_REPORT" "${POOL_TARGUESS[1]}" "${POOL_TARGUESS[4]}")
    } || {
        _emsg "${FUNCNAME}: tar guessing failed"
        return 1
    }
}

#;
# @desc Performs Complete function cache removal for relays
# @ptip $1  pool id for the relay cache function (comma separated list)
#;
function odsel_delc() {
    local x="${1:-prime}"
    _split "${x//[[:space:]]/}"
    for x in ${!SPLIT_STRING[@]}; do
        x=$(odsel_gph "${SPLIT_STRING[$x]}")
        . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash" &> /dev/null && {
            _isfunction "_init_pool_$x" && {
                _init_pool_$x
                x="__pool_relay_$x[$_FCACHE]"
                ! [[ -z ${!x} ]] && rm -rf "${!x}"/*.bash
            }
        }
    done
}
