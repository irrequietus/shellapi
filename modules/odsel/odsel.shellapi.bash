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
# @desc The init implementation for this module
# @warn Same fix as in _init for _opsolve (bash 4.x related)
#;
function odsel_init() {
    ODSEL_TARCOIL=()
    ODSEL_TARGUESS=()
    ODSEL_DGET="wget -c"
    ODSEL_XMLA=()
    ODSEL_RXP=(
        [0]="^[[:space:]]*([[:alnum:]_-]*)[[:space:]]*\
((\[[[:space:]]*([[:alnum:]_-]*)[[:space:]]*\])|([[:space:]]*))"
        [1]="^[[:space:]]*([[:alnum:]_-]*)[[:space:]]*\
\[[[:space:]]*([[:alnum:]_\.-]*)[[:space:]]*(.)"
        [2]="[[:space:]]*@[[:space:]]*([[:alnum:]_]*)\
[[:space:]]*:[[:space:]]*([[:alnum:]_]*)\
[[:space:]]*->[[:space:]]*([[:alnum:]_]*)"
        [3]="[[:space:]]*\{([[:space:][:alnum:]:@\>,_-]*)\}"
        [4]="[[:space:]]*:[[:space:]]*(code|text)[[:space:]]*\;"
)
    ODSEL_OPRT=()
    ODSEL_OPRT[$(_opsolve "->")]="pm"
    ODSEL_OPRT[$(_opsolve "~>")]="rm"
    ODSEL_OPRT[$(_opsolve "<-")]="lm"
    ODSEL_OPRT[$(_opsolve "=")]="as0"
    ODSEL_OPRT[$(_opsolve ":=")]="as1"
    ODSEL_OPRT[$(_opsolve "::=")]="as2"
    _wexp_this odsel_vdef odsel_import odsel_export odsel_fsi
}

