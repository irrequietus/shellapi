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
# @desc The implementation for the init handle
#;
function i9kgoo_init() {
    I9KGOO_LIST=()
}

#;
# @desc Load a particular i9kg asset (file) or a series of i9kg assets
#       if passed as a comma separated list. This function either loads
#       the i9kg initializers from their odsel function caches or creates
#       and loads the necessary function cache depending on requirements.
# @ptip $1  comma separated list of i9kg assets to load
# @note An example of i9kg assets in list:
#
#       i9kgoo_load "gcc[],glibc[prime],binutils,foopack[mypool]"
#
#       letting X = {[], [prime], ''}
#           for every x  E X -> use the prime pool
#           for every x !E X -> use the pool described in x
# @note uses the default XML implementation of the i9kg spec
#;
function i9kgoo_load() {
    local x="${1//[[:space:]]/}," y l m n p r
    until [[ -z $x ]]; do
        [[ "${x/,*/}" =~ ([a-zA-Z0-9_-]*)\[([^[:space:]]*)\] ]] \
            && y=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]:-prime}") \
            || y=("${x/,*/}" "prime")
        y=($(_odsel_i9kg_header "${y[0]}[${y[1]}]"))
        eval "((__LOCK__i9kg_${y[$_I9KG_RHID]}))" \
        && _wmsg "reusing: ${y[$_I9KG_RLAY]}[${y[$_I9KG_POOL]}] -> $(_dotstr ${y[$_I9KG_RHID]})" || {
            m="${y[$_I9KG_RLAY]}[${y[$_I9KG_POOL]}]"
            r=$(_dotstr ${y[$_I9KG_RHID]})
            p=$(_dotstr ${y[$_I9KG_PHID]})
            eval "__LOCK__i9kg_${y[$_I9KG_RHID]}=1
                  ! ((__LOCK__pool_${y[$_I9KG_PHID]}))" && {
                _isfunction "_init_pool_${y[$_I9KG_PHID]}" || {
                    . "$POOL_RELAY_CACHE/functions/${y[$_I9KG_PHID]}.poolconf.bash" &> /dev/null || {
                        _emsg "@[${y[$_I9KG_POOL]}] : $p failed"
                        return 1
                    }
                    _eqmsg "@[${y[$_I9KG_POOL]}] : $p complete"
                }
                _init_pool_${y[$_I9KG_PHID]}
                eval "__LOCK__pool_${y[$_I9KG_PHID]}=1"
            }
            _ckmsg "requesting $m ?= $r"
            n="__pool_relay_${y[$_I9KG_PHID]}[$_FCACHE]"
            n="${!n}/__i9kg_init_${y[$_I9KG_RHID]}.odsel.bash"
            . "$n" &> /dev/null && {
                _isfunction "__i9kg_init_${y[$_I9KG_RHID]}" \
                    && "__i9kg_init_${y[$_I9KG_RHID]}" \
                    || {
                        _emsg "${FUNCNAME}: corrupt i9kg cache: $r"
                        return 1
                    }
            } || {
                l="__pool_relay_${y[$_I9KG_PHID]}[$_I9KG_SEEDS_XML]"
                l="${!l}/${y[$_I9KG_RLAY]}.i9kg.xml"
                [[ -e $l ]] && {
                    _nmsg "extracting $m -> $r"
                    odsel_xmla \
                        "$l" \
                        "__i9kg_rcache_${y[$_I9KG_RHID]}" \
                        && \
                    odsel_i9kg_objc \
                        "__i9kg_rcache_${y[$_I9KG_RHID]}" \
                        ${y[$_I9KG_RHID]} > "$n" \
                        && _eqmsg "$m: ok" \
                        || {
                            _emsg "${FUNCNAME}: $m: fail"
                            return 1
                        }
                } || {
                    _emsg "${FUNCNAME}: does not exist: $m"
                    return 1
                }
            }
        }
        [ "$x" = "${x#*,}" ] && {
            _emsg "${FUNCNAME}: invalid expression : $x"
            return 1
        } || x="${x#*,}"
    done
}

