READ THIS CAREFULLY

1. Preliminary Setup
=================

There are a few requirements in order to get shellapi core operational.
The following steps are necessary for creating scripts that use the shellapi
functions. This is a technical preview; intended audience is extremely
niche - oriented.

1.1. The SHELLAPI_HOME global must be set to point to the directory where shellapi
     root is located.
1.2. If (2) is satisfied, the following script inclusion must take place:
     "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
1.3. Once (3) is done, the _init function call should be done and shellapi is
     operational from now on.
1.4. The system is design to halt if SHELLAPI_HOME is not set, even if inclusion
     takes place directly, bypassing the SHELLAPI_HOME global setting phase. This
     is per design.
1.5. During _init, a default "runspace" is created if none is set, with the name
     "rspace" located at the current working directory of the script.
1.6. Steps 1, 2, 3 are significant for every script run; 4 and 5 are done automatically
     during the first run when allowed by the internal logic core of shellapi.

2. Using the odreex pools
=========================

An odreex pool is collection of resources related to build instructions. Several
odreex pools may be initialized and used in a variety of ways, through the interface
offered by a custom DSL named "odsel". The odsel language is redundantly (and partialy)
implemented in GNU bash for the purpose of using a pure GNU bash based solution when
the end user desires to.

2.1. Currently only the [prime] pool is allowed to exist for the time being; this pool is
     the reserved one that is to be the end user's own modification of another third -
     party pool or created by the end user from start.
2.2. To create [prime] run "odsel_setup_pool" with no arguments inside a script compliant
     with {1.1, 1.2, 1.3} or {1.x} if no "runspace" has ever been created. The metabase.xml
     file required in the metabase directory of the pool and containing the various rpli
     links for the time being, must be put manually in position. See http://odreex.org
     for more details.


