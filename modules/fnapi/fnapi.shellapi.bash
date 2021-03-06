#!/bin/bash

# Copyright (C) 2009, 2010 - George Makrydakis <irrequietus@gmail.com>

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
# @desc The init handle for this module
#;
function fnapi_init() {
    export FNAPI_CHECKSUM="${SHELLAPI_HASH_MODES}"
    export FNAPI_SKIP=3
    export FNAPI_TIMER="0.2"
    export _FNAPI_FHASH=0
    export _FNAPI_FNAME=2
    export _FNAPI_FARGS=1
    export SHELLAPI_HASH_MODES="${FNAPI_CHECKSUM}"
    export SHELLAPI_HASH="${SHELLAPI_HASH_MODES}"
    case "${FNAPI_CHECKSUM}" in
        sha384sum | sha512sum)
            export FNAPI_HASH_LEVEL=2
        ;;
        sha224sum | sha256sum)
            export FNAPI_HASH_LEVEL=1
        ;;
        sha1sum | md5sum)
            export FNAPI_HASH_LEVEL=0
        ;;
        *)
            _fatal "${FUNCNAME}: not supported ${FNAPI_CHECKSUM}"
        ;;
    esac
    _wexp_this fnapi_schedule fnapi_deploy_schedule
}

#;
# @desc For a given PID (Process IDentifier), gather all child processes
# @ptip $1 parent PID
# @echo whitespace separated list of child pids
#;
function fnapi_cpid() {
    local p=($1) v i
    while : ; do
        v=$(ps -o pid --ppid ${p[${#p[@]}-1]})
        p[${#p[@]}]="${v#*PID}"
        [[ ${p[${#p[@]}-1]} ]] || {
            for i in ${p[@]}; do
                [[ $i ]] && printf "%d\n" $i
            done
            break
        }
    done
}

#;
# @desc Perform pid garbage collection on a particular function
# @ptip $1  Function lock hash
# @ptip $2  pid of the function in background operation
#;
function fnapi_pgc() {
    local   il_="${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr" \
            pl_="${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.pass" \
            fl_="${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.fail" \
            kl_="${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.kill" \
            i=0
    while kill -0  "$2" &>/dev/null; do
        [[ -d $il_ && ! -d $kl_ ]] || {
            for i in $(fnapi_cpid $2); do
                kill $i
            done &> /dev/null
            [[ -d $il_ ]] && {
                [[ -d $pl_ ]] &&  {
                    cat "$pl_/timing.log" > "$kl_/timing.log"
                    rm -rf "$pl_"
                }
                cat "$il_/timing.log" >> "$kl_/timing.log"
                printf "kill: %s\n" "$(date -R)" >> "$kl_/timing.log"
                rm -rf "$il_"
                return
            }
        }
        sleep $FNAPI_TIMER
    done
    [[ -d $pl_ ]] && rm -rf "$pl_"
    [[ -d $il_ ]] && mv "$il_" "$pl_"
}

#;
# @desc Check whether foreground execution of the wrapped instruction
#       sequence is allowed or not. The sequence is identified by the
#       FNAPI header hash representing its lock.
# @ptip $1  FNAPI header hash representing function lock.
# @retv 0/?
#;
function fnapi_allow_single() {
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.kill ]] && return 4
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inqe ]] && return 3
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr ]] && return 2
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.fail ]] && return 1
    mkdir -p "${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.single"
}

#;
# @desc Check whether background execution of the wrapped instruction
#       sequence is allowed or not. The sequence is identified by the
#       FNAPI header hash representing its lock.
# @ptip $1  FNAPI header hash representing function lock.
# @retv 0/?
#;
function fnapi_allow_parallel() {
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.kill ]] && return 4
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inqe ]] && return 3
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr ]] && return 2
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.fail ]] && return 1
    mkdir -p "${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.parallel"
}