#;
# @desc The prototype for handling the odsel switch / case expression
# @ptip $1  switch / case expression written in odsel semantics
# @note Currently comprised of a simple syntax checker only
#;
function odsel_swcase() {
    [[ $1 =~ ^[[:space:]]*([[:alnum:]\(\)]*)*[[:space:]]*=\>[[:space:]]*(.*) ]] && {
        local x="${BASH_REMATCH[1]}" y="${BASH_REMATCH[2]}" z=
        while [[ $y =~ ^[[:space:]]*(\||case)[[:space:]]+(.*) ]]; do
            z="${BASH_REMATCH[2]}"
            [[ $z =~ ^\"([^\"]*)\"[[:space:]]*:[[:space:]]+([[:alnum:]_\(\)]*) \
            || $z =~ ^\'([^\']*)\'[[:space:]]*:[[:space:]]+([[:alnum:]_\(\)]*) \
            || $z =~ ^([[:alnum:]_]*)[[:space:]]*:[[:space:]]+([[:alnum:]_\(\)]*) ]] && {
                y="${y#*"${BASH_REMATCH[1]}"*"${BASH_REMATCH[2]}"}"
            }
        done
    } || _emsg "${FUNCNAME}: incorrect syntax"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc odsel_vsi prototype (to deprecate ununified means)
# @ptip $1  A valid odsel expression
#;
function odsel_vsi() {
    _qsplit "$(_ccrem "${1}")" \;
    local x y z a n m b z g f=() i=("${SPLIT_STRING[@]}")
    for((x=0;x<${#i[@]};x++)); do
        y="${i[$x]}"
        [[ -z ${y//[[:space:]]/} ]] && continue
        if [[ $y =~ ^[[:space:]]*(\?|:|@|newc|delc|load|del|new|sim|def|import|export|unit|init|switch|flush)[[:space:]]*(.*) ]]; then
            case "${BASH_REMATCH[1]}" in
                init|unit)
                    _omsg "$(_emph ${BASH_REMATCH[1]}): ${i[$x]}"
                ;;
                \?|switch)
                    n="${y#*${BASH_REMATCH[1]}}"
                    [[ $n =~ ^[[:space:]]*([[:alnum:]\(\)]*)*[[:space:]]*=\>[[:space:]]*(.*) ]]
                    _omsg "$(_emph patt): ${BASH_REMATCH[1]}"
                    odsel_swcase "$n" \
                        || return 1
                ;;
                def|:)
                    case "${i[$x]#*${BASH_REMATCH[1]}}" in
                        [[:space:]]*)
                                n="${BASH_REMATCH[2]}"
                                local _r="${BASH_REMATCH[1]}"
                                if  [[ $n =~ ^([[:alnum:]_]*)\(\)[[:space:]]*\{([[:space:]]*) ]]; then
                                    _isfunction _fnop_${BASH_REMATCH[1]} && {
                                        _emsg "${FUNCNAME}: already defined: ${BASH_REMATCH[1]}()"
                                    } || {
                                        [[ ${n#*{${BASH_REMATCH[2]}} == \} ]] && {
                                            eval "_fnop_${BASH_REMATCH[1]}(){ _void; }"
                                        } || {
                                            m=" ${!i[@]} "; m=(${m#* $x }); f=("${i[$x]#*{}")
                                            [[ -z ${f[0]//[[:space:]]/} ]] && {
                                                eval "_fnop_${BASH_REMATCH[1]}(){ _void; }"
                                            } || {
                                                for x in ${m[@]}; do
                                                    [[ ${i[$x]} == \} ]] && break
                                                    [[ -z ${i[$x]//[[:space:]]/} ]] || f+=("${i[$x]}")
                                                done
                                                _omsg "$(_emph dfun): ${BASH_REMATCH[1]}"
                                                eval "_fnop_${BASH_REMATCH[1]}=(\"\${f[@]/%/;}\")"
                                            }
                                        }
                                    }
                                elif [[ $n =~ ^([[:alnum:]_]*)\(\)[[:space:]]*=\>[[:space:]]*\{(.*)\} ]]; then
                                    local nm="${BASH_REMATCH[1]}" o="${BASH_REMATCH[2]}" t= l=
                                    _omsg "$(_emph dcbk): callback list detected for: ${BASH_REMATCH[1]}()"
                                    while [[ $o =~ (\][[:space:]]*,) ]]; do
                                        l="${o/"${BASH_REMATCH[1]}"*/}]:code;"
                                        t+="$l"
                                        o="${o#*${BASH_REMATCH[1]}}"
                                        odsel_getcbk "$l" || return 1
                                    done
                                    l="$o:code;"
                                    t+="$l"
                                    odsel_getcbk "$l" \
                                        && eval "_fnop_$nm() { __odsel_cbkdeploy \"${t}\"; }"
                                elif [[ $n =~ ^([[:alnum:]_]*)\(\)[[:space:]]*=\>(.*) ]]; then
                                    _omsg "$(_emph dcbk): callback: ${BASH_REMATCH[1]}()"
                                    odsel_dcbk "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
                                        || _emsg "${FUNCNAME}: could not define callback"
                                elif [[ $n =~ ^([[:alnum:]_]*)[[:space:]]*=[[:space:]]* ]]; then
                                    odsel_vdef "${i[$x]#*$_r}" \
                                        || _emsg "${FUNCNAME}: cannot parse definition: ${i[$x]}"
                                elif [[ $n =~ ^\[([[:alnum:]_]*)\][[:space:]]*=[[:space:]]*\>[[:space:]]*@ ]]; then
                                    n=${BASH_REMATCH[1]}
                                    odsel_gscoil "${i[$x]};" \
                                        && _omsg "$(_emph coil): $(_emph $n): defined" \
                                        || { _emsg "${FUNCNAME}: cannot define expression base: " \
                                                   " * : ${y:0:$((${#y}/5))}..."; }
                                elif [[ $n =~ ^([\]\[[:alnum:]_]*)(=|\<\<)(.*) ]]; then
                                    _omsg "$(_emph dval): ${BASH_REMATCH[1]}"
                                    [[ ${BASH_REMATCH[2]} = \<\< ]] \
                                        && n="${BASH_REMATCH[1]}://${BASH_REMATCH[3]}" \
                                        || n="${BASH_REMATCH[3]}"
                                elif [[ $n =~ ^@([[:alnum:]_]*)\[([[:alnum:]_]*)\][[:space:]]*(:=|=|::=)[[:space:]]*(.*) ]]; then
                                    _omsg "$(_emph i9kg): assignment operation detected"
                                    _omsg "$(_emph i9kg): ${BASH_REMATCH[3]} ${BASH_REMATCH[1]}[${BASH_REMATCH[2]}]"
                                    _odsel_${ODSEL_OPRT[$(_opsolve "${BASH_REMATCH[3]}")]} "${BASH_REMATCH[4]}" || return 1
                                else
                                    _emsg "${FUNCNAME}: illegal def:" " *  $n"
                                fi
                            ;;
                            :*)
                                _omsg "$(_emph rpli): ${BASH_REMATCH[2]}"
                                ;;
                    esac
                    ;;
                flush)
                    _omsg "$(_emph flsh): cleaning up fail flags"
                    fnapi_flush
                    ;;
                @)
                    _omsg "$(_emph rpli): ${BASH_REMATCH[1]:1}${BASH_REMATCH[2]}"
                    _odsel_rpli_i "${BASH_REMATCH[1]:1}${BASH_REMATCH[2]}"
                    ;;
                *)
                    _omsg "$(_emph rpli): odsel_${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
                    odsel_${BASH_REMATCH[1]} "${BASH_REMATCH[2]}"
                    ;;
            esac
        elif [[ $y =~ ^[[:space:]]*([[:alnum:]_]*)\(\)(.*) ]]; then
            [[ -z ${BASH_REMATCH[2]} ]] \
                && _omsg "$(_emph call): -> ${BASH_REMATCH[1]}" \
                || { _emsg "${FUNCNAME}: wrong syntax!"; return 1; }
            n="_fnop_${BASH_REMATCH[1]}"
            _isfunction $n && {
                ($n || { _for_each SHELLAPI_ERROR _fail; return 1; } ) \
                    || { _emsg "${FUNCNAME}: callback failure"; return 1; }
            } || {
                ! [[ -z ${!n} ]] && {
                    n="$n[*]"
                    odsel_vsi "${!n}" \
                        || _emsg "${FUNCNAME}: cascade failure"
                } || _emsg  "$(_emph call): ${BASH_REMATCH[1]}(): failed because:" \
                            "* undefined call: ${BASH_REMATCH[1]}()"
            }
        elif [[ $y =~ ^[[:space:]]*([\]\[[:alnum:]_]*):// ]]; then
            _omsg "$(_emph i9kg): ? ${BASH_REMATCH[1]}"
        else
            _emsg "${FUNCNAME}: unknown request"
        fi
        ((${#SHELLAPI_ERROR[@]})) && return 1 || :
    done
}

#;
# @desc A selector for odsel "finals"; practically keyword - driven
#       action selector
# @ptip $1  An unmatched final selector
#;
function odsel_i9kgfsel() {
    case "${1//[[:space:]]/}" in
        ''|code|c) printf "t" ;;
        text|t)    printf "c" ;;
        *)  _emsg "${FUNCNAME}: unknown final: $1"
            return 1
            ;;
    esac
}

#;
# @desc An odsel file interpreter
# @ptip $1  full path to odsel file to interpret
#;
function __odsel_fsi_p() {
    ! [[ -z $1 ]] && {
        [[ -e $1 ]] && {
            odsel_vsi "$(< "$1")" \
                || _emsg "${FUNCNAME}: file could not be interpreted"
        } || _emsg "${FUNCNAME}: file not found: $1"
    } || _emsg "${FUNCNAME}: no file given, aborting"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Evolution of odsel_scli(), in unstable form. This one does work with
#       the new odsel_exprseq implementation and will deprecate odsel_scli()
# @ptip $1  An odsel i9kg expression.
#;
function __odsel_i9kgi_p() {
    local p= n= v= i= a= b= x= y= r=() _r _c k s= j
    [[ $1 =~ ${ODSEL_RXP[0]} ]] && {
        p="${BASH_REMATCH[4]}${BASH_REMATCH[5]}"
        y=${BASH_REMATCH[1]}; p=${p:-prime}
        _r=_odsel_gscoil_$(odsel_gph "$p")
        _isfunction $_r && _r="$($_r)" || return 2
        [[ ${x:=${1#*//}} =~ ${ODSEL_RXP[1]} ]] && {
            n="${BASH_REMATCH[1]}";v="${BASH_REMATCH[2]}";x="${x#*$v}"
            case "${j:=${BASH_REMATCH[3]}}" in
                @)  [[ $x =~ @([[:alnum:]_]*):([[:alnum:]_]*)[[:space:]]*\]${ODSEL_RXP[4]}
                    || $x =~ @([[:alnum:]_]*):([[:alnum:]_]*)[[:space:]]*\]([^\;]*)\; ]] && {
                        k=$(odsel_i9kgfsel "${BASH_REMATCH[3]}") || return 1
                        r+=("$n[$v@${BASH_REMATCH[1]}:${BASH_REMATCH[2]}]")
                    } || {
                        [[ $x =~ ${ODSEL_RXP[2]}[[:space:]]*\]${ODSEL_RXP[4]} \
                        || $x =~ ${ODSEL_RXP[2]}[[:space:]]*\]([^\;]*)\; ]] && {
                            k=$(odsel_i9kgfsel "${BASH_REMATCH[4]}") || return 1
                            _r="${_r#*${BASH_REMATCH[2]}}"
                            _r="${_r%${BASH_REMATCH[3]}*}"
                            r+=("$n[${v}@${BASH_REMATCH[1]}:${BASH_REMATCH[2]}]")
                            for _c in ${_r}; do
                                r+=("$n[${v}@${BASH_REMATCH[1]}:${_c}]") 
                            done
                            r+=("$n[${v}@${BASH_REMATCH[1]}:${BASH_REMATCH[3]}]")
                            s="${x#*${BASH_REMATCH[3]}*]}"
                            [[ $s =~ ^${ODSEL_RXP[4]} ]] \
                                && k=$(odsel_i9kgfsel "${BASH_REMATCH[1]}") \
                                || return 1
                        }
                    }
                    ;;
                \]) # fix this once out of _p() phase, hardwiring must go
                    r+=("$n[${v}@stable:configure_pre->make_install_post]")
                    ;;
                :)  [[ $x =~ ${ODSEL_RXP[3]}[[:space:]]*\]${ODSEL_RXP[4]}
                    || $x =~ ${ODSEL_RXP[3]}[[:space:]]*\]([^\;]*)\; ]] && {
                        s="${BASH_REMATCH[1]}"
                        k=$(odsel_i9kgfsel "${BASH_REMATCH[2]}") || return 1
                        [[ $s =~ ^@([[:alnum:]_]*):([[:alnum:]_]*) ]] \
                            && [[ $s == @${BASH_REMATCH[1]}:${BASH_REMATCH[2]} ]] && {
                            r+=("$n[$v$s]")
                            s=
                        } || {
                            s="$s,"
                            while [[ $s =~ ${ODSEL_RXP[2]} ]]; do
                                _r="${_r#*${BASH_REMATCH[2]}}"
                                _r="${_r%${BASH_REMATCH[3]}*}"
                                r+=("$n[${v}@${BASH_REMATCH[1]}:${BASH_REMATCH[2]}]")
                                for _c in ${_r}; do
                                    r+=("$n[${v}@${BASH_REMATCH[1]}:${_c}]") 
                                done
                                r+=("$n[${v}@${BASH_REMATCH[1]}:${BASH_REMATCH[3]}]")
                                s="${s#*,}"
                            done
                        }
                        [[ -z $s ]]
                    } || ! :
                    ;;
                 *) ! : ;;
            esac
        } || ! :
    } || return 1
    [[ -z $2 ]] && {
        x=($(_odsel_i9kg_header "$1"))
        x="${x[2]}"
    } || x="$2"
    for z in ${!r[@]}; do
        odsel_exprseq "${r[$z]}" $x $k || return 1
    done
}

#;
# @desc Load an i9kg XML file describing the various instances of a "package"
#       into an array, complete with the dependency query metadata, build
#       instruction sequences etc. The resulting array is
# @ptip $1  The path to the i9kg XML file to process (stores result to ODSEL_XMLA global)
# @note     Use of <bashdata> is completely experimental within i9kg xml files and
#           this is why it only gives a warning despite performing the planned operations.
# @note The latest change for use with __xmlapi_* prototypes is a temporary speed bottleneck
#       for a while until 0.x-pre7.
#;
function odsel_xmla() {
    local   v_sn= v_an= v_in= v_iv= x= l= \
            v=0 i=0 p=0 q=0 _bd=0 _bc=0 _bn= \
            t=() c=() k=() y=() r=() n=() \
            _A=() _D=() _NB=() _NR=() _DB=() _DR=()
    ODSEL_XMLA=()
    __xmlapi_aftseq "$1" ||  { _emsg "${FUNCNAME}(): illegal exception at $1"; return 1; }
    for l in ${!XML_AFTSEQ[@]}; do
        l="${XML_AFTSEQ[$l]}"
        (($_bd)) && {
            [[ $l == \</bashdata\> ]] && {
                _bd=0
                local f="$(mktemp)"
                _wmsg "${FUNCNAME}: null - handling <bashdata>"
                printf "%s\n</bashdata>\n" "${_BD[$_bc]}" > "$f"
                _xml2bda "$f"
                _bn="$(type _gblx_$_bn | tail --lines=+4)"
                unset -f _gblx_$_bn
                ((_bc++))
            } || _BD[$_bc]+="$(printf "\n%s" "$l")"
            continue
        } || y+=("$(_xmlapi_eex "$l" \&)")
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
                    && v_an="$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)" \
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
                    && v_iv="$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: version"; return 1; }
                [[  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_in="$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: alias"; return 1; }
                    n="$n$(printf "\n%s" "$v_in[$v_iv]")"
                ;;
            \<rpli\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _D[$i]="${_D[$i]}$(printf "\n%s" "$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)")"
                ;;
            \<dbld\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DB[$i]="${_DB[$i]}$(printf "\n%s" "$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)")"
                ;;
            \<drun\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DR[$i]="${_DR[$i]}$(printf "\n%s" "$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)")"
                ;;
            \<nbld\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NB[$i]="${_NB[$i]}$(printf "\n%s" "$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)")"
                ;;
            \<nrun\ */\>)
                [[  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NR[$i]="${_NR[$i]}$(printf "\n%s" "$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)")"
                ;;
            \<sequence\ *)
                [[  $l =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $l =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_sn="$(_xmlapi_eex "${BASH_REMATCH[1]}" \&)" \
                    || { _emsg "${FUNCNAME}: attribute missing in $1: variant"; return 1; }
                ;;
            \<bashdata\>)
                _bd=1
                _bn="$(_hsos "_${v_in}[${v_iv}@${v_sn}]")"
                _BD[$_bc]="<bashdata fni=\"_gblx_$_bn\">"
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
                _emsg "${FUNCNAME}: invalid i9kg XML : $l" "${FUNCNAME}: invalid i9kg file: $1"
                return 1
                ;;
        esac
    done
    y=()
    while read -r l; do
        y+=("$l")
    done< <(for l in ${!_A[@]}; do
                printf "%s\n" "${_A[$l]}"
            done | sort -k1,1 -t\ )
    eval "${2:-ODSEL_XMLA}=(\"\$((\${#y[@]}+1)) \$((\${#r[@]}+\${#y[@]}+1))\"
            \"\${y[@]}\"
            \"\${r[@]}\"
            \"\${n:1}\"
            \"\${_D[@]}\" \"\${_DB[@]}\" \"\${_DR[@]}\" \"\${_NB[@]}\" \"\${_NR[@]}\")"
}

