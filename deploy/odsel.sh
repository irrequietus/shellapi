#!/bin/bash

# Copyright (C) 2010 - 2012, George Makrydakis <irrequietus@gmail.com>

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

function __shellapi_qp() {
    printf "\033[1;32m[s]\033[0m: %s\n" "$1"
}

#;
# @note experimental loader, supports only -p and -f, this is a quick
#       fix for helping with development of the modules, right now
#       focusing on "hot run" and "vsiq file interpreter" modes.
#;

function __shellapi_fcheck() {
    local   rj= x= y=1 vars=() \
            v_p=0 v_f=0
    while getopts f:p: x; do
        rj="${@:$((${OPTIND}-1)):${OPTIND}}"
        case $x in
            [fp])
                ((v_$x)) && {
                    __shellapi_qp "shellapi: ( %s ) assigned as: \"%s\", aborting"\
                        "$x" "${vars[v_$x]}"
                    return 1
                }
                [[ $x == [isthgfjqrp] ]] && ((v_$x=$((y++)))) || {
                    __shellapi_qp "shellapi: invalid option: %s" "$rj"
                    return 1
                }
                vars[v_$x]="$OPTARG"
                ;;
            *)
                __shellapi_qp "shellapi: unknown switch used!"
                return 1
                ;;
        esac
    done
    { ((v_p)) || ((v_f)); } && {
         ((v_p)) && ((v_f)) && {
            __shellapi_qp "cannot use -p and -f together!"
            exit 1
         }
         [ -z "${SHELLAPI_HOME}" ] && {
            # NOTE: this assumes that you run odsel.sh within the 'deploy'
            #       directory
            pushd ../ &> /dev/null
            export SHELLAPI_HOME="$(pwd)"
            popd &> /dev/null
         }
         export SHELLAPI_TARGET="${SHELLAPI_HOME}/deploy/__rspace"
         . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash" &> /dev/null \
            || __shellapi_qp "could not include core, aborting"
         ((v_p)) && {
            __shellapi_qp "hot run processing mode, prepare to explode!"
            _init || _fatal
            x="$(_pathget "$(pwd)" "${vars[v_p]}")"
            [ -f "$x" ] && source "$x"
            exit $?
         }
         ((v_f)) && {
            __shellapi_qp "running odsel_vsiq() driven odsel parsing..."
            _init && odsel_vsiq "$(< "$(_pathget "$(pwd)" "${vars[v_f]}")")" || _fatal
            exit $?
         }
    }
}

__shellapi_fcheck "$@"
