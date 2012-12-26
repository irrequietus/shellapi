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
# @note Step one of the experimental loader, this is a test for
#       the upcoming shell - strict only odsel subset that handles
#       build bootstraps etc.
#;

function __shellapi_checkinstall() {
    __shellapi_fcheck "${@}" && {
        [ -z "$SHELLAPI_HOME" ] && {
                __shellapi_qp "You cannot run shellapi without specifying SHELLAPI_HOME!"
                exit 1
            } || {
            [[ -d $SHELLAPI_HOME  ]] && {
                . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash" && {
                    ! [ -z $SHELLAPI_TARGET ] && {
                        unset __shellapi_fcheck __shellapi_checkinstall __shellapi_qp
                        _init || _fatal
                        pushd "${SHELLAPI_BSTRAPSH:-.}" &> /dev/null
                        odsel_fsi "$(_pathget "${SHELLAPI_BSTRAPSH:-.}" ${!#})" || _fatal
                        popd &> /dev/null
                    } || {
                        __shellapi_qp "SHELLAPI_TARGET not set!"
                        exit 1
                    }
                }
            } || {
                __shellapi_qp "SHELLAPI_HOME set but directory does not exist!"
                exit 1
            }
        }
    } || {
        ((SHELLAPI_EXIT_0)) && return 0
        __shellapi_qp "shellapi: environment is not set, aborting."
        return 1
    }
}

#;
# @note Step two of the experimental loader
#;

function __shellapi_fcheck() {
    local   rj= x= y=1 vars=() \
            v_t=0 v_i=0 v_s=0 v_h=0 \
            v_g=0 v_f=0 v_j=0 v_q=0 v_r=0 \
            v_p=0
    while getopts :i:s:t:hg:f:j:q:r:p: x; do
        rj="${@:$((${OPTIND}-1)):${OPTIND}}"
        case $x in
            [isthgfjqrp])
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
    ((v_p)) && {
         [ -z "${SHELLAPI_HOME}" ] && {
            # NOTE: this assumes that you run odsel.sh within the 'deploy'
            #       directory
            pushd ../ &> /dev/null
            export SHELLAPI_HOME="$(pwd)"
            popd &> /dev/null
         }
         export SHELLAPI_TARGET="${SHELLAPI_HOME}/deploy/__rspace"
         . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
         __shellapi_qp "hot run processing mode, prepare to explode!"
         _init || _fatal
         x="$(_pathget "$(pwd)" "${vars[v_p]}")"
         [ -f "$x" ] && source "$x"
         exit $?
    }
    ((v_r)) && {
        ! [ -z "${SHELLAPI_HOME}" ] && {
            export SHELLAPI_TARGET="${SHELLAPI_HOME}/deploy/__rspace"
            . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
            __shellapi_qp "running odsel_vsiq() driven odsel parsing..."
            _init && odsel_vsiq "$(< "$(_pathget "$(pwd)" "${vars[v_r]}")")" || _fatal
            SHELLAPI_EXIT_0=1
        }
        return 1
    }
    ((v_q)) && {
        ! [ -z "${SHELLAPI_HOME}" ] && {
            ! [ -z "${SHELLAPI_TARGET}" ] && {
                . "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
                __shellapi_qp "running odsel_vsiq() driven odsel parsing..."
                _init && odsel_vsiq "$(< "$(_pathget "$(pwd)" "${vars[v_q]}")")" || _fatal
                SHELLAPI_EXIT_0=1
                return 1
            }
        } || return 1
    }
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
        __shellapi_qp "running odsel interpreter\n"
        SHELLAPI_HOME="$SHELLAPI_BSTRAPRN" \
        SHELLAPI_TARGET="$SHELLAPI_BSTRAPRN/deploy/__rspace"
        export SHELLAPI_HOME SHELLAPI_TARGET
        return 0
    }
    ((v_g)) && {
        __shellapi_qp "generating odsel.bash self extracting script"
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
        __shellapi_qp "shellapi: option -i can only be used as standalone, aborting."
        return 1
    } || {
        ((v_i)) && {
            __shellapi_qp "requested an installation!"
            export SHELLAPI_TARGET="${vars[v_i]}"
            return 0
        } || {
            ! ((v_h)) && {
                ((v_t)) && export SHELLAPI_TARGET="${vars[v_t]}"
                ((v_s)) && export SHELLAPI_HOME="${vars[v_s]}"
                return 0
            } || {
                __shellapi_qp "shellapi: help option!"
                exit 0
            }
        }
    }
}

__shellapi_checkinstall "$@"
