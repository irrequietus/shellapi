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
        m="${y[$_I9KG_RLAY]}[${y[$_I9KG_POOL]}]"
        r=$(_dotstr ${y[$_I9KG_RHID]})
        p=$(_dotstr ${y[$_I9KG_PHID]})
        _isfunction "_init_pool_${y[$_I9KG_PHID]}" || {
            [[ -e $POOL_RELAY_CACHE/functions/${y[$_I9KG_PHID]}.poolconf.bash ]] \
                && . "$POOL_RELAY_CACHE/functions/${y[$_I9KG_PHID]}.poolconf.bash" \
                || {
                    _emsg "@[${y[$_I9KG_POOL]}] : $p failed"
                    return 1
                }
                _eqmsg "@[${y[$_I9KG_POOL]}] : $p complete"
        }
        _init_pool_${y[$_I9KG_PHID]}
        _ckmsg "requesting $m ?= $r"
        n="__pool_relay_${y[$_I9KG_PHID]}[$_FCACHE]"
        n="${!n}/__i9kg_init_${y[$_I9KG_RHID]}.odsel.bash"
        [[ -e $n ]] && {
            . "$n"
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
# @arrv I9KGOO_LIST : global array where the results of the operation
#       are stored
#;
function i9kgoo_list_xml() {
    I9KGOO_LIST=()
    local v x="$(odsel_gph "${1:-prime}")" y z
    _isfunction "_init_pool_$x" || {
        [[ -e $POOL_RELAY_CACHE/functions/$x.poolconf.bash ]] \
            && . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash" \
            || {
                _emsg "${FUNCNAME}: @[$2]: cache $(_dotstr $x) not found"
                return 1
            }
    }
    _init_pool_$x
    y="__pool_relay_$x[$_I9KG_SEEDS_XML]"
    shopt -s nullglob dotglob
    pushd "${!y}" &> /dev/null && {
        I9KGOO_LIST=(*.i9kg.xml)
        I9KGOO_LIST=("${I9KGOO_LIST[@]/.i9kg.*/}")
        v=${#I9KGOO_LIST[@]}
        popd &> /dev/null
    } || _fatal "${FUNCNAME}: i9kg XML seeds directory not found"
    shopt -u nullglob dotglob
    (($v > -1))
}

#;
# @desc Create i9kg odsel caches for all the i9kg assets of a pool.
# @ptip $1  pool whose i9kg odsel caches must be initialized.
#;
function i9kgoo_pcache() {
    i9kgoo_list_xml "${1:-prime}"
    local x="${I9KGOO_LIST[@]}"
    i9kgoo_load "${x// /,}"
}
