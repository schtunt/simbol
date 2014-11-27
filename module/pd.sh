# vim: tw=0:ts=4:sw=4:et:ft=bash

:<<[core:docstring]
PagerDuty module
[core:docstring]

#. See http://developer.pagerduty.com/documentation/rest to extend functionality
#. PagerDuty -={
core:import util
core:import vault

core:requires curl
core:requires ENV USER_PAGERDUTY_HOST
core:requires VAULT PAGERDUTY_API_KEY

#. pd:secret -={
declare -g SECRET
function ::pd:secret() {
    [ ${#SECRET} -gt 0 ] || SECRET="$(:vault:read PAGERDUTY_API_KEY)"
    [ $? -eq 0 ] || core:raise EXCEPTION_SHOULD_NOT_GET_HERE
    echo "${SECRET}"
}
#. }=-
#. pd:http -={
function ::pd:http() {
    local -i e=${CODE_FAILURE?}

    local secret="$(::pd:secret)"
    case $1 in
        get|post)
            local method="${1^^}"
            local subpath="$2"
            local url="https://${USER_PAGERDUTY_HOST?}/api/v1/${subpath}"
            local data
            if [ ${method} == "GET" ]; then
                for datum in ${@:3}; do
                    data+=" --data-urlencode ${datum}"
                done
                curl -s\
                    -H "Content-type: application/json"\
                    -H "Authorization: Token token=${secret}"\
                    -X ${method} -G ${data} ${url}\
                ;
                e=$?
            elif [ ${method} == "POST" ]; then
                for datum in ${@:3}; do
                    data+=" -d ${datum}"
                done
                curl -s\
                    -H "Content-type: application/json"\
                    -H "Authorization: Token token=${secret}"\
                    -X ${method} ${data} ${url}\
                ;
                e=$?
            fi
        ;;
        *:*)
            core:raise EXCEPTION_BAD_FN_CALL
        ;;
    esac

    return $e
}
#. }=-
#. pd:query -={
function :pd:query() {
    local -i e=${CODE_FAILURE?}

    case $#:$1 in
        1:oncall)
            ::pd:http get 'users/on_call'
            e=$?
        ;;
        1:services)
            ::pd:http get 'services'
            e=$?
        ;;
        1:users)
            ::pd:http get 'users'
            e=$?
        ;;
        1:schedules)
            ::pd:http get 'schedules'
            e=$?
        ;;
        *:incidents)
            #. https://developer.pagerduty.com/documentation/rest/incidents/list
            ::pd:http get 'incidents'\
                'sort_by=created_on:asc' "$@"
            e=$?
        ;;
        2:schedules)
            ::pd:http get "schedules/${schedid}"\
                "since=$(date --iso-8601=minutes -d "0 hour")"\
                "until=$(date --iso-8601=minutes -d "12 hour")"\
            ;
            e=$?
        ;;
        *)
            core:raise EXCEPTION_BAD_FN_CALL
        ;;
    esac

    return $e
}

function pd:query:help() {
    cat <<!
Usage:
-   users
-   oncall
-   services
-   schedules [<schedule-id>]
-   incidents [status=triggered|acknowledged|resolved]
-   incidents [service=<service-id>[,<service-id>[...]]]
!
}
function pd:query:usage() { echo "oncall | incidents | schedules [<schedule-id>]"; }
function pd:query() {
    local -i e=${CODE_DEFAULT?}

    case $#:$1 in
        1:users)
            :pd:query $1 | jq -c '.users[] | [.id,.name]'
            e=$?
        ;;
        1:oncall)
            :pd:query $1 | jq -c '.users[]
                | {id:.id,name:.name,on_call:.on_call[]}
                | select(.on_call.level>=1)
                | select(.on_call.level<=3)
                | {id:.id,who:.name,level:.on_call.level,from:.on_call.start,to:.on_call.end,epid:.on_call.escalation_policy.id,epn:.on_call.escalation_policy.name}
            '
            e=$?
        ;;
        1:services)
            :pd:query $1 | jq -c '.services[] | [.id,.name]'
            e=$?
        ;;
        1:schedules)
            :pd:query $1 | jq -c '.schedules[]'
            e=$?
        ;;
        2:schedules)
            :pd:query $1 $2 | jq 'schedule.final_schedule.rendered_schedule_entries'
            e=$?
        ;;
        *:incidents)
            local -i total=$(:pd:query "$@" | jq -c '.total')
            local -i limit=100
            local -i offset=0

            while [ ${offset} -lt ${total} ]; do
                :pd:query "$@" limit=${limit} offset=${offset} |
                    jq -c '.incidents[] | [.id,.incident_number,.created_on,.status,.service.name,.escalation_policy.name,.trigger_summary_data.subject,.resolved_by_user.name]'
                ((offset+=limit))
            done
            e=$?
        ;;
    esac

    return $e
}
#. }=-
#. pd:override -={
function pd:override:usage() { echo "<sched-id> <user-id> <start> <end>"; }
function pd:override() {
    local -i e=${CODE_DEFAULT?}

    if [ $# -eq 4 ]; then
        local secret="$(::pd:secret)"

        local schedid="$1"
        local userid="$2"
        local sdate="$3" #="$(date -u +'%Y-%m-%dT%H:%M:%S' -d "TZ=\"$(cat /etc/timezone)\" $3")"
        local edate="$4" #="$(date -u +'%Y-%m-%dT%H:%M:%S' -d "TZ=\"$(cat /etc/timezone)\" $4")"

        local postdata='{"override":{"user_id":"'${userid}'","start":"'${sdate}'","end":"'${edate}'"}}'
        local results
        results="$(::pd:http post "/schedules/${schedid}/overrides" "${postdata}")"
        echo "${results}" | jq . -c
        e=$?
    fi

    return $e
}
#. }=-
#. }=-
