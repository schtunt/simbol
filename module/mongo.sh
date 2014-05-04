# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
The module interfaces mongodb
[core:docstring]

#. Mongo -={
core:import util
core:requires mongo

#. mongo:query -={
#simbol mongo :query BC 'qdn=/server/' qdn
function :mongo:query() {
    local -i e=${CODE_FAILURE?}

    if [ $# -gt 2 ]; then
        local db=$1
        local collection=$2

        local -a filters
        local -a display
        for kvp in ${@:3}; do
            if [[ ${kvp} =~ [^=]+=.+ ]]; then
                filters+=( "${kvp//=*}: ${kvp##*=}" )
            else
                display+=( "${kvp}" )
            fi
        done

        if [ ${#display[@]} -gt 0 ]; then
            #"load(\"${SIMBOL_CORE_LIBJS?}/mongo/helper.js\")"
            local -a jseval=(
                "var filters = { $(:util:join ', ' filters) }"
                "var data = db.${collection}.find(filters, { _id: 0 }).toArray()"
                "printjson(data)"
            )

            #mongo --quiet --eval "$(:util:join ';' jseval)"\
            #    ${db} ${SIMBOL_CORE_LIBJS?}/mongo/host.js |
            #    jsontool -a ${display[@]}
            mongo --quiet --eval "$(:util:join ';' jseval)" ${db} |
                jsontool -a ${display[@]}

            e=${CODE_SUCCESS?}

        else
            core:raise EXCEPTION_BAD_FN_CALL "At least one display field to be supplied"
        fi
    else
        core:raise EXCEPTION_BAD_FN_CALL "$# arguments given, >1 expected"
    fi

    return $e
}
#. }=-

function mongo:host() {
    :mongo:query ${SIMBOL_PROFILE} host "$@"
}
#. }=-