#;
# @desc Check whether fnapi allows the wrapped instruction sequence to be
#       executed or not. The sequence is identified by the FNAPI header
#       hash representing its lock.
# @ptip $1  FNAPI header hash representing function lock.
# @retv 0/?
#;
function fnapi_allows() {
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.kill ]] && return 4
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inqe ]] && return 3
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.fail ]] && return 1
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.parallel ]] && {
        rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.parallel" \
            &> /dev/null || return 2
        return 0
    }
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.single ]] && {
        rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr/.single" \
            &> /dev/null || return 2
        return 0
    }
    [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr ]] && return 2 || {
        mkdir "${I9KG_DEFS[$_PROCESS_LOCKS]}/$1.inpr"
    } &> /dev/null && return 0 || return 3
    return 1
}

#;
# @desc Check whether fnapi allows the wrapped instruction sequence to be
#       executed or not. The sequence is identified by the FNAPI header
#       hash representing its lock. This is the version for PROGRESS locks.
# @ptip $1  FNAPI header hash representing function lock.
# @retv 0/?
#;
function fnapi_allows_flock() {
    [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.kill ]] && return 4
    [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inqe ]] && return 3
    [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.fail ]] && return 1
    [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inpr ]] && return 2
    mkdir "${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inpr"
    printf "inpr: %s\n" "$(date -R)" >> \
        "${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inpr/timing.log"
}

#;
# @desc Check whether the hash id you are checking for allows progress
#       by asserting progress status, this time including [pass] as
#       significant.
# @ptip $1  lock hash id
#;
function fnapi_allows_go() {
    [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.pass ]] || { 
        [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.kill ]] && return 4
        [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inqe ]] && return 3
        [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.inpr ]] && return 2
        [[ -d ${I9KG_DEFS[$_PROGRESS_LOCKS]}/$1.fail ]] && return 1
        return 5
    }
}

#;
# @desc Launch a function with its arguments through fnapi in parallel mode
# @ptip ${1}    The name of the function to lanuch
# @ptip ${@:2}  Arguments that must be passed to the function
#;
function fnapi_plaunch() {
    fnapi_makeheader "${1}" "${@:2}"
    local fheader="${FNAPI_HEADER[$_FNAPI_FHASH]}"
    fnapi_allow_parallel "${fheader}" && {
        $1 "${@:2}" &
        fnapi_pgc "$fheader" $! &
    } || _wmsg "$FUNCNAME [$1]: ${FNAPI_MSGL[$?]}"
}

#;
# @desc Launch a function with its arguments through fnapi in sequel mode
# @ptip ${1}    The name of the function to lanuch
# @ptip ${@:2}  Arguments that must be passed to the function
#;
function fnapi_slaunch() {
    fnapi_makeheader "${1}" "${@:2}"
    local fheader="${FNAPI_HEADER[$_FNAPI_FHASH]}"
    fnapi_allow_single "${fheader}" && {
        $1 "${@:2}"
        (($?)) && {
            rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.fail"
            [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.inpr ]] \
                && mv   "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.inpr" \
                        "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.fail"
            return 1
        } || {
            rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.pass"
            [[ -d ${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.inpr ]] \
                && mv   "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.inpr" \
                        "${I9KG_DEFS[$_PROCESS_LOCKS]}/${fheader}.pass"
            return 0
        }
    } || _wmsg "$FUNCNAME [$1]: ${SHELLAPI_ILMSG[$?]}"
}

#;
# @desc     Write a function according to _fnp_* specification requirements
# @ptip $1  Assignable function name for the _fnp_* generated function.
# @ptip $2  Array containing sequence of commands comprising the nested function block.
# @ptip $3  Array containing the _fnp_* dependencies of the generated function call (hash ids).
# @ptip $4  Run location of the generated function.
# @ptip $5  An integer representing the "weight", a factor related to the time necessary
#           for the function to complete.
#;
function fnapi_fnp_write() {
    ! _isfunction "$1" && {
        eval "$1(){ local _d_=($(_for_each $3 printf "%s\n"))
        local _f_=$(f=$(_for_each $2 printf "%s\n" | ${FNAPI_CHECKSUM}); printf "${f/ */}")
        [[ \$1 = path ]] && printf \"%s\n\" \"${4:-.}\" || {
        [[ \$1 = csec ]] && printf \"%d\" ${5:-0} || {
        [[ \$1 = preq ]] && printf \"%s\n\" \"\${_d_[@]}\" || {
            fnapi_allows_flock \$_f_ && { {
            pushd \"${4:-.}\" &> /dev/null && \\
            $(_for_each $2 printf "%s && \\\\\n")
            popd &> /dev/null || ! :
        } &> \${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$_f_.inpr/output.log && fnapi_relock progress/\$_f_ pass \\
            || fnapi_relock progress/\$_f_ fail; }; }; }; }; }" &> /dev/null && export -f $1 \
            || { _emsg "${FUNCNAME}: could not generate _fnp_*: $1"; }
    } || _emsg "${FUNCNAME}: function already defined: $1"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc         Rewrite the dependency list of a _fnp_* specification compliant function.