#;
# @desc Creating an i9kg DTD automatically after an odsel_gscoil call. This
#       gives the ability to override any defaults provided for i9kg action tag
#       mode attributes. Examples to follow.
# @ptip $1  Function representing the customized event grammar for i9kg files
#       as produced by odsel_gscoil(), the format is _odsel_gscoil_<pool hash id>
#;
function odsel_gscoil_dtd() {
    _isfunction "$1" && {
        local x=($($1)) y=(dbld drun nbld nrun) z n
        n=("${y[@]/%/ |}" rpli)
        x=("${x[@]/%/ |}")
        printf "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>
<!-- autogenerating custom i9kg DTD: begin -->
<!ELEMENT i9kg (instance)*>
<!ATTLIST i9kg name CDATA #REQUIRED>
<!ELEMENT instance (materials,(sequence)*)>
<!ELEMENT sequence (action)*>
<!ELEMENT action (code|text)*>
<!ELEMENT code (#PCDATA)>
<!ELEMENT text (#PCDATA)>
<!ELEMENT materials (EMPTY | (%s)*)>
%s
<!ATTLIST i9kg name CDATA #REQUIRED>
<!ATTLIST instance alias CDATA #REQUIRED version CDATA #REQUIRED>
<!ATTLIST sequence variant CDATA #REQUIRED>
<!ATTLIST action mode (%s null) \"null\">
<!-- autogenerating custom i9kg DTD: end -->\n" "${n[*]}" \
        "$(for n in ${y[@]} rpli; do
            printf "<!ELEMENT %s EMPTY>\n<!ATTLIST %s item CDATA #REQUIRED>\n" $n $n
          done)" "${x[*]}"
    } || return 1
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
            _psplit "${x:1}"
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
# @ptip $1  A specific instantiation block identifier for a given odsel expression.
# @ptip $2  The i9kg rcache hash identifier it requires; may deduce it on its own
#           but as always, the rcache array must be already initialized.
# @ptip $3  A t/c switch.
# @note As with many others in its group, this is now intended as internal.
#;
function odsel_exprseq() {
    local x="$1" r=1 m=0 t=0 a="__i9kg_rcache_$2" z="$3"
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
            printf "%d\n" $((${x#?}+$v))
        done
    }
}

#;
# @desc A dependency querying mechanism compatible with an i9kg rcache
#       array. The purpose here is to get a whitespace separated list
#       of dependencies of a specific type: {rpli,dbld,drun,nbld,nrun}.
# @ptip $1  An instance - specific block of a valid odsel expression (://*)
# @ptip $2  Any string out of {rpli,dbld,drun,nbld,nrun}
# @ptip $3  The hash id of the i9kg rcache.
# @note The i9kg rcache used must be initialized.
#;
function odsel_depquery() {
    local x q=0 k=0 f=0 y="__i9kg_rcache_$3"
    x="$y[0]"; x="$y[$((q=${!x/* /}))]"
    case "${2:-rpli}" in
        "" | rpli);;
        dbld)   f=1 ;;
        drun)   f=2 ;;
        nbld)   f=3 ;;
        nrun)   f=4 ;;
        *)  printf "%s\n" "-2"
            return 1
        ;;
    esac
    for x in ${!x}; do
        [ "$x" == "$1" ] \
            && printf "%s\n" "$((q+$(($(($(_asof $y)-$((++q))))*f/5))+k))" \
            && return
        ((k++))
    done
    printf "%s\n" "-1"
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
# @desc Prepare a resource for use (extraction to path from its identifier)
# @ptip $1 Resource identifier (<name>:<version>) of the compressed resource.
# @ptip $2 Physical path where the compressed resource gets extracted.
# @ptip $3 The hash identifier of the pool containing the resource we want.
# @devs FIXME: odsel_ifind() gets called twice, rewire odsel_getfn or
#       deprecate it.
#;
function odsel_extpli() {
    local x="$1" y h="${3:-$(odsel_gph prime)}" c= i= e=0
    local z="__pool_relay_$h[$_PRISTINE]"
    odsel_ifind "$x" "$h" \
        && x="${!z}/${POOL_ITEM[$_ENTRY]##*/}" \
        || { _emsg "${FUNCNAME}: could not find resource: ${1##*/}"; return 1; }
    [[ -e $x ]] && _cfx "$x" ${POOL_ITEM[$_CHECKSUM]} || {
        odsel_getfn "$1" $h || {
            _emsg "${FUNCNAME}: could not export resource: ${1##*/}"
            return 1
        }
    }
    case "$x" in
        *.tar.bz2|*.tbz) c=j ;;
        *.tar.gz|*.tgz)  c=z ;;
        *.tar.lzma)      c=l ;;
        *.bz2)           c=b; i="bzip2 -d" ;;
        *.gz)            c=g; i="gzip  -d" ;;
        *.lzma)          c=a; i="lzma  -d" ;;
    esac
    case "$c" in
        [jz])  tar -C "${2:-.}" -x${c}f "$x" &> /dev/null || e=1 ;;
        [bga]) cp "$x" "${2:-.}" && $i "${2:-.}/${x##*/}" &> /dev/null || e=1 ;;
        l)     { lzma -dc "$x" | tar -C "${2:-.}" -x ; } 2> /dev/null
               [[ ${PIPESTATUS[*]} = "0 0" ]] || e=1 ;;
    esac
    ((e)) && { _emsg "${FUNCNAME}: could not extract ${x##*/}"; return 1; }
    return 0
}

