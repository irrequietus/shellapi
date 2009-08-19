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
        # special handlers go here
        # TODO: explain how shellapi module event handlers work,
        #       this one seems like a good example
        # FIXME: _pool_handler_* functions must become _odsel_handler_*
        #       as per convention; the more elaborate reporting scheme
        #       must replace the following code.
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
# @desc Update a clone
# @devs FIXME import implementation
#;
function odsel_clone_update() {
    _wmsg "${FUNCNAME}: under implementation, reserved"
}

#;
# @desc An odsel interpreter in pure GNU bash (3.x, 4.x compatible)
#;
function odsel_si() {
    _decoy_this "${FUNCNAME}: odsel_si reviewed in a private git branch"
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
# @desc The init implementation for this module
# @devs FIXME: import XML - driven implementation for this one as well
# @devs FIXME: port globals into the XML configuration file (syscore - specs like)
#;
function odsel_init() {
    I9KG_ALIASES=(LOCATION
        PRISTINE
        PAYLOAD
        PATCHES
        SNAPSHOTS
        CLONES
        EZCONFIG
        METABASE
        METACACHE
        I9KG_DEPOT
        I9KG_SEEDS
        I9KG_SEEDS_XML
        I9KG_SEEDS_JSON
        I9KG_SEEDS_YAML
        I9KG_REPORTS
        I9KG_REPORTS_XML
        I9KG_REPORTS_JSON
        I9KG_REPORTS_YAML
        FCACHE
        RHID
        RPLI)
    I9KG_OAL=(
        RLAY
        POOL
        RHID
        PHID
        EXPR
    )
    _I9KG_RLAY=0
    _I9KG_POOL=1
    _I9KG_RHID=2
    _I9KG_PHID=3
    _I9KG_EXPR=4
    POOL_CACHE=()
    POOL_REPORT=()
    POOL_TARGUESS=()
    POOL_BUILDSPACE=()
    POOL_DGET="wget -c"
    ODSEL_XMLA=()
    ODSEL_REGEXP=( ':[{]([^}]*)[}]\]'
                   '([^,]*),'
                   '@([^@]*):([^->]*)->([^->]*)'
                   '\[([^@{}>,-]*):\{@([^@{}>,-]*)\}\]'
                   '\[([^@{}>,-]*)@([^@{}>,-]*)\]'
                   '\[([^@{}>,-]*):([^@{}>,-]*)\]'
                   '\[([^@{}>,:]*)\]' )
    ODSEL_OPRT=( [$(_opsolve ">>")]="mm"
                 [$(_opsolve "->")]="pm"
                 [$(_opsolve "~>")]="rm" )
    _HPAGE=0
    _CHECKSUM=1
    _ENTRY=2
    _UPDATE=3
    _PREGET=4
    _POSTGET=5
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
    local x="${2:-__pool_relay_$(odsel_gph "$1")[$_RPLI]}" y=
    y="${!x}[0]";y=(${!y})
    printf "%d\n" "$(($(_asof ${!x})/7+${#y[@]}+1))"
}

#;
# @desc Retrieve a particular pool item from the pool relay and store
#       the result into the POOL_ITEM global array; the pool relay must
#       be initialized.
# @ptip $1  odsel rpli target to retrieve
#;
function odsel_ifind() {
    local x="$1" a="${2:-"__pool_relay_$(odsel_gph "prime")[$_RPLI]"}"\
        r=1 m=0 t=0 b=" " f o m n matches=()
    [[ -z $2 ]] && a=${!a}
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
            matches=("$n")
        else
            while [[ ${n%:*} == $x || $n == $x ]]; do
                matches+=("${n#*:}")
                n="$a[$((r++))]"
                n="${!n/|*/}"
            done
        fi
        ((${#matches[@]} != 1)) && {
            for h in ${matches[@]}; do
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
# @desc Read a file with ppli links and preprocess it
# @ptip $1  path to file
# @devs FIXME: _fatal raised is superfluous; move to _emsg
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
    o=0 a=() x= _tagged= k=()
    QPOOL_RLA=()
    while read -r l; do
        case "$l" in
            \<pli\ * | \<pli\ */\>)
            [[  $l =~ [[:space:]]*entry[[:space:]]*=[[:space:]]*\"([^\"]*)\" || \
                $l =~ [[:space:]]*entry[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] && {
                    _entry="${BASH_REMATCH[1]}"
                    [[ -z $_entry ]] && _fatal "${FUNCNAME}: $l"
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
                        || _fatal "${FUNCNAME}: attribute not found: idf"
            } || _fatal "${FUNCNAME}: entry attribute not found in: $_l"
            [[ $l = */\> ]] && {
                # we have the tagged attribute now, which means use it
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
                QPOOL_RLA+=("$_version $b")
                [[ -z $_tagged ]] || {
                    QPOOL_RLA+=("$_tagged $b")
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
                _fatal "${FUNCNAME}: unexpected tag in stream: $l"
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
                QPOOL_RLA+=("$_version $b")
            ;;
            zz)
                break;
            ;;
        esac
    done< <(_xmlpnseq "$1")
    z=0
    while read -r x; do
        QPOOL_RLA[$((z++))]="$x"
    done< <(for x in ${!QPOOL_RLA[@]}; do
                printf "%s\n" "${QPOOL_RLA[$x]}"
            done | sort -k1,1 -t\|)
    k="${k[@]}"
    [[ -z $2 ]] \
        && eval "QPOOL_RLA=(\"\$k\" \"\${QPOOL_RLA[@]}\" \"\${a[@]}\")" \
        || {
            eval "$2=(\"\$k\" \"\${QPOOL_RLA[@]}\" \"\${a[@]}\")"
            QPOOL_RLA=()
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
# @desc Transform an ungrouped odsel expression into the sequence of commands
#       or text or whatever it refers to, for the pool it refers to and the
#       i9kg file containing the particular instance it has been mapped for.
# @ptip $1  odsel expression
# @ptip $@  i9kg rcache hash identifier it requires; may deduce it on its own
#           but as always, the rcache array must be already initialized.
#;
function odsel_exprseq() {
    local x="$1" a r=1 m=0 t=0
    [[ -z $2 ]] && {
        [[ "${x/:*/}" =~ ([a-zA-Z0-9_-]*)\[([^[:space:]]*)\] ]] \
                && a=("${BASH_REMATCH[1]}" "${BASH_REMATCH[2]:-prime}") \
                || a=("${x/:*/}" "prime")
        a=__i9kg_rcache_$(_hsos "${a[0]}[${a[1]}]")
    } || a="$2"
    local b="$a[0]"
    local h="${!b/ */}" v="${!b/ */}"
    local s=$h
    while (($r<$h)); do
        t="$a[$((m=$((r+$(($((h-r))/2))))))]"
        [[ "${!t/ */}" < "$x" ]] && r=$((m+1)) || h=$m
    done
    t="$a[$r]"
    (($r < $s)) \
        && [ "${!t/ */}" == "$x" ] \
        && for x in ${!t#* }; do
               x="$a[$x+$v]"
               printf "%s\n" "${!x}"
           done
}

#;
# @desc Initialize a pool relay and create a function cache entry
# @ptip $1  pool hash identifier
#;
function odsel_relay() {
    local   x y z \
            _f="${POOL_RELAY_STORE}/$1.poolconf.xml" \
            _s="${POOL_RELAY_STORE}/$1.poolconf.bash"
    [[ -z $POOL_RELAYS ]] && POOL_RELAYS=()
    x=$(_ssbfind POOL_RELAYS "$1") && {
    # if it is already in the pool relays, just load it up
        _isfunction "_init_pool_$1" || {
            . "$_s"  &> /dev/null || {
                _emsg "${FUNCNAME}: $1 in pool relays, not available in cache"
                return 1
            }
        }
        _init_pool_$1
    } || {
        while read -r z; do
            POOL_RELAYS[$((y++))]="$z"
        done< <(POOL_RELAYS+=("$1")
                for x in ${!POOL_RELAYS[@]}; do
                    printf "%s\n" "${POOL_RELAYS[$x]}" 
                done | sort)
        ! [[ -e $_f ]] && {
            {
                printf  "<bashdata fni=\"%s\">\n <array name=\"%s\" check=\"reuse\">\n" \
                        "_init_pool_$1" "${2:-$1}"
                for x in ${!I9KG_ALIASES[@]}; do
                    printf  "  <index name=\"%s\">%s</index>\n" \
                            "${I9KG_ALIASES[$x]}" \
                            "\${I9KG_POOLSPACE}${I9KG_PRIME[$x]/${I9KG_POOLSPACE}\/prime//$1}"
                done
                printf " </array>\n</bashdata>\n"
            } > "$_f" 2> /dev/null || {
                _emsg "${FUNCNAME}: could not create file: $1.poolconf.xml"
                return 1
            }
        } || {
            _emsg "${FUNCNAME}: file is already here, cannot overwrite: $1.poolconf.xml"
            return 1
        }
        rm -rf "$_s"
        _xml2bda "$_f" "$_s"
    }
    ! ((${#SHELLAPI_ERROR[@]}))
}

#;
# @desc An odsel expression wrapper handling particular actions based upon
#       odsel expressions. For the time being acts as a i9kg function cache
#       loader and initializer before delegating to odsel_exprseq
# @ptip $1  the odsel expression of which to use or create i9kg init cache
#           in the meanwhile.
# @devs FIXME: Still linked exclusively to [prime] pool; import pool - agnostic
#       implementation (already present in header request; eliminate I9KG_PRIME
#       wiring)
#;
function odsel_act() {
    local x y=($(_odsel_i9kg_header "$1"))
    _isfunction "__i9kg_init_${y[$_I9KG_RHID]}" || {
        x="${I9KG_PRIME[$_FCACHE]}/__i9kg_init_${y[$_I9KG_RHID]}.odsel.bash"
        odsel_xmla \
            "${I9KG_PRIME[$_I9KG_SEEDS_XML]}/${y[$_I9KG_RLAY]}.i9kg.xml" \
            "__i9kg_rcache_${y[$_I9KG_RHID]}"
        odsel_i9kg_objc \
            "__i9kg_rcache_${y[$_I9KG_RHID]}" \
            ${y[$_I9KG_RHID]} > "$x"
        . "$x"
    }
    __i9kg_init_${y[$_I9KG_RHID]}
    odsel_exprseq "$1"
}

#;
# @desc
# @devs FIXME: import implementation
#;
function _odsel_pm() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc internal event handler for the ~> operator
# @devs FIXME import implementation
#;
function _odsel_rm() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc Greater than or equal comparison
# @devs FIXME import implementation
#;
function _odsel_gte() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc Less than or equal comparison
# @devs FIXME import implementation
#;
function _odsel_lte() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc Greater than comparison
# @devs FIXME import implementation
#;
function _odsel_gt() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc Less than comparison
# @devs FIXME import implementation
#;
function _odsel_lt() {
    _decoy_this "${FUNCNAME}"
}

#;
# @desc internal event handler for the >> operator
# @devs FIXME
#;
function _odsel_mm() {
    local x="$1" y="$2"
    case "$x" in
        \[*\])
            [[ $y =~ \&([^0-9][a-zA-Z0-9-]*) ]] && {
                x="${x%?}"
                x="${x:1}"
                odsel_enable "${x-prime}" "${BASH_REMATCH[1]}"
                #&& eval "${BASH_REMATCH[1]}[$_RPLI]=_pool_rcache_\${${BASH_REMATCH[1]}[$_RHID]}"
            }
        ;;
        *)
        ;;
    esac
}

#;
# @desc Default handler for undefined operators
#;
function _odsel_() {
    _emsg "${FUNCNAME}*: operator not defined"
    return 1
}

#;
# @desc Generate and use a function for retrieving a particular
#       resource.
# @ptip $1  odsel pli shortcut identifying the resource
# @ptip $2  odsel pli metadata array where to search for the resource
#;
function odsel_getfn() {
    odsel_ifind "$1" "$2" && {
        FNPREP_ARRAY=()
        ODSEL_FN="_odself_$(_hsos "$1")"
        while read -r j; do
            [[ -z $j ]] \
                || FNPREP_ARRAY+=("$j")
        done< <(printf "%s\n%s\n%s\n" \
                "${POOL_ITEM[$_PREGET]}" \
                "$(odsel_ifetch "${POOL_ITEM[$_ENTRY]}")"\
                "${POOL_ITEM[$_POSTGET]}" )
        local f=$(mktemp)
        [[ -z ${POOL_ITEM[$_CHECKSUM]} ]] \
            || FNPREP_ARRAY+=(\
"_cfx ${POOL_ITEM[$_ENTRY]##*/} ${POOL_ITEM[$_CHECKSUM]} && \\\
fnapi_msg \"checking hash of ${POOL_ITEM[$_ENTRY]##*/} : \
\$(_dotstr "${POOL_ITEM[$_CHECKSUM]}") : ok\"")
        fnapi_genblock "$ODSEL_FN" "pool request: $1" \
            FNPREP_ARRAY "pool request: $1" fatal > "$f"
        unset FNPREP_ARRAY
        . "$f"
        rm -rf $f
        $ODSEL_FN
    } || _emsg "${FUNCNAME}: [function()] --> $1 ?"
    ! ((${#SHELLAPI_ERRORS[@]}))
}

#;
# @desc Expand an ungrouped odsel expression
#;
function odsel_expand() {
    [[ $1 =~ @\[([a-zA-Z0-9-]*)\]://(snapshot|clone|pristine)/(.*) ]] && {
        local   x="__pool_relay_$(odsel_gph "${BASH_REMATCH[1]:-prime}")[$_RPLI]" \
                vpool="${BASH_REMATCH[1]:-prime}" \
                vsection=${BASH_REMATCH[2]} \
                vexp="${BASH_REMATCH[3]}"
        [[ $vexp =~ ([a-zA-Z0-9-]*):\((.*)\) ]] && {
            _odsel_${VERSION_OPERATORS[$(_opsolve "${BASH_REMATCH[2]:0:2}")]}
        } || odsel_getfn "$vsection/$vexp" "${!x}"
    }
}

#;
# @desc A pool expression interpeter, in bash
# @ptip $1  pool expression to intepret
# @devs DEPRECATED: non canonical, to be included into odsel_si
#;
function poolcli() {
    local x="${1//[[:space:]]/}" y z a op=
    case "$x" in
        @\[*\]\://*)
            odsel_expand "$x"
        ;;
        @\:\:\{*\})
            x="${x#*{}"
            x="${x%?},"
            while [[ $x =~ ([^,]*),([^,]*) ]]; do
                y="${BASH_REMATCH[1]}"
                [[  $y =~ ([^=\~\>\-]*):\((.*)\)([=\~\>\-]\>)([^=\~\>\-]*):\((.*)\) || \
                    $y =~ ([^=\~\>\-]*):\((.*)\)([=\~\>\-]\>)([^=\~\>\-]*) || \
                    $y =~ ([^=\~\>\-]*)([=\~\>\-]\>)([^=\~\>\-]*) || \
                    $y =~ ([^=\~\>\-]*):\((.*)\) || \
                    $y =~ ([^=\~\>\-]*)
                ]] && {
                    a=("${BASH_REMATCH[@]:1}")
                    case "${#a[@]}" in
                        5 | 4)
                            _odsel_${ODSEL_OPRT[$(_opsolve "${a[2]}")]} \
                                "${BASH_REMATCH[@]:1:2}" "${BASH_REMATCH[@]:3:4}" \
                                    || return 1
                            ;;
                        3)
                            _odsel_${ODSEL_OPRT[$(_opsolve "${a[1]}")]}  \
                                "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" \
                                    || return 1
                            ;;
                        2 | 1)
                                echo NOTHING HERE
                            ;;
                        *) ;;
                    esac
                }
                x="${x#*,}"
            done
        ;;
    esac
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
function odsel_enable() {
    local x=$(odsel_gph "$1") z
    local y="${2:-__pool_relay_$x}"
    _isfunction "_init_pool_$x" && _init_pool_$x || {
        if [[ -e $POOL_RELAY_CACHE/functions/$x.poolconf.bash ]]; then
            _imsg "@[$1]: loading configuration cache $(_dotstr "$x")"
            . "$POOL_RELAY_CACHE/functions/$x.poolconf.bash"
            _init_pool_$x &> /dev/null || {
                _emsg "${FUNCNAME}: for pool [$1]"
                _emsg "${FUNCNAME}: invalid cache: $(_dotstr "$x")"
                return 1
            }
            eval "__pool_relay_${x}[\$_RHID]=\"$x\"
                  __pool_relay_${x}[\$_RPLI]=\"__pool_rcache_$x\""
        else
            _nmsg "@[$1]: caching xml relay : $(_dotstr "$x")"
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
                _emsg "${FUNCNAME}: for pool [$1]"
                _emsg "${FUNCNAME}: pool configuration relay invalid or missing: $(_dotstr "$x")"
                return 1
            }
            _cmsg "@[$1]: caching complete  : $(_dotstr "$x")"
        fi
    }
}

#;
# @desc Create a pool, either within the poolset or at a path of your
#       option. A function cache is created for the XML description file
#       as well. If a pool is followed by the [] operator, retrieval of
#       the metabase and its processing takes place. The pool gets enabled
#       on creation (in a way similar to odsel_enable)
# @ptip $1  Comma separated pool list
#;
function odsel_create() {
    local x y z f l t k h
    _split "${1//[[:space:]]/}"
    for y in ${SPLIT_STRING[@]}; do
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
function odsel_remove() {
    local x y
    _split "${1//[[:space:]]/}"
    for x in ${!SPLIT_STRING[@]}; do
        x="${SPLIT_STRING[$x]}"
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
# @desc Convert a pull expression to a specific resource within a pool
# @ptip $1  pull expression to be processed
# @devs import new implementation
#;
function odsel_pull() {
    _decoy_this "${FUNCNAME}: implementation not imported"
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
# @desc Transform a directory or any tarball into a tarball with the default payload
#       option, putting it into [snapshots] or [payload] directory by default, or
#       storing it at a specified, existing path in the filesystem.
# @ptip $1  A filesystem path or a pool instruction
# @ptip $2  A valid fileystem path to output the result of the operations
# @devs FIXME: remove [prime] exclusive linking
#;
function odsel_iassign() {
    local s x t
    POOL_REPORT=()
    [[ ${1#*/} == $1 && ${1:0:1} != . ]] \
        && s="${I9KG_PRIME[$_PRISTINE]}/$1" \
        || s="${1}"
    case "$s" in
        pool\:* | pool\[*)
            _fatal "${FUNCNAME}: inter - pool operations are currently reserved: $s"
            ;;
        *.tar.bz2 | *.tbz)  x="bzip2 -dc" ;;
        *.tar.gz | *.tgz)   x="gzip -dc"  ;;
        *.tar.lzma)         x="lzma -dc"  ;;
        */*)
            ! [[ -d $s ]] \
                && _emsg "${FUNCNAME}: a snapshot was requested, for a non - existing filepath:$s" \
                && return 1
            ;;
         *)
            _emsg "${FUNCNAME}: unrecognizable error in: $s"
            return 1
         ;;
    esac
    [[ -z $x ]] && {
        t="${2:-${I9KG_PRIME[$_SNAPSHOTS]}}/${s##*/}-snapshot.$(dtff).tar.${SHELLAPI_PAYLOAD//[ip]/}"
        {
            pushd "${s%/*}" > /dev/null
            tar cf - "${s##*/}" | ${SHELLAPI_PAYLOAD} --best -c - > "$t"
            popd > /dev/null
        } 2>/dev/null || _emsg "${FUNCNAME}: could not perform conversion for: $1"
    } || {
        t="${s##*/}"
        t="${2:-${I9KG_PRIME[$_PAYLOAD]}}/${t%.t*}.tar.${SHELLAPI_PAYLOAD//[ip]/}"
        {
            $x "$s" | $SHELLAPI_PAYLOAD --best > "$t"
        } 2>/dev/null || _emsg "${FUNCNAME}: could not perform conversion for: $1"
    }
    odsel_targuess "$t" || _fatal
    [[ $x == snap ]] \
        && POOL_REPORT="@://snapshot/${POOL_TARGUESS[0]}:${POOL_TARGUESS[2]#*.}" \
        || POOL_REPORT="@://payload/${POOL_TARGUESS[0]}:${POOL_TARGUESS[2]}"
    POOL_REPORT=("$POOL_REPORT" "${POOL_TARGUESS[1]}" "${POOL_TARGUESS[4]}")
}

#;
# @desc Create an rpli link out of a tarball
# @ptip $1  tarball to process
# @warn FIXME: minor annoyances
#;
function odsel_xmlputs() {
    odsel_targuess "$1" && {
    printf "<block alias=\"%s\" hpage=\"?\">
    <rpli
        entry=\"%s\"
        version=\"%s\"
        idf=\"%s\"
        sha1sum=\"%s\"/>\n</block>\n" \
        ${POOL_TARGUESS[@]}
    } || {
        _emsg "${FUNCNAME}: failed for: $1"
        return 1
    }
}

#;
# @desc Initialize to the full series of events
# @note DEPRECATED : must move to XML driven version
#;
function odsel_presets_all() {
    I9KG_PRESETS=(
        "configure_pre"
        "configure_build"
        "configure_post"
        "make_pre"
        "make_build"
        "make_post"
        "make_install_pre"
        "make_install_build"
        "make_install_post"
        "remove_install_pre"
        "remove_install_build"
        "remove_install_post"
    )
}

#;
# @desc Initialize to the remove series of events
# @note DEPRECATED : must move to XML driven version
#;
function odsel_presets_remove() {
    I9KG_PRESETS=(
        "remove_install_pre"
        "remove_install_build"
        "remove_install_post"
    )
}

#;
# @desc Initialize to the install series of events
# @note DEPRECATED : must move to XML driven version
#;
function odsel_presets_install() {
    I9KG_PRESETS=(
        "configure_pre"
        "configure_build"
        "configure_post"
        "make_pre"
        "make_build"
        "make_post"
        "make_install_pre"
        "make_install_build"
        "make_install_post"
    )
}

#;
# @desc A practical, odsel group expression expander in bash (component of the future odsel_si)
#       for multiple, en block odsel expression interpretation during instruction / metadata
#       navigation in the arrays.
# @ptip $1  odsel block statement to interpret
# @ptip $2  array to store the block statement sequence, defaults to ODSEL_EXPBLOCK
#;
function odsel_scli() {
    local   _ft="${2:-ODSEL_EXPBLOCK}" \
            _l="${1//[[:space:]]/}" \
            _c=0 _p= _r= _b=()
    local   lhs="${_l/[*/}" \
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
    case "$_l" in
        *\[*:\{@*,*)
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
        *\[*:\{@*)
                [[ $_l =~ ${ODSEL_REGEXP[3]} ]] \
                    &&   _b+=("${lhs}[${BASH_REMATCH[1]}@${BASH_REMATCH[2]}]${rhs}") \
                    || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
        *\[*@*:*)
                [[ $_l =~ ${ODSEL_REGEXP[4]} ]] \
                    &&   _b+=("${lhs}[${BASH_REMATCH[1]}@${BASH_REMATCH[2]}]${rhs}") \
                    || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
        *\[*:*\]*)
                [[ $_l =~ ${ODSEL_REGEXP[5]} ]] \
                    &&  _b+=("${lhs}[${BASH_REMATCH[1]}@stable:${BASH_REMATCH[2]}]${rhs}") \
                    || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
        *\[*\]*)
                [[ $_l =~ ${ODSEL_REGEXP[6]} ]] && {
                    for _c in ${I9KG_PRESETS[@]}; do
                        _b+=("${lhs}[${BASH_REMATCH[1]}@stable:$_c]${rhs}") 
                    done
                } || _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
            *)
                _fatal "${FUNCNAME}: failed to recognize: $_l"
            ;;
    esac
    # FIXME: eval expression can substitute after check
    local _ff="$(mktemp)"
    printf "${_ft}=(\"\${_b[@]}\")\n" > $_ff
    . $_ff
    rm -rf $_ff
}

#;
# @desc Load an i9kg XML file describing the various instances of a "package"
#       into an array, complete with the dependency query metadata, build
#       instruction sequences etc. The resulting array is
# @ptip $1  path to file
# @ptip $2  a hash identifier or default to ODSEL_XMLA global
# @devs TODO: consider removing _fatal for _emsg semantics with stop on first error.
#;
function odsel_xmla() {
    local   v_sn v_an v_in v_iv t=() c=() k=0 \
            v=0 _cn=0 \
            li= p=0 q=0 x \
            xarray=() _A=() _rvfx=() _pt=() _D=() _NB=() _NR=() _DB=() _DR=() i=0 n=() \
            fnm="${1##*[!/]/}"
            fnm="${fnm/.*/}"
    while read -r li; do
        xarray+=("$li")
        case "${li}" in
            \<action\ *)
                [[  $li =~ [[:space:]]*mode[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*mode[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_an="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute missing in $1: mode"
            ;;
            \</action\>)
                ((${#_pt[@]})) && {
                    #_A+=("${fnm}://${v_in}[${v_iv}@${v_sn}:${v_an}] ${_pt[@]}")
                    ((${#c[@]})) && _A+=("${fnm}://${v_in}[${v_iv}@${v_sn}:${v_an}]:code ${c[@]}")
                    ((${#t[@]})) && _A+=("${fnm}://${v_in}[${v_iv}@${v_sn}:${v_an}]:text ${t[@]}")
                    _actions+=($p)
                    _pt=()
                    t=()
                    c=()
                }
                k=0
            ;;
            \<rpli\ */\>)
                [[  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _D[$i]="${_D[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
            ;;
            \<dbld\ */\>)
                [[  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DB[$i]="${_DB[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
            ;;
            \<drun\ */\>)
                [[  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _DR[$i]="${_DR[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
            ;;
            \<nbld\ */\>)
                [[  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NB[$i]="${_NB[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
            ;;
            \<nrun\ */\>)
                [[  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*item[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && _NR[$i]="${_NR[$i]}$(printf "\n%s" "${BASH_REMATCH[1]}")"
            ;;
            \<sequence\ *)
                [[  $li =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*variant[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_sn="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute missing in $1: variant"
            ;;
            \</instance\>)
                _D[$i]="${_D[$i]:1}"
                _DB[$i]="${_DB[$i]:1}"
                _DR[$i]="${_DR[$i]:1}"
                _NB[$i]="${_NB[$i]:1}"
                _NR[$i]="${_NR[$i]:1}"
                ((i++))
            ;;
            \<code\> | \<text\>)
                v=${#xarray[@]}
            ;;
            \</code\> | \</text\>)
                q=$((${#xarray[@]}-1))
                p=${#_rvfx[@]}
                [[ ${li} == \</code\> ]] \
                    && c+=($p) \
                    || t+=($p)
                _A+=("${fnm}://${v_in}[${v_iv}@${v_sn}:${v_an}(:$((k++)))]:${li:2:4} $p")
                x="${xarray[$v]//\$/\\\$}"
                x="${x//\`/\\\`}"
                _rvfx[$p]="${x//\"/\\\"}"
                ((v++))
                for((;v<$q;v++)); do
                   x="${xarray[$v]//\$/\\\$}"
                   x="${x//\`/\\\`}"
                   _rvfx[$p]="${_rvfx[$p]}$(printf "\n%s" "${x//\"/\\\"}")"
                done
                _pt+=("$p") # events are split into single transactions
           ;;
           \<instance\ *)
                [[  $li =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*version[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_iv="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute missing in $1: version"
                [[  $li =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\"([^\"]*)\" \
                ||  $li =~ [[:space:]]*alias[[:space:]]*=[[:space:]]*\'([^\']*)\' ]] \
                    && v_in="${BASH_REMATCH[1]}" \
                    || _fatal "${FUNCNAME}: attribute missing in $1: alias"
                    n="$n$(printf "\n%s" "$v_in[$v_iv]")"
           ;;
        esac
    done< <(_xmlpnseq "$1")
    _finals=()
    while read -r l; do
        _finals+=("$l")
    done< <(for l in ${!_A[@]}; do
                printf "%s\n" "${_A[$l]}"
            done | sort -k1,1 -t\ )
    eval "${2:-ODSEL_XMLA}=( \"\$((\${#_finals[@]}+1)) \$((\${#_rvfx[@]}+\${#_finals[@]}+1))\"
            \"\${_finals[@]}\"
            \"\${_rvfx[@]}\"
            \"\${n:1}\"
            \"\${_D[@]}\" \"\${_DB[@]}\" \"\${_DR[@]}\" \"\${_NB[@]}\" \"\${_NR[@]}\") "
}

#;
# @desc Performs Complete function cache removal for relays
# @ptip $1  hash id for the relay cache function
#;
function odsel_rrfcache() {
    rm -rf "${POOL_RELAY_CACHE}/functions/${1:-*}.poolconf.bash"
}

#;
# @desc A wrapper function for odsel_create
# @ptip $1  pool identifier
#;
function odsel_setup_pool() {
    _nmsg "creating @[${1:-prime}]" \
        && odsel_create "${1:-prime}" \
        || {
            _emsg "${FUNCNAME}: creating @[${1:-prime}] failed"
            return 1
           }
    _cmsg "created  @[${1:-prime}]"
}

