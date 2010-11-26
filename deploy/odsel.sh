#!/bin/bash

# Copyright (C) 2010 - George Makrydakis <george@odreex.org>

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
# @note Step one of the experimental loader, this is a test for
#       the upcoming shell - strict only odsel subset that handles
#       build bootstraps etc.
#;

function __shellapi_checkinstall() {
    __shellapi_fcheck "${@}" && {
        [ -z "$SHELLAPI_HOME" ] && {
                printf "You cannot run shellapi without specifying SHELLAPI_HOME!\n"
                exit 1
            } || {
            [[ -d $SHELLAPI_HOME  ]] && {
                . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash" && {
                    ! [ -z $SHELLAPI_TARGET ] && {
                        _init || _fatal
                        pushd "${SHELLAPI_BSTRAPSH:-.}" &> /dev/null
                        odsel_fsi "$(_pathget "${SHELLAPI_BSTRAPSH:-.}" ${!#})" || _fatal
                        popd &> /dev/null
                    } || {
                        printf "SHELLAPI_TARGET not set!\n"
                        exit 1
                    }
                }
            } || {
                printf "SHELLAPI_HOME set but directory does not exist!\n"
                exit 1
            }
        }
    } || {
        printf "shellapi: environment is not set, aborting.\n"
        return 1
    }
}

#;
# @note Step two of the experimental loader
#;

function __shellapi_fcheck() {
    local   rj= x= y=1 vars=() \
            v_t=0 v_i=0 v_s=0 v_h=0 \
            v_g=0 v_f=0 v_j=0
    while getopts :i:s:t:hg:f:j: x; do
        rj="${@:$((${OPTIND}-1)):${OPTIND}}"
        case $x in
            [isthgfj])
                ((v_$x)) && {
                    printf "shellapi: ( %s ) assigned as: \"%s\", aborting\n"\
                        "$x" "${vars[v_$x]}"
                    return 1
                }
                [[ $x == [isthgfj] ]] && ((v_$x=$((y++)))) || {
                    printf "shellapi: invalid option: %s\n" "$rj"
                    return 1
                }
                vars[v_$x]="$OPTARG"
                ;;
            *)
                [[ $rj\: == -[istfj]\: ]] \
                    && printf "shellapi: ( %s ) without input, aborting...\n" "$rj" \
                    || printf "shellapi: ( %s ) without match, aborting...\n" "$rj"
                return 1
                ;;
        esac
    done
    ((v_j)) && {
        local s_double="$(pwd)"
        export SHELLAPI_HOME="${s_double%/*}"
        export SHELLAPI_TARGET="$SHELLAPI_HOME/deploy/__rspace"
        . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
        _init
        export SHELLAPI_TARGET="$(mktemp -d __rspace.XXXXXXXX)/__"
        _omsg "creating odsel_sh..."
        _odselrun_gen "${vars[v_j]}"
        _omsg "created odsel_sh in ${vars[v_j]}"
        exit
    }
    ((v_f)) && {
        printf "running odsel interpreter\n"
        SHELLAPI_HOME="$SHELLAPI_BSTRAPRN" \
        SHELLAPI_TARGET="$SHELLAPI_BSTRAPRN/deploy/__rspace"
        export SHELLAPI_HOME SHELLAPI_TARGET
        return 0
    }
    ((v_g)) && {
        printf "generating odsel.bash self extracting script\n"
        ((v_t)) && ((v_s)) && {
            export SHELLAPI_TARGET="${vars[v_t]}"
            export SHELLAPI_HOME="${vars[v_s]}"
            . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
            _init
            _odselrun_gen "${!#}/"
            exit
        }
    }
    ((v_i)) && ((v_s+v_t+v_h)) && {
        printf "shellapi: option -i can only be used as standalone, aborting.\n"
        return 1
    } || {
        ((v_i)) && {
            printf "requested an installation!\n"
            export SHELLAPI_TARGET="${vars[v_i]}"
            return 0
        } || {
            ! ((v_h)) && {
                ((v_t)) && export SHELLAPI_TARGET="${vars[v_t]}"
                ((v_s)) && export SHELLAPI_HOME="${vars[v_s]}"
                return 0
            } || {
                printf "shellapi: help option!\n"
                return 0
            }
        }
    }
}

__shellapi_checkinstall "$@"
