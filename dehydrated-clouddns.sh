#!/usr/bin/env bash

# Dehydrated hook for solving ACME challenges via CloudDNS API
#
# Author: Radek Sprta <sprta@vshosting.cz>

set -o errexit  # Error if a command fails
set -o errtrace # Inherit error trap
set -o nounset  # Error if a variable is unset
set -o pipefail # Error if pipe fails

CLOUDDNS_API='https://admin.vshosting.cloud/clouddns'
CLOUDDNS_LOGIN_API='https://admin.vshosting.cloud/api/public/auth/login'
PROPAGATION_TIME=100

# Main control flow
# Args: $1 (required): Hook to use.
#       $1 (required): Domain to add record for.
#       $2 (not used): DNS Record filename.
#       $3 (required): DNS record content.
function main() {
    case "${1:-}" in
        deploy_challenge)
            shift
            deploy_challenge "$@"
            ;;
        clean_challenge)
            shift
            clean_challenge "$@"
            ;;
    esac
}

# Clean up dns-01 ACME challenge record via CloudDNS API.
# Args: $1 (required): Domain to add record for.
#       $2 (not used)
#       $3 (required): DNS record content.
clean_challenge() {
    echo " + CloudDNS hook executing: clean_challenge"
    local domain="$1"
    local domain_id
    local domain_root
    local record_id

    domain_root=$(_get_domain_root "${domain}")
    domain_id=$(_get_domain_id "${domain_root}")

    record_name="_acme-challenge.${domain}"
    record_id=$(_get_record_id "${domain_id}" "${record_name}")
    _delete_record "${record_id}"
    _publish_records "${domain_id}"
}

# Deploy dns-01 ACME challenge record via CloudDNS API.
# Args: $1 (required): Domain to add record for.
#       $2 (not used)
#       $3 (required): DNS record content.
function deploy_challenge() {
    echo " + CloudDNS hook executing: deploy_challenge"
    local domain="$1"
    local domain_id
    local domain_root
    local record_value="$3"

    domain_root=$(_get_domain_root "${domain}")
    domain_id=$(_get_domain_id "${domain_root}")

    record_name="_acme-challenge.${domain}"
    _add_record "${domain_id}" "${record_name}" "${record_value}"
    _publish_records "${domain_id}"

    echo "  + Waiting for propagation..."
    sleep ${PROPAGATION_TIME}
}

# Add TXT record to DNS zone.
# Args: $1 (required): Domain id of the zone.
#       $2 (required): Record name.
#       $3 (required): Record value.
function _add_record() {
    local data="{\"type\":\"TXT\",\"name\":\"$2.\",\"value\":\"$3\",\"domainId\":\"$1\"}"
    response=$(_api_request "POST" "record-txt" "${data}")

    # If adding record failed (error:) then print error message
    if [[ "${response// /}" == *'"error"'* ]]; then
        local re='"message":"([^"]+)"'
        if [[ "${response}" =~ ${re} ]]; then
            _err "DNS challenge not added: ${BASH_REMATCH[1]}"
        else
            _err "DNS challenge not added: unknown error - ${response}"
        fi
    fi
}

# Make a request to CloudDNS API.
# Args: $1 (required): HTTP method.
#       $2 (required): Request endpoint.
#       $3 (required): Request data in json format.
# Retv: API response json.
function _api_request() {
    if [ -z "${CLOUDDNS_TOKEN:-}" ]; then
        _login
    fi
    auth_header="Authorization: Bearer $CLOUDDNS_TOKEN"
    _request "$1" "$CLOUDDNS_API/$2" "${3:-}" "${auth_header}" | tr -d '\t\r\n '
}

# Delete a record from DNS zone.
# Args: $1 (required): Record id.
function _delete_record() {
    response=$(_api_request "DELETE" "record/$1")

    # If adding record failed (error:) then print error message
    if [[ "${response// /}" == *'"error"'* ]]; then
        local re='"message":"([^"]+)"'
        if [[ "${response}" =~ ${re} ]]; then
            _err "DNS challenge not added: ${BASH_REMATCH[1]}"
        else
            _err "DNS challenge not added: unknown error - ${response}"
        fi
    fi
}

