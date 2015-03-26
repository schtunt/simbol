# vim: tw=0:ts=4:sw=4:et:ft=bash

#. Docstring for this module; keep this to a single line
:<<[core:docstring]
The simbol module aims to serve as a tutorial for new simbol users.  Once you are
comfortable with simbol, you can simply disable this module.
[core:docstring]

#. Tutorial -={

#. tutorial:p01 -={
function tutorial:p01() {
    cat <<!
# Part 1 - Simple Start

Let's get started with absolute simplest possible function.  In simbol, you
break define all your custom code into functions, and you group those
functions into modules.

As you can probably guess, this tutorial itself is a module by the name
\`tutorial\`, and the function in this example is called \`p01\`.  The full
function declaration is thus:

\`\`\`
    function tutorial:p01() {
        ...
    }
\`\`\`

Peek inside ${SIMBOL_CORE?}/module/tutorial to see the implementation of this
function before continuing.

Let's get to that in the next tutorial, where we will demonstrate how to use
one module from another.  In particular we're going to replace our \`cat\`
function with a call to \`:util:markdown()\`.

    % simbol tutorial p02
!
}
#. }=-
#. tutorial:p02 -={
core:import util
function tutorial:p02() {
    :util:markdown h1 "Part 2 - Using Modules" <<!
If all has gone well, then you should be seeing some colors on your terminal.

To use a function from another module, you simply import it:

    core:import util

After that, you call any function it provides, in this case \`:util:markdown\`.

_SIDENOTE_: We call functions that start with a colon \`internal\` because
they're not exposed publically via the CLI user interface.  This is dicussed in
detail in p04 of this tutorial.

Look inside once more time to see the implementation of this function, and then
move onto p03 where we discuss the three types of functions in simbol:

    % simbol tutorial p03
!
}
#. }=-
#. tutorial:p03 -={
function tutorial:p03() {
    :util:markdown h1 "Part 3.0 - The Three Function Types" <<!
Earlier we mentioned that the function \`:util:markdown\` was an internal
function, but there are a few more things that should be said about simbol
functions.

There are 3 types of functions in simbol, all three will be covered in details
right here because this information is key when writing your own modules:

All function names consist of two tokens, separated by a colon character, and
preceded with either 0, 1 or 2 colons, and the first token must be the name
of the module (same as the file in which the function has been defined.

Let's move onto the next section where we take a deeper look at public
functions:

    % simbol tutorial p03s1
!
}

function tutorial:p03s1() {
    :util:markdown h2 "Part 3.1 - Public Functions" <<!
Public functions always take the form \`<module-name>:<function-name>()\`.  For
example:

    function mymod:myfunc()

These functions don't do the hard work, they look after the the UI side of
things only, and when they need anything calculated, they will call internal or
private functions.

Public functions are automatically sought out by the simbol engine and presented
to the user at the CLI.  They also allow you to define various other functions
that decorate and enhance the function further.  What follows is an exhaustive
list of all such functions in line with the previous example:

    function mymod:myfunc:usage()
    function mymod:myfunc:help()
    function mymod:myfunc:alert()
    function mymod:myfunc:shflags()
    function mymod:myfunc:cached()
    function mymod:myfunc:cachefile()
    function mymod:myfunc:formats()

Note that these functions are all optional; they do not need to be declared, and
should only be defined when required.

We won't go into explaining them all here, that will come in p07.  Let's move
onto the next section where we look at internal functions:

    % simbol tutorial p03s2
!
}

function tutorial:p03s2() {
    :util:markdown h2 "Part 3.2 - Internal Functions" <<!
Internal functions always take the form \`:<module-name>:<function-name>()\`.
For example:

    function :mymod:myfunc()

These functions do the heavy lifting, they should never generate output for
humans, only computers - it is the responsibility of the public functions to
take that output and render it in a format suitable for the user.

Furthermore, internal functions are there for code reuse; that is, they perform
one task, and do it well, and provide an API that any other function from any
other module can use.  Users however can not access these functions directly.

!
}

function tutorial:p03s2() {
    :util:markdown h2 "Part 3.2 - Private Functions" <<!
Finally, we come to the final type of function - the private function.  These
always take the form \`::<module-name>:<function-name>()\`.  For example:

    function ::mymod:myfunc()

These functions are where you put you single-use code; these functions are
niether publically accessible, nor are they accessible from other modules.

These functions are generally a quick-and-dirty wrapper for some code that
you don't care much to expose to anything but one or two functions within the
same module.
!
}
#. }=-
#. tutorial:hello -={
#. Optional alerts
function tutorial:hello:alert() {
    cat <<!
TODO This is mynewfn, alas it does nothing interesting
WARN Well it does demonstrate the various alerts such as this warning
FIXME Critical issues can also be communicated in the same way
DEPR Once you deprecated a function, don't delete it, just add an alert
!
}

function tutorial:hello:formats() {
    cat <<!
dot
html
email
ansi
text
!
}

#. Optional shflags function for complicated functions
function tutorial:hello:shflags() {
    cat <<!
boolean greet   true    greet    g
string  name    World   repo-dir n
integer repeat  1       repeat   r
float   snooze  0.01    sleep    s
!
}

#    Seeing as this is the hello (world) example, let's start with
#    the very basics of simbol first, and then get to the particulars
#    of this particular function.
#
#    Depending on how many arguments you supply simbol, and what those
#    arguments are, you will get a contextual help menu, for example
#    try the following:
#
#    simbol
#    simbol tutorial
#
#    You will note from the last command that you

#. Optional long help message
function tutorial:hello:help() {
    cat <<!
    This function greets the world in high spirit.

    It also demonstrates the following features of simbol:

    * processing commandline arguments
    * processing short/long options via shflags
    * using the core module \`util' to join elements of an array

    Here are a few examples to illustrate the above:

    simbol tutorial hello --help

    simbol tutorial hello world
    simbol tutorial hello Jack
    simbol tutorial hello -g world
    simbol tutorial hello -c 3 world
    simbol tutorial hello -c 3 -s 0.2 world
    simbol tutorial hello Nucky Lucky Chucky
!
}

#. Optional cachefile - specifies that the command generates a file, and that
#. the output is not important.  It also specifies the generated file's path.
#. This should be used to cache functions that generate files instead of
#. output.
#function :tutorial:hello:cachefile() { echo $1; }

#. Optional cachetime change, if cache is enabled at all for this function.
function tutorial:hello:cached() { echo 10; } #. Let's go with 10s on this one.

#. Mandatory short usage
function tutorial:hello:usage() {
    echo "<to-you> [<and-also-you> [...]]"
}

#. Mandatory - the function itself
function tutorial:hello() {
    local -i e=${CODE_DEFAULT?}
    : e=${CODE_DEFAULT?} #. signals to simbol that user is in need of help
    : e=${CODE_FAILURE?} #. signals to simbol that there is an error condition
    : e=${CODE_SUCCESS?} #. signals to simbol that all went well

    if [ $# -gt 0 ]; then
        #. For shflags, we have a little work to do; here's a string:
        local name=${FLAGS_name?}; unset FLAGS_name;

        #. Here is an int:
        local -i repeat=${FLAGS_repeat?}; unset FLAGS_repeat;

        #. And here is a float:
        local snooze=${FLAGS_snooze?}; unset FLAGS_snooze;

        #. Here is a boolean, the ugliest of them all:
        local -i greet=${FLAGS_greet?}; ((greet=~greet+2)); unset FLAGS_greet

        local greeting="Hello"
        if [ ${greet} -eq 0 ]; then
            greeting="Goodbye"
        fi

        local -a creatures
        local whostr
        shopt -s nocasematch
        if [ $# -eq 1 ] && [[ $1 == "WORLD" ]]; then
            whostr="WORLD!"
        else
            creatures=( "$@" )
            whostr="$(:util:join , creatures), and of course ${name}!"
        fi

        local -i i
        for ((i=0; i<repeat; i++)); do
            cpf "${greeting} ${whostr}\n"
            sleep ${snooze}
        done

        e=${CODE_SUCCESS?}
    fi

    return $e
}
#. }=-

#. }=-
