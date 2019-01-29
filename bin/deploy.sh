#!/bin/sh

raise()
{
  echo "${1}" >&2
}

check_required_environment() {
  required_env="CI_COMMIT_REF_SLUG CI_PROJECT_NAME OPENSHIFT_API_URL OPENSHIFT_API_TOKEN OPENSHIFT_PROJECT"

  for reqvar in $required_env
  do
    if [ -z ${!reqvar} ]
    then
      raise "missing ENVIRONMENT ${reqvar}!"
      return 1
    fi
  done
}

login() {
  oc login "${OPENSHIFT_API_URL}" ${OC_PARAMETERS} --token="${OPENSHIFT_API_TOKEN}"
  if [ $? -gt 0 ]
  then
    raise "Could not login"
    return 1
  fi
  oc ${OC_PARAMETERS} whoami
  oc ${OC_PARAMETERS} project "${OPENSHIFT_PROJECT}"
}

deployments() {
  raise "deployments $*"
  local application="${1}"
  local environment="${2}"

  oc ${OC_PARAMETERS} get dc -l app=${application},environment=${environment} -o json | jq -r '.items[].metadata.name'
  if [ $? -gt 0 ]
  then
    echo "Could not get deployment configurations for ${application} ${environment}" >&2
    exit 1
  fi
}

deploy_latest() {
  raise "deploy_latest $*"
  local application_id="${1}"
  oc ${OC_PARAMETERS} rollout latest dc/${application_id}
  if [ $? -gt 0 ]
  then
    raise "deployment_config ${application_id} does not exist!"
    return 1
  fi
}

latest_deployed_version() {
  raise "latest_deployed_version $*"
  local application_id="${1}"
  oc ${OC_PARAMETERS} get dc/${application_id} -o json | jq -r '.status.latestVersion'
  if [ $? -gt 0 ]
  then
    raise "could not get latest version for ${application_id}"
    return 1
  fi
}

deployment_status() {
  local application_id="${1}"
  local version="${2}"
  oc ${OC_PARAMETERS} rollout history dc/${application_id} | awk '{print $1}' | grep "^${version}"
  if [ $? -gt 0 ]
  then
    raise "could not get status for ${application_id} ${version}"
    return 1
  fi
}

print_log() {
  raise "print_log $*"
  local application_id="${1}"
  oc ${OC_PARAMETERS} logs dc/${application_id}
}

run_main() {
  check_required_environment || exit 1
  login || exit 1

  environment=$(echo "${CI_COMMIT_REF_SLUG}" | sed "s/\-deployment.*//" | sed "s/\_/\-/g")
  application=$(echo "${CI_PROJECT_NAME}" | sed "s/\_/\-/g")

  for application_id in `deployments "${application}" "${environment}"`
  do
    deploy_latest "${application_id}" || exit 1
    latest_deployed_version=$(latest_deployed_version "${application_id}")
    if [ -z "${latest_deployed_version}" ]
    then
      exit 1
    fi
    current_status=$(deployment_status "${application_id}" "${latest_deployed_version}")
    [ -z "${current_status}" ] && exit 1
    while [ "${current_status}" = "Running" ]
    do
      sleep 5
      current_status=$(deployment_status "${application_id}" "${latest_deployed_version}") || exit 1
      [ -z "${current_status}" ] && exit 1
    done

    if [ "${current_status}" = "Failed" ]
    then
      raise "${application_id} Deployment Failed"
      print_log "${application_id}"
      exit 1
    fi
    echo "${application_id} Deployment Successful!" >&2
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  run_main
fi