#;
# @desc Get a list of i9kg XML files inside a poolconf
# @ptip $1  The name of the pool whose i9kg XML files are requested,
#           defaults to "prime" when none is set.
# @ptip $2  A hash identifier for the pool hash; when set, it overrides
#           $1.
# @arrv I9KGOO_LIST : global array where the results of the operation
#       are stored
#;
function i9kgoo_list_xml() {
    I9KGOO_LIST=()
    local x="${2:-$(odsel_gph "${1:-prime}")}" y="${1:-prime}" z
    _isfunction "_init_pool_$x" || {
        . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash" &> /dev/null || {
            _emsg "${FUNCNAME}: @[$y]: cache $(_dotstr $x) not found"
            return 1
        }
    }
    [[ -z $2 ]] && _init_pool_$x
    y="__pool_relay_$x[$_I9KG_SEEDS_XML]"
    shopt -s nullglob dotglob
    pushd "${!y}" &> /dev/null && {
        I9KGOO_LIST=(*.i9kg.xml)
        I9KGOO_LIST=("${I9KGOO_LIST[@]/.i9kg.*/}")
        z=${#I9KGOO_LIST[@]}
        popd &> /dev/null
    } || _fatal "${FUNCNAME}: i9kg XML seeds directory not found"
    shopt -u nullglob dotglob
    (($z > -1))
}

#;
# @desc Create i9kg odsel caches for all the i9kg assets of a pool.
# @ptip $1  pool whose i9kg odsel caches must be initialized.
# @ptip $2  (optional) pool hash identifier, defaults to generating it
#           from $1
# @devs TODO: all odsel_gph calls can be optimized and eliminated when
#       using i9kgoo_* and other modules depending on this function
#       in "chained" mode.
#;
function i9kgoo_pcache() {
    local   x="${1:-prime}" y="${2:-$(odsel_gph "${1:-prime}")}"
    _isnullref "__pool_relay_$y" && {
        _isfunction _init_pool_$y && _init_pool_$y || {
            . "${POOL_RELAY_CACHE}/functions/$y.poolconf.bash" &> /dev/null \
                && _isfunction _init_pool_$y \
                && _init_pool_$y \
                || {
                    _emsg "${FUNCNAME}: @[$x] poolconf corrupt or missing: $(_dotstr $y)"
                    return 1
                }
        }
    }
    i9kgoo_list_xml "$x" "$y"
    x="${I9KGOO_LIST[@]}"
    i9kgoo_load "${x// /,}" \
        || _emsg "${FUNCNAME}: could not create caches"
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc Some simple statistics about a pool rcache. The pool must be
#       completely canonical (initialized in runspace, $_RPLI set)
# @ptip $1  Name of the pool to analyze
# @ptip $2  Global where to store results
# @note The global arrays POOL_PRISTINE and POOL_CLONES containg pristine
#       and clone rpli items respectively
#;
function i9kgoo_pool_analyze() {
    local   x="__pool_relay_$(odsel_gph "$1")[$_RPLI]" \
            f= o= t=\|
    local   h="$(odsel_prc_num "" "$x")"
    POOL_PRISTINE=()
    POOL_CLONES=()
    x="${!x}"
    for ((o=1;o<h;o++)); do
        f="$x[$o]"
        f="${!f/|*/}"
        case "$f" in
            pristine/*)
                [[ $t != ${f#*/} ]] && \
                    POOL_PRISTINE+=("${f#*/}") && \
                    t="${f#*/}"
            ;;
            clone/*)
                POOL_CLONES+=("${f#*/}")
            ;;
        esac
    done
}

#;
# @desc Generate a simulation instance to be part of an i9kg file, using
#       the XML implementation for i9kg out of a rpli item.
# @ptips $1 rpli item to use "<name>:<version>"
# @note The function prints output to stdout
#;
function i9kgoo_sim_prseq_xml() {
    local x
    printf "    <instance alias=\"default\" version=\"%s\">
        <materials>
            <rpli item=\"%s\"/>
        </materials>
        <sequence variant=\"stable\">\n" "${1/*:/}" "$1"
    for x in ${I9KG_PRESETS[@]}; do
        printf "            <action mode=\"%s\">
                <code>printf \"%s://default[%s@stable:%s] simulating: \$RANDOM events\\\n\"</code>
                <text>This is text for the %s event!</text>
            </action>\n" "$x" "${1/:*/}" "${1/*:/}" "$x" "$x"
    done
    printf "        </sequence>\n    </instance>\n"
}
