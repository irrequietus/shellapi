READ THIS CAREFULLY

1. Compatibility Notes
======================

1.1. Compatibility is guaranteed with GNU Bash 3.2.10+ (including 4.0.x+).

2. Preliminary Setup
====================

There are a few requirements in order to get shellapi core operational.
The following steps are necessary for creating scripts that use the shellapi
functions. This is a technical preview; intended audience is extremely
niche - oriented.

2.1. The SHELLAPI_HOME global must be set to point to the directory where shellapi
     root is located.
2.2. If (2) is satisfied, the following script inclusion must take place:
     "${SHELLAPI_HOME}/modules/syscore/syscore.shellapi.bash"
2.3. Once (3) is done, the _init function call should be done and shellapi is
     operational from now on.
2.4. The system is design to halt if SHELLAPI_HOME is not set, even if inclusion
     takes place directly, bypassing the SHELLAPI_HOME global setting phase. This
     is per design.
2.5. During _init, a default "runspace" is created if none is set, with the name
     "rspace" located at the current working directory of the script.
2.6. Steps 1, 2, 3 are significant for every script run; 4 and 5 are done automatically
     during the first run when allowed by the internal logic core of shellapi.

3. Using the odreex pools
=========================

An odreex pool is collection of resources related to build instructions. Several
odreex pools may be initialized and used in a variety of ways, through the interface
offered by a custom DSL named "odsel". The odsel language is redundantly (and partialy)
implemented in GNU bash for the purpose of using a pure GNU bash based solution when
the end user desires to. The easiest way to see what a pool is is to run the following
command after an _init call is made:

odsel_vsi "new prime[];"

The command above retrieves the metabase XML descriptor from the official repository and
initializes the function and configuration caches of the prime pool; these caches are
located within the relays subdirectories of the runspace selected. Notice that if you
run the following:

odsel_vsi "del prime; sim prime;"

An i9kg "simulation" will run, creating a series of i9kg XML files and other material as
used by the system during test runs and for development purposes. Another, more complicated
example is the following:

odsel_vsi "
    : ftest() {
        del example;
        sim example;
        : ctest() => gcc[example]://default[4.4.0:{ @stable:configure_pre->make_post } ];
    };
    ftest();
    ctest();" || _fatal

In this case, we use odsel to define a function that does the following:

    a) Deletes the "example" pool.
    b) Runs an i9kg XML simulation for the "example" pool.
    c) Defines a callback function (ctest) that is the command sequence as extracted
       from the i9kg XML file of the simulation for gcc (look at that XML for more
       details) within the "example" pool.
    d) We run the function we have defined (ftest).
    e) Since the ftest() call has generated the ctest callback, we simply call that!
    f) In case of error, the _fatal() shellapi call will inform you of what happened.
       Notice that _fatal() is placed outside odsel_vsi(), it is a different shellapi
       function call.

These "callbacks" and other functions are defined using the odsel DSL, implemented in
GNU bash (as an initial demonstration) and all the operations take place within shellapi.
A wider variety of odsel expressions as well as a progressively completing implementation
for odsel itself are to follow. Callbacks (as well as functions) can be defined in nested
or non - nested definitions in odsel expressions; odsel_vsi() is the shellapi function that
is the current GNU Bash - implementation for odsel.

Check commit 955562675d27a7db4d5f115a4f7fc3844c9e61ca for some of the details related to
callback / function generation at the official git repository for the shellapi:

http://gitorious.org/odreex/shellapi.

This is still something *experimental*.

4. Final remarks
================

If you have not set a SHELLAPI_TARGET global, the prime pool will be located inside
the runspace created during the first run. If you wish to use that runspace, remember
to set it as one your SHELLAPI_TARGET global, pointing to the directory where that
runspace is found.