#               Take note that the function must exist in order to be "rewritten".
# @ptip $1      The name of an already defined _fnp_* function.
# @ptip ${@:2}  Sequence of the new dependencies (hash ids).
#;
function fnapi_fnp_deprw() {
    local t="$1"
    _isfunction $t && {
        t="$(type $t | tail --lines=+2)"
        eval "${t/local _d_=(*)/local _d_=(${@:2})}" &> /dev/null \
            || { _emsg "${FUNCNAME}: could not rewrite dependencies for _fnp_*: $1"; eval "$t"; }
    } || _emsg "${FUNCNAME}: cannot rewrite an undefined function: $1"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Sort a list of _fnp_* compliant functions by csec "weight factor"
# @ptip $2  Whitespace separated list.
# @note The csec factor is always a positive integer or zero (csec >= 0).
#;
function fnapi_by_csec() {
    local x y=() n=
    for x in $@; do
        n=$($x csec || printf "0" )
        y[$n]="${y[$n]} $x"
    done
    printf "%b\n" ${y[@]}
}

#;
# @desc Create a FNAPI_HEADER array for a given function and parameters combination;
#       the function must exist or it raises fatal
# @ptip $@ function to call, along with the parameters it is to be called with.
#;
function fnapi_makeheader() {
    (($#)) && {
        _isfunction "$1" && {
            FNAPI_HEADER=("$(printf "%s\n" "${@}" | \
                ${FNAPI_CHECKSUM})" "$(($#-1))" "${@}") i=0
            FNAPI_HEADER[0]="${FNAPI_HEADER[$_FNAPI_FHASH]/ */}"
            return 0
        } || _fatal "${FUNCNAME}: $1 does not exist"
     } || _fatal "${FUNCNAME}: called without arguments"
}

#;
# @desc Return a FNAPI_HEADER array for a given function and parameters combination;
#       the function may also not exist in current running space.
# @ptip $@ function to call, along with the parameters it is to be called with.
#;
function fnapi_dumpheader() {
    (($#)) && {
            local x="$(printf "%s\n" "${@}" | ${FNAPI_CHECKSUM})"
            printf "%s\n" "${x/ */}"
     } || return 1
}

#;
# @desc Explicitely relock a progress / process lock of [inpr] status
# @ptip $1  The lock format: process/<hash> or progress/<hash>
# @ptip $2  The "relocked" target (pass|fail|inqe|kill)
#;
function fnapi_relock() {
    (($# == 2)) && {
        case "${1}" in
            process/*)

                    rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.pass"
                    printf  "${2:-fail}: %s\n" "$(date -R)" >> \
                            "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.inpr/timing.log"
                    mv  "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.inpr" \
                        "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.${2:-fail}"
                ;;
            progress/*)

                    rm -rf "${I9KG_DEFS[$_PROGRESS_LOCKS]}/${1#*/}.pass"
                    printf  "${2:-fail}: %s\n" "$(date -R)" >> \
                            "${I9KG_DEFS[$_PROGRESS_LOCKS]}/${1#*/}.inpr/timing.log"
                    mv  "${I9KG_DEFS[$_PROGRESS_LOCKS]}/${1#*/}.inpr" \
                        "${I9KG_DEFS[$_PROGRESS_LOCKS]}/${1#*/}.${2:-fail}"
                ;;
                *)
                    _emsg "${FUNCNAME}: unknown lock category"
                ;;
        esac
    }
}

#;
# @desc Unlock function locks (progress / process)
# @ptip $1  unlocking in the format of [process|progress]/<hash>.<ext|*>
#;
function fnapi_unlock() {
    (($# == 1)) && {
        case "${1}" in
            progress/*)
                    rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.*"
                ;;
            process/*)
                    rm -rf "${I9KG_DEFS[$_PROCESS_LOCKS]}/${1#*/}.*"
                ;;
                *)
                    _emsg "${FUNCNAME}: unknown lock category"
                ;;
        esac
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}


#;
# @desc Convert the FNAPI_HEADER array into part of a JSON object; the
#       entries in this case may be multiple (see the skip factor)
# @ptip none, uses the contents of FNAPI_HEADER array.
# @prod dev-only
#;
function fnapi_to_json() {
    local i
    printf "  {\n   \"name\" : \"%s\",\n" "${FNAPI_HEADER[$_FNAPI_FNAME]}"
    printf "   \"hvalue\" : \"%s\",\n   \"args\" : [\n" \
        "${FNAPI_HEADER[$_FNAPI_FHASH]}"
    for((i=$FNAPI_SKIP;i<$((${FNAPI_HEADER[$_FNAPI_FARGS]}+2));i++)); do
        printf "      \"%s\",\n" "${FNAPI_HEADER[$i]}"
    done
    printf "      \"%s\"\n   ],\n" \
    "${FNAPI_HEADER[$((${#FNAPI_HEADER[@]} > $(($_FNAPI_FARGS+1)) \
        ? $((${#FNAPI_HEADER[@]}-1)) : ${#FNAPI_HEADER[@]}))]}"
    printf "   \"status\" : \"pass\",\n"
    printf "   \"started\" : \"%s\",\n" "-TODO-"
    printf "   \"stopped\" : \"%s\"\n" "-TODO-"
    printf "  }"
}

#;
# @desc Convert the FNAPI_HEADER array into a XML document; the entries
#       in this case may be multiple (see the skip factor)
# @ptip none, uses the contents of FNAPI_HEADER array as created
#       by previous call of fnapi_makeheader
# @prod dev-only
#;
function fnapi_to_xml() {
    local i
    printf " <function name=\"%s\"
    hvalue=\"%s\"
    started=\"-TODO-\"
    stopped=\"-TODO-\"
    status=\"pass\">\n" \
    "${FNAPI_HEADER[$_FNAPI_FNAME]}" "${FNAPI_HEADER[$_FNAPI_FHASH]}"
    for((i=$FNAPI_SKIP;i<$((${FNAPI_HEADER[$_FNAPI_FARGS]}+2));i++)); do
        printf "   <arg value=\"${FNAPI_HEADER[$i]}\"/>\n"
    done
    ((${#FNAPI_HEADER[@]} > $(($_FNAPI_FARGS+1)))) \
        && printf "   <arg value=\"%s\"/>\n" \
           "${FNAPI_HEADER[$((${#FNAPI_HEADER[@]}-1))]}"
    printf " </function>\n"
}

#;
# @desc Generate a function block wrapper around a series of successive
#       commands stored as strings in a bash array. A true / false check
#       is performed when these commands are executed within the wrapper
# @ptip $1  Function name to assign to the wrapper
# @ptip $2  Message prefix to present when informing about progress
# @ptip $3  Array / variable in which the command sequence is found.
# @ptip $4  Identifier appearing in the warning message if attempting to run again
#           after a failure. If this is active, it overrides $1
# @note This function treats newline whitespace within the variables as significant.
#;
function fnapi_genblock() {
    (($# < 3)) && _fatal "${FUNCNAME}: wrong number of arguments: $#"
    local p
    printf "function %s() {
    fnapi_makeheader \"\${FUNCNAME}\" \"\${@}\"
    local f=\"\${FNAPI_HEADER[\$_FNAPI_FHASH]}\"
    fnapi_allows_flock \"\$f\" && {
        pushd . &> /dev/null
        rm -rf \${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass
        _nmsg \"%s: \$(_dotstr \$f): in progress\"
        printf \"inpr: %%s\\\\n\" \"\$(date -R)\" >> \\
            \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing.log\"
        {\n" "$1" "$2"
    for p in $(_xsof $3); do
        while read -r p; do
            printf "            %s && \\\\\n" "${p}"
        done< <(p="$3[$p]"; printf "%s\n" "${!p}")
    done
    printf "            : || ! : 
        } &> \${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/output.log && {
            popd &> /dev/null
            rm -rf \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass\"
            printf \"pass: %%s\\\\n\" \"\$(date -R)\" >> \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing.log\"
            mv  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr\" \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass\"
            fnapi_showmsg
            _cmsg \"%s: \$(_dotstr \$f): is complete\"
            return
        } || {
            popd &> /dev/null
            rm -rf \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.fail\"
            printf \"fail: %%s\\\\n\" \"\$(date -R)\" >> \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing.log\"
            mv  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr\" \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.fail\"
            _fail \"%s: \$(_dotstr \$f): has failed\"
            _%s \"in : %s\"
            return 1
        }
    } || _wmsg \"%s: \
\${FNAPI_MSGL[((\$((f=\$?))>\${#FNAPI_MSGL[@]}?\$((\${#FNAPI_MSGL[@]}-1)):\$f))]}: \
\$(_dotstr \${FNAPI_HEADER[\$_FNAPI_FHASH]})\" \n}\n" \
    "$2" "${4:-"\${FUNCNAME}"}" "${5:-wshow}" \
    "${4:-"\${FUNCNAME}"}" "${4:-"\${FUNCNAME}"}"
}

#;
# @desc Create an instruction cascade out of an array containing an instruction
#       per array variable member.
# @ptip $1  Function name to assign to the wrapper
# @ptip $2  Message prefix to present when informing about the function
# @ptip $3  Array / variable in which a command sequence is found.
# @note This function treats newline whitespace within the variables as significant.
#;
function fnapi_gencascade() {
    local x y z=$(_asof $3) a=
    [[ -z $2 ]] && a="$2: "
    printf "function %s() {
    fnapi_makeheader \"\${FUNCNAME}\" \"\${@}\"
    local f=\"\${FNAPI_HEADER[\$_FNAPI_FHASH]}\"
    fnapi_allows_flock \"\$f\" && {
        rm -rf  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\"\$f.pass
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\"\$f.inpr/*.log
        pushd . &> /dev/null
        _omsg \"\$(_emph \${FUNCNAME}): %s\$(_dotstr \$f): 0/$z\"\n" "$1" "$a"
    for x in $(_xsof $3); do
        printf "        {\n"
        printf "            _nmsg \"\$(_emph \"\${FUNCNAME}|%s\"): inpr\"
            printf \"inpr: %%s\\\\n\" \"\$(date -R)\" >> \\
            \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing-%s.log\"
            {\n" "$x" "$x"
        while read -r y; do
            printf "                %s && \\\\\n" "${y}"
        done< <(y="$3[$x]"; printf "%s\n" "${!y}")
        printf "                : || ! :
            } &> \${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/output-%s.log && {
                _cmsg \"\$(_emph \"\${FUNCNAME}|%s\"): pass\"
                printf \"pass: %%s\\\\n\" \"\$(date -R)\" >> \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing-%s.log\"
            } || {
                _fail \"\$(_emph \"\${FUNCNAME}|%s\"): fail\"
                printf \"fail: %%s\\\\n\" \"\$(date -R)\" >> \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing-%s.log\"
                ! :
            }\n" "$x" "$x" "$x" "$x" "$x"
        printf "        } &&"
    done
    printf "    : || {
            popd &> /dev/null
            _emsg \"\$(_emph \"\${FUNCNAME}|$z\"): \$(_dotstr \$f)\"
            mv  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr\" \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.fail\"
            _fatal \"instruction cascade failure\"\n        }
    } || {
        _wmsg \"%s: \
\${FNAPI_MSGL[((\$((f=\$?))>\${#FNAPI_MSGL[@]}?\$((\${#FNAPI_MSGL[@]}-1)):\$f))]}: \
\$(_dotstr \${FNAPI_HEADER[\$_FNAPI_FHASH]})\"
        return \$f
    }
    popd &> /dev/null
    mv  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr\" \\
        \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass\"
    _omsg \"\$(_emph \${FUNCNAME}): \$(_dotstr \$f): $z/$z\"\n}\n" \
    "$1"
}

#;
# @desc A task scheduler prototype implemented in pure GNU bash. This function is
#       designed to calculate the scheduling for function "wrappers" as presented
#       within the array which represents the tasks along with their dependencies.
# @ptip $1  The array variable containing the task set representation.
# @ptip $2  The array variable where to store the result (optional, defaults to
#           ODSEL_FNSCHEDULE).
#;
function __fnapi_schedule_p() {
    eval "local g=(\"\${$1[@]}\")"
    local a= x= r= y= j= s= g1=() g2=()
    ODSEL_FNSCHEDULE=()
    for x in ${!g[@]}; do
        a=(${g[$x]#*[[:space:]]})
        r="${g[$x]/[[:space:]]*/}"
        ((_fl_$r)) \
            || ((_fl_$r=${#g1[@]}+1))
        g1[_fl_$r]="$r"
        g2[_fl_$r]="${a[@]}"
        for y in ${a[@]}; do
            ((_fl_$y)) \
                || ((_fl_$y=${#g1[@]}+1))
            g1[_fl_$y]="$y"
        done
    done
    r=${#g1[@]}
    for x in ${!g1[@]}; do
        [[ -z ${g2[$x]} ]] && {
            s+=("${g1[$x]}")
            unset -v _fl_${g1[$x]} g1[$x]
        }
    done
    while ((${#s[@]})) ; do
        j=${s[${#s[@]}-1]}
        unset -v s[${#s[@]}-1]
        ODSEL_FNSCHEDULE+=($j)
        for x in ${!g1[@]}; do
            y=(${g2[$x]})
            for i in ${!y[@]}; do
                [[ ${y[i]} = $j ]] \
                    && unset -v y[i]
            done
            ((${#y[@]})) && g2[$x]="${y[@]}" || {
                s+=(${g1[$x]})
                unset -v _fl_${g1[$x]} g1[$x] g2[$x]
            }
        done
    done
    ((${#g1[@]})) && {
        g1=(${g1[*]})
        _emsg   "${FUNCNAME}(): a cyclic event sequence has been detected" \
                "* : cycle seems to start from: ${g1[0]}" \
                "* : would have cycled at  : $((r-${#g1[*]}))/$r in sequence"
        return 1
    }
    [[ -z $2 ]] \
        || eval "$2=(\"\${ODSEL_FNSCHEDULE[@]}\"); ODSEL_FNSCHEDULE=()"
}


#;
# @desc A deploy function for the schedule produced by __fnapi_schedule_p()
# @ptip $1  The array variable containing the task set representation.
# @ptip $2  A split factor ( + n to add when parallel / serial, defaults to 0 ).
# @note Complete the wiring after testing.
#;
function __fnapi_deploy_schedule_p() {
    local x n m l z=${2:-0}
    _isint $z && {
         (($z)) && x=plaunch || x=slaunch
         __fnapi_schedule_p $1 && {
            for n in ${!ODSEL_FNSCHEDULE[@]}; do
                # wiring up here once +
                m=(${ODSEL_FNSCHEDULE[$n]})
                while ((${#m[@]})); do
                    l=0
                    for n in ${!m[@]}; do
                        (($((l++))>z)) && break
                        printf "%s " ${m[$n]}
                        unset m[$n]
                    done
                    echo
                done
            done
         } || _emsg "${FUNCNAME}: cannot deploy function sequence: $1"
    } || _emsg "${FUNCNAME}: \"$z\" is not a number, cannot process sequence: $1"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Check for a progress lock (inpr, pass, fail, inqe)
# @ptip $1 name of the function; defaulting to null returns whether
#       all functions in process (inpr)
#;
function fnapi_pstatus() {
    FNAPI_STATUS=()
    local v="${1:-*.inpr}"
    shopt -s nullglob dotglob
    pushd "${I9KG_DEFS[$_PROCESS_LOCKS]}" &> /dev/null && {
        eval "FNAPI_STATUS=(${v})"
        v=${#FNAPI_STATUS[@]}
        popd &> /dev/null
    } || _fatal "${FUNCNAME}: locks directory does not exist"
    shopt -u nullglob dotglob
    (($v > -1))
}

#;
# @desc Get the number of locks of a particular type, by default the inpr
#       locks.
# @ptip $1  a string expression related to locks, defaults to *.inpr
#;
function fnapi_psn() {
    fnapi_pstatus "$1" \
        && printf "%s\n" "${#FNAPI_STATUS[@]}" \
        || _emsg "${FUNCNAME}: irrecoverable error (fnapi_pstatus)"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Get the lock type for a given hash
# @ptip $1  hash representing the lock
#;
function fnapi_getlock() {
    fnapi_pstatus "$1.*"
    ((${#FNAPI_STATUS[@]} <= 1)) \
        && printf "%s\n" "${FNAPI_STATUS[0]}" \
        || _emsg "${FUNCNAME}: $1 is multilocked"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Get the lock type for a particular function call (arguments
#       included in the internally generated hash)
# @ptip $@  function call (function + arguments)
#;
function fnapi_getlock_dh() {
    fnapi_pstatus "$(fnapi_dumpheader "$@").*"
    ((${#FNAPI_STATUS[@]} <= 1)) \
        && printf "%s\n" "${FNAPI_STATUS[0]}" \
        || _emsg "${FUNCNAME}: $1 is multilocked"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Identify all progress locks (inpr, pass, fail inqe) and store them
#       into their respective report arrays.
#;
function fnapi_pstatall() {
    FNAPI_SINPR=()
    FNAPI_SPASS=()
    FNAPI_SINQE=()
    FNAPI_SFAIL=()
    fnapi_pstatus "*" && {
        local i
        for i in ${!FNAPI_STATUS[@]}; do
            case "${i##*.}" in
                inpr) FNAPI_SINPR[${FNAPI_SINPR[@]}]=${FNAPI_STATUS[$i]} ;;
                pass) FNAPI_SPASS[${FNAPI_SPASS[@]}]=${FNAPI_STATUS[$i]} ;;
                fail) FNAPI_SFAIL[${FNAPI_SFAIL[@]}]=${FNAPI_STATUS[$i]} ;;
                inqe) FNAPI_SINQE[${FNAPI_SINQE[@]}]=${FNAPI_STATUS[$i]} ;;
            esac
        done
    } || ! :
}

#;
# @desc Clean up locks that are not of use anymore
# @ptip $1  The type of lock to clean up. Defaults to "fail"
#;
function fnapi_flush() {
    local x="${1:-fail}"
    case "$x" in
        inpr|pass|fail|inqe)
            pushd "${I9KG_DEFS[$_PROCESS_LOCKS]}" &> /dev/null && {
                rm -rf *.$x
                pushd "${I9KG_DEFS[$_PROGRESS_LOCKS]}" &> /dev/null && {
                    rm -rf *.$x
                } || _fatal "${FUNCNAME}: progress locks directory does not exist"
            } || _fatal "${FUNCNAME}: process locks directory does not exist"
            { popd; popd; } &> /dev/null
            ;;
        *)
            _emsg "${FUNCNAME}: invalid request: $x"
            return 1
    esac
}

#;
# @desc Push a fnapi message to the FNAPI_MSG array
# @ptip $1  message to push to the array
#;
function fnapi_msg() {
    FNAPI_MSG[${#FNAPI_MSG[@]}]="$1"
}

#;
# @desc Present messages stored into FNAPI_MSG arrays when executing a block
#       through an fnapi_genblock function. The function also takes into
#       account SHELLAPI_ERROR messages as well and raises _fatal if needed.
# @note The messages appear always AFTER the block has been executed; they
#       are more of an aid for reading the logs than a log themselves.
#;
function fnapi_showmsg() {
    local x
    for x in ${!FNAPI_MSG[@]}; do
        _ckmsg "${FNAPI_MSG[@]}"
    done
    FNAPI_MSG=()
}