# Print error message and exit.
# Args: $@ (required): Message to print.
function _err() {
    echo "$@" >&2
    exit 1
}

# Get domain id.
# Args: $1 (required): Domain to get id for.
# Retv: Domain id
function _get_domain_id() {
    local data="{\"search\": [{\"name\": \"clientId\", \"operator\": \"eq\", \"value\": \"${CLOUDDNS_CLIENT_ID}\"}, {\"name\": \"domainName\", \"operator\": \"eq\", \"value\": \"$1.\"}]}"
    response=$(_api_request "POST" "domain/search" "${data}")

    local re='domainType":"[^"]*","id":"([^,]*)",' # Match domain id
    #if [[ "${response//[$'\t\r\n ']}" =~ $re ]]; then
    if [[ "${response}" =~ ${re} ]]; then
        domain_id="${BASH_REMATCH[1]}"
    fi
    if [[ -z "${domain_id:-}" ]]; then
        _err 'Domain name not found on your CloudDNS account'
    fi
    echo "${domain_id}"
}

# Get the main domain for given domain.
# Args: $1 (required): Full domain.
# Retv: Domain root
function _get_domain_root() {
    local data="{\"search\": [{\"name\": \"clientId\", \"operator\": \"eq\", \"value\": \"${CLOUDDNS_CLIENT_ID:-}\"}]}"
    response=$(_api_request "POST" "domain/search" "${data}")

    domain_slice="$1"
    while [[ -z "${domain_root:-}" ]]; do
        if [[ "${response}" =~ domainName\":\"${domain_slice} ]]; then
            domain_root="${domain_slice}"
        fi
        domain_slice="${domain_slice#[^\.]*.}"
    done
    echo "${domain_root}"
}

# Get DNS record id.
# Args: $1 (required): Domain id.
#       $2 (required): DNS record.
# Retv: DNS record id.
function _get_record_id() {
    response=$(_api_request "GET" "domain/$1")
    local re="\"lastDomainRecordList\".*\"id\":\"([^,]*)\"[^}]*\"name\":\"$2.\"," # Match domain id
    if [[ "${response}" =~ ${re} ]]; then
        record_id="${BASH_REMATCH[1]}"
    fi
    if [[ -z "${record_id:-}" ]]; then
        _err 'Challenge record does not exist'
    fi
    echo "${record_id}"
}

# Login to CloudDNS and get access token.
# Exports: CLOUDDNS_TOKEN.
function _login() {
    if [ -z "${CLOUDDNS_PASSWORD:-}" ] || [ -z "${CLOUDDNS_EMAIL:-}" ] || [ -z "${CLOUDDNS_CLIENT_ID:-}" ]; then
        _err "You didn't specify a CloudDNS password, email and client ID yet."
    fi

    login_data="{\"email\": \"$CLOUDDNS_EMAIL\", \"password\": \"$CLOUDDNS_PASSWORD\"}"
    response="$(_request "POST" "$CLOUDDNS_LOGIN_API" "$login_data")"

    re='"accessToken":"([^,]*)",' # Match access token
    if [[ "${response// /}" =~ $re ]]; then
        export CLOUDDNS_TOKEN="${BASH_REMATCH[1]}"
    else
        _err 'Could not get CloudDNS access token; check your credentials'
    fi
}

# Published record changed for given domain.
# Args: $1 (required): Domain id.
function _publish_records() {
    _api_request "PUT" "domain/$1/publish" "{\"soaTtl\":300}" >/dev/null
}

# Make an HTTP request.
# Args: $1 (required): HTTP method.
#       $2 (required): Request endpoint.
#       $3 (required): Request data in JSON format.
#       $4 (required): Request headers.
# Retv: HTTP Response.
function _request() {
    if [[ "$1" == "GET" ]]; then
        curl --silent --header "${4:-}" -X "$1" "$2"
    else
        local header='Content-Type: application/json'
        curl --silent --header "${header}" --header "${4:-}" -X "$1" "$2" --data "$3"
    fi
}

# Run the script
main "$@"
