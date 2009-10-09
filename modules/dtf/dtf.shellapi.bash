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
# @desc Convert seconds into mixed number time format
# @ptip $1 seconds to process (integer)
# @echo time in mixed number format
#;
function dtf_mixed_of() {
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
function dtf_seconds_of() {
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
function dtf_mixed_diff() {
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
function dtf_mixed_plus() {
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
        printf "%s\n" $(dtf_mixed_of "$((l+r))")
    } || _fail "${FUNCNAME}: ${SHCORE_MSGL[$_SHCORE_ERRNOPARAM]}: $#"
}
