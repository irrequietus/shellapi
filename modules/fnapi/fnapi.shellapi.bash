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
# @desc The init implementation for this module
#;
function fnapi_init() {
    FNAPI_CHECKSUM="${SHELLAPI_HASH_MODES}"
    FNAPI_SKIP=3
    FNAPI_TIMER="0.2"
    _FNAPI_FHASH=0
    _FNAPI_FNAME=2
    _FNAPI_FARGS=1
    SHELLAPI_HASH_MODES="${FNAPI_CHECKSUM}"
    SHELLAPI_HASH="${SHELLAPI_HASH_MODES}"
    case "${FNAPI_CHECKSUM}" in
        sha384sum | sha512sum)
            FNAPI_HASH_LEVEL=2
        ;;
        sha224sum | sha256sum)
            FNAPI_HASH_LEVEL=1
        ;;
        sha1sum | md5sum)
            FNAPI_HASH_LEVEL=0
        ;;
        *)
            _fatal "${FUNCNAME}: not supported ${FNAPI_CHECKSUM}"
        ;;
    esac
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
            printf "${x/ */}"
            return
     } || _emsg "${FUNCNAME}: called without arguments"
    ! ((${#SHELLAPI_ERROR[@]}))
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
        local _cdir=\"\$(pwd)\"
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
            cd \"\$_cdir\"
            rm -rf \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass\"
            printf \"pass: %%s\\\\n\" \"\$(date -R)\" >> \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr/timing.log\"
            mv  \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.inpr\" \\
                \"\${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass\"
            fnapi_showmsg
            _cmsg \"%s: \$(_dotstr \$f): is complete\"
            return
        } || {
            cd \"\$_cdir\"
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
        rm -rf \${I9KG_DEFS[\$_PROGRESS_LOCKS]}/\$f.pass
        _omsg \"\$(_emph \${FUNCNAME}): %s\$(_dotstr \$f): 0/$z\"\n" "$1" "$2"
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
    _omsg \"\$(_emph \${FUNCNAME}): \$(_dotstr \$f): $z/$z\"\n}\n" \
    "$1"
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