#;
# @desc Part of the "callback" cascade, also able to detect cycles and prepare
#       the ODSEL_DDEPS global doing hoop jumping in hoops between the three parts.
# @devs FIXME: _cp_* locks need cleanup, hardwiring for the default event
#       grammar must also be removed.
#;
function __odsel_ddepexp_p() {
    local x= y= f= z=()
    odsel_getcbk "$1" && {
        x="${1%@*}]"
        x="${x//[\{\}[:space:]]/}"
        y="${x//[:\/.\]\[]/_}"
        f="${1//[[:space:]]/}"
        x="${f%:*}"
        y=_fnoph_$(_hsos "${f}")
        ((${#ODSEL_CBKDEP[@]})) && {
            ((_cp_$y)) || {
                ((_cp_$y=1))
                ODSEL_DDEPS+=("$y ${ODSEL_CBKDEP[*]//[:\/.\]\[]/_}")
                for x in ${!ODSEL_CBKDEP[@]}; do
                    z+=("${ODSEL_CBKDEP[$x]}")
                done
                for x in ${!z[@]}; do
                    __odsel_ddepexp_p "${z[$x]%?}@stable:configure_pre->make_install_post]:code;" \
                    || break
                done
            }
        } || {
            ((_cp_$y)) || {
                ODSEL_DDEPS+=("$y _void")
                ((_cp_$y=1))
            }
        }
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc The "initiating part" of the cascade trio (prepare, expand, formulate) needed
#       for completing the initial part of the instantiation sequence. The other
#       two are __odsel_ddepexp_p() and odsel_getcbk()
# @ptip $1  A semicolon separated list of odsel block extraction expressions
# @devs FIXME: change (;), give alternative to ODSEL_DDEPS global, etc.
#;
function __odsel_ddepprep_p() {
    local x="$IFS" y z=()
    IFS=";"; y=($1); IFS="$x"
    ODSEL_DDEPS=()
    for x in ${!y[@]}; do
        __odsel_ddepexp_p "${y[$x]};"
    done
}

#;
# @desc Extracting a resource and collocating it with its patches in the same
#       allocated uuid - named folder within utilspace.
# @ptip $1 Resource identifier (<name>:<version>) of the compressed resource.
# @ptip $2 The hash identifier of the pool containing the resource we want.
# @ptip $3 Specifying a particular uuid / identifier to use in utilspace (optional)
#;
function odsel_sppx() {
    local x="$1" y z="${2:-$(odsel_gph prime)}" a="${3:-$(_uuidg)}"
    local b="__pool_relay_$z[$_PATCHES]"
    ODSEL_SSPXU=
    _omsg "$(_emph sppx): $1 -> $a: ..."
    odsel_uspaceinit "$a" \
        && odsel_extpli "pristine/$1" "${I9KG_UTILSPACE[$LOCATION]}/$a/source" "$z" \
        || _emsg "${FUNCNAME}: could not prepare resource: $1"
    ((${#SHELLAPI_ERROR[@]})) && {
        rm -rf "${I9KG_UTILSPACE[$_LOCATION]}/$a"
        return 1
    } || {
        [[ -d ${!b}/${1/:/-}/ ]] && {
            cp -ax "${!b}/${1/:/-}/" "${I9KG_UTILSPACE[$_LOCATION]}/$a/source" \
                || { _emsg "${FUNCNAME}: could not prepare resource: $1"; return 1; }
        }
    }
    _omsg "$(_emph sppx): $1 -> $a: ok!"
    ODSEL_SSPXU=$a
}

#;
# @desc An anonymous callback deploy function that can deploy callbacks while respecting
#       their actual dependencies.
# @ptip $1  Anonymous callbacks with ; separation
# @note An anonymous callback sequencing experiment.
#;
function __odsel_cbkdeploy() {
    local v= x= y= z= n=()
    __odsel_ddepprep_p "$1" && {
        v=($(__fnapi_deploy_schedule_p ODSEL_DDEPS \
                || { _for_each SHELLAPI_ERROR _fail; return 1; })) || _fatal
        for x in ${v[@]:1}; do
            _omsg "$(_emph preq): ${!x}"
            for y in $($x preq); do
                ($y || { _for_each SHELLAPI_ERROR _fail; return 1; }) || {
                    _emsg "${FUNCNAME}: could not deploy anonymous callback:" \
                          "* ..."
                    unset -v ODSEL_DDEPS ODSEL_CBKDEP ODSEL_SSPXU
                    return 1
                }
            done
            _omsg "$(_emph runf): () => ${!x}"
            ($x || { _for_each SHELLAPI_ERROR _fail; return 1; }) || {
                _emsg "${FUNCNAME}: could not deploy anonymous callback:" \
                      "* ${!x}"
                break
            }
        done
    } || _emsg "${FUNCNAME}: deployment failure"
    unset -v ODSEL_DDEPS ODSEL_CBKDEP ODSEL_SSPXU
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
    _psplit "${x[0]}"
    case "$y" in
        \$|pristine|'')
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
# @desc Assignment type 0 handler decoy
# @ptip $1  String with valid json input
# @note The /* */ comments have been already removed so $1 is valid json
#;
function _odsel_as0() {
    _omsg "$(_emph i9kg): assignment type 0"
    _jsonpnseq "$1" \
        && _omsg "$(_emph json): assignment of: $((${#SPNSEQ_JSON[@]}-1))"
}
#;
# @desc Assignment type 1 handler decoy
# @ptip $1  String with valid json input
# @note The /* */ comments have been already removed so $1 is valid json
#;
function _odsel_as1() {
    _omsg "$(_emph i9kg): assignment type 1"
    _jsonpnseq "$1" \
        && _omsg "$(_emph json): assignment of: $((${#SPNSEQ_JSON[@]}-1))"
}

#;
# @desc Assignment type 2 handler decoy
# @ptip $1  String with valid json input
# @note The /* */ comments have been already removed so $1 is valid json
#;
function _odsel_as2() {
    _omsg "$(_emph i9kg): assignment type 2"
    _jsonpnseq "$1" \
        && _omsg "$(_emph json): assignment of: $((${#SPNSEQ_JSON[@]}-1))"
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
    local a="${1//[[:space:]]/}" v=
    [[ $a =~ ://([[:alnum:]_-]*)\[([.[:alnum:]_-]*)[\]@:] ]] \
        && v="${BASH_REMATCH[1]}[${BASH_REMATCH[2]}]"
    [[ "${a/:*/}" =~ ([[:alnum:]_-]*)\[([^[:space:]]*)\] ]] \
            && a=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]:-prime}") \
            || a=("${a/:*/}" "prime")
    a[2]="$(_hsos "${a[0]}[${a[1]}]")"
    printf "%s\n" "${a[@]} $(odsel_gph "${a[1]}") $v $(_hsos "${1//[[:space:]]/}")"
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
    _psplit "${1//[[:space:]]/}"
    for n in ${!SPLIT_STRING[@]}; do
        n=${SPLIT_STRING[$n]}
        x=$(odsel_gph "$n")
        y="__pool_relay_$x"
        _isfunction "_init_pool_$x" && _init_pool_$x || {
            if [[ -e $POOL_RELAY_CACHE/functions/$x.poolconf.bash ]]; then
                _omsg "$(_emph pool): $(_emph $n): loading configuration cache $(_dotstr "$x")"
                . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash"
                _init_pool_$x &> /dev/null || {
                    _emsg "${FUNCNAME}: for pool [$1]" " * : invalid cache: $(_dotstr "$x")"
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
                    _emsg   "${FUNCNAME}: in pool [$n]" \
                            " * : pool configuration relay invalid or missing: $(_dotstr "$x")"
                    return 1
                }
                _cmsg "@[$n]: caching complete  : $(_dotstr "$x")"
            fi
        }
    done
}

#;
# @desc Simulation handler
# @ptip $1  pool identifier (comma separated list)
#;
function odsel_sim() {
    local x="${1//[[:space:]]/}"
    [[ -z $1 ]] && {
        _emsg "${FUNCNAME}: pool identifier(s) not set"
        return 1
    }
    _psplit "$x"
    for x in ${SPLIT_STRING[@]}; do
        odsel_ispool "$x" && {
            _emsg "${FUNCNAME}: cannot run a simulation on an already existing pool"
            break
        } || {
            odsel_new "${x}[]" \
                && i9kgoo_sim_metabase_xml "$x" \
                && i9kgoo_pcache "$x" \
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
# @desc A keyword reserve for "export" functionality
#;
function __odsel_export_p() {
    _qsplit "$1" && {
        local i=("${SPLIT_STRING[@]}")
        _omsg "${FUNCNAME}: $(_emph "reserved :: ${#i[@]}")"
        return 0
    }
    return 1
}

#;
# @desc A keyword reserve for "import" functionality
#;
function __odsel_import_p() {
    _qsplit "$1" && {
        local i=("${SPLIT_STRING[@]}")
        _omsg "${FUNCNAME}: $(_emph "reserved :: ${#i[@]}")"
        return 0
    }
    return 1
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
    _psplit "${1//[[:space:]]/}"
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
# @desc The prototype for "value" definition in odsel
# @ptip $1  Left side
# @ptip $2  Right side
#;
function odsel_dval() {
    local x="$1" y="${2//[[:space:]]/}"
    _omsg "$(_emph DVAL): name  = $x"
    _omsg "$(_emph DVAL): value = $y"
    [ "$x" = "${y/:*/}" ] && {
        _omsg "* -> properly defined: $x"
    } || _emsg "${FUNCNAME}: not equal"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Remove a series of pools from the runspace
# @ptip $1  comma separated list of pool names
#;
function odsel_del() {
    local x y a
    _psplit "${1//[[:space:]]/}"
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
# @desc Completely redefine odsel "step" - related grammar elements using an odsel
#       expression, making the requirement of XML / * redundant for step - description.
#       This is a silent function generator.
# @ptip $1  The odsel grammar - modifier definition expression.
#;
function odsel_gscoil() {
    local x="${1//[[:space:]]/}"
    [[ "$x" =~ :\[([[:alnum:]_]*)\]=\>@\{([,[:alnum:]_]*)\}:\{([,[:alnum:]_]*)\}([:\>,\|[:alnum:]_-]*)\; ]] && {
        [[ ${x#*${BASH_REMATCH[4]}} = \; ]] && {
            local   r="_odsel_gscoil_$(odsel_gph ${BASH_REMATCH[1]})" n= \
                    s=(${BASH_REMATCH[2]//,/ }) f=(${BASH_REMATCH[3]//,/ }) l=() \
                    k= v=
            _isfunction "$r" && {
                _emsg   "${FUNCNAME}: event paths for [${BASH_REMATCH[1]}]:" \
                        " * : are already defined in coil: $(_dotstr ${r##*_})"
                return 1
            }
            k=$(v=$RANDOM$RANDOM
                for x in ${f[@]}; do
                    ((_$v_$x)) && { printf "%s\n" $x; return 1; } || ((_$v_$x=1))
                done)   && v="${BASH_REMATCH[4]:1}|" \
                        || { _emsg "${FUNCNAME}: $k is defined more than once"; return 1; }
            while [[ "$v" =~ ^([[:alnum:]_]*):([[:alnum:]_]*)-\>([[:alnum:]_]*)\| 
                  || "$v" =~ ^([[:alnum:]_]*):([[:alnum:]_]*)\| ]]; do
                ((${#BASH_REMATCH[@]} == 4)) && {
                    local a=-1 b=-1
                    for x in ${!f[@]}; do
                        [[ ${f[$x]} == ${BASH_REMATCH[2]} ]] && a=$x
                        [[ ${f[$x]} == ${BASH_REMATCH[3]} ]] && b=$x
                    done
                    (( ((a<0)) || ((b<0)) )) \
                        && _emsg "${FUNCNAME}: $(_emph ${BASH_REMATCH[1]}) is invalid" || {
                        ((a<b)) && {
                            n=; for((x=a;x<=b;x++)); do n+="${f[$x]} "; done
                            l+=("${BASH_REMATCH[1]} ${n% }")
                            v="${v#*${BASH_REMATCH[3]}|}"
                        } || _emsg "${FUNCNAME}: $(_emph ${BASH_REMATCH[1]}) is inversed"
                    }
                } || {
                    l+=("${BASH_REMATCH[1]} ${BASH_REMATCH[2]}")
                    v="${v#*${BASH_REMATCH[2]}|}"
                }
                ((${#SHELLAPI_ERROR[@]})) && return 1 || :
            done
            [[ -z $v ]] || {
                _emsg   "${FUNCNAME}: invalid expression:" \
                        "in : ... ${x:0:$((${#x}/3))} ..." \
                        "** : ... ${v:0:$((${#v}/2))} ..."
                return 1
            }
        } || {
            v="${x#*${BASH_REMATCH[4]}}"
            _emsg   "${FUNCNAME}: invalid expression:" \
                    "in : ... ${x:0:$((${#x}/3))} ..."
                    "** : ... ${v:0:$((${#v}/2))} ..."
            return 1
        }
    } || {
        _emsg "${FUNCNAME}: invalid expression:" "** ${x:0:$((${#x}/3))}..."
        return 1
    }
    eval "$r() { case \"\$1\" in
        $(for x in ${!l[@]}; do
            printf  "%s) printf \"%s\\\\n\" ;;\n" \
                    "${l[$x]/ */}" "${l[$x]#* }"
          done) '') printf \"${f[@]}\\\\n\" ;; *) return 1 ;; esac; }"
}

#;
# @desc Process a comma separated list of odsel "variable" assignments, whether
#       for a single value or containing nested lists ( variable = { , , , } )
# @ptip $1  The part of an odsel expression containing said statement.
#;
function __odsel_vdef_p() {
    local x="$1," y z n m b
    while [[ ${x#"${x%%[![:space:]]*}"} =~ ^([[:alnum:]_]*)[[:space:]]*=[[:space:]]*(.*) ]]; do
        n="${BASH_REMATCH[1]}"; m="${BASH_REMATCH[2]}"
        [[ $m =~ \"([^\"]*)\"[[:space:]]*,|\
\'([^\']*)\'[[:space:]]*,|\
([[:alnum:]_/:\.]*)[[:space:]]*,|\
(\{[\'\"[:space:][:alnum:]_/:,\.\;\{\}]*\})[[:space:]]*, ]] \
            && y="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}" \
            || return 1
        if [[ ${y:0:1} = { ]]; then
            z="${y:1:$((${#y}-2))},"
            while [[ ${z#"${z%%[![:space:]]*}"} =~ \
^\"([^\"]*)\"[[:space:]]*,|\
^\'([^\']*)\'[[:space:]]*,|^([[:alnum:]_/:\.]*)[[:space:]]*, ]]; do
                b="${BASH_REMATCH[1]}${BASH_REMATCH[2]}${BASH_REMATCH[3]}"
                z="${z#*$b*,}"
                _omsg "$(_emph def) : $n :: $b"
            done
        else _omsg "$(_emph def) : $n : $y"; fi    
        x="${x#*$y*,}"
    done
    [[ -z $x ]] || {
        _emsg "${FUNCNAME}: expression cannot be processed:$x"
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Generate a callback out of an odsel i9kg extraction expression. The output
#       of the callback is logged at a progress lock, check for its hash id within
#       the shellrun folder in order to find it.
# @ptip $1  Callback name within odsel instruction flow.
# @ptip $2  The odsel i9kg extraction expression.
# @note This is a prototype, towards the final step and it is hardwired to :code
#       from the default odsel coil (the presets as defined within odsel.config.xml).
#;
function odsel_dcbk() {
    _isfunction _fnop_$1 && _emsg "${FUNCNAME}: already defined: $1()" || {
        odsel_getcbk "$2" _fnop_$1
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Another callback generator
# @ptip $1  An odsel expression.
# @ptip $2  Callback name (optional).
#;
function odsel_getcbk() {
    local x=($(_odsel_i9kg_header "$1")) y= z= d= g= f=() a= n= h=() m=$(_uuidg)
    ODSEL_CBKDEP=()
    i9kgoo_load "$1" \
        && y="__i9kg_rcache_${x[2]}[$(odsel_depquery "${x[4]}" "rpli" "${x[2]}")]" \
        && a="__i9kg_rcache_${x[2]}[$(odsel_depquery "${x[4]}" "dbld" "${x[2]}")]" \
        && z="$(__odsel_i9kgi_p "$1;" "${x[2]}")" && {
            n="${2:-_fnoph_${x[5]}}"
            for d in ${!a}; do ODSEL_CBKDEP+=("_fnoph_${x[5]}"); done
            for d in ${!y}; do
                g=${x[5]}
                _isfunction _get_${x[5]} \
                    || eval "_get_${x[5]}() { odsel_sppx $d ${x[3]} $m; }"
                h+=(_get_${x[5]})
            done
            for d in $z; do
                while read -r d; do
                    f+=("$d")
                done< <(d="__i9kg_rcache_${x[2]}[$d]"; printf "%s\n" "${!d}")
            done
            _isfunction $n || {
                fnapi_fnp_write $n f h "${I9KG_UTILSPACE[$LOCATION]}/$m/source"
                eval "$n=\"${1//[[:space:]]/}\""
            }
        } || {
            y=$?
            x="${1//[[:space:]]/}"
            _emsg  "${FUNCNAME}: odsel callback failure:"
            (($y == 2)) && _emsg "* grammar is undefined for pool: $(_emph ${x[1]})"
            _emsg  "* ${x:0:$((${#x}/2))}..."
        }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Extract name / version information out of a tarball
# @ptip $1  path to the tarball or name of the tarball
#;
function odsel_targuess() {
    ODSEL_TARGUESS=()
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
    ODSEL_TARGUESS=("$n" "$s" "$v" "$i" "$(_hsof "$1")")
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
            e="${ODSEL_DGET} $1"
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
    _psplit "${1//[[:space:]]/}"
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
            fnapi_genblock "$o" "requesting: $x" \
                FNPREP_ARRAY "requesting: $x" fatal > "$f"
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
    ODSEL_TARCOIL=() ODSEL_TARGUESS=()
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
            && ODSEL_TARCOIL="snapshot/${ODSEL_TARGUESS[0]}:${ODSEL_TARGUESS[2]#*.}" \
            || ODSEL_TARCOIL="payload/${ODSEL_TARGUESS[0]}:${ODSEL_TARGUESS[2]}"
        ODSEL_TARCOIL=("$ODSEL_TARCOIL" "${ODSEL_TARGUESS[1]}" "${ODSEL_TARGUESS[4]}")
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
    _psplit "${x//[[:space:]]/}"
    for x in ${!SPLIT_STRING[@]}; do
        _omsg "$(_emph delc): deleting i9kg cache for: $(_emph ${SPLIT_STRING[$x]})"
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
