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
the end user desires to. The easiest way to see what a pool is is to run the following
command after an _init call is made:

odsel_create "prime[]"

The command above retrieves the metabase XML descriptor from the official repository and
initializes the function and configuration caches of the prime pool; these caches are
located within the relays subdirectories of the runspace selected.

If you have not set a SHELLAPI_TARGET global, the prime pool will be located inside
the runspace created during the first run. If you wish to use that runspace, remember
to set it as one your SHELLAPI_TARGET global, pointing to the directory where that
runspace is found.


