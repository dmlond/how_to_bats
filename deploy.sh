#!/bin/sh
required_env="CI_COMMIT_REF_SLUG CI_PROJECT_NAME OPENSHIFT_API_URL OPENSHIFT_API_TOKEN OPENSHIFT_PROJECT"

for reqvar in $required_env
do
  if [ -z ${!reqvar} ]
  then
    echo "missing ENVIRONMENT ${reqvar}!" >&2
    exit 1
  fi
done

oc login "${OPENSHIFT_API_URL}" ${OC_PARAMETERS} --token="${OPENSHIFT_API_TOKEN}"
if [ $? -gt 0 ]
then
  echo "Could not login" >&2
  exit 1
fi
oc ${OC_PARAMETERS} whoami
oc ${OC_PARAMETERS} project "${OPENSHIFT_PROJECT}"

environment=$(echo "${CI_COMMIT_REF_SLUG}" | sed "s/\-deployment.*//" | sed "s/\_/\-/g")
application=$(echo "${CI_PROJECT_NAME}" | sed "s/\_/\-/g")

for application_id in `oc ${OC_PARAMETERS} rollout history dc/${application} | awk '{print $1}' | grep "^${environment}"`
do
  oc ${OC_PARAMETERS} rollout latest dc/${application_id}
  if [ $? -gt 0 ]
  then
    echo "deployment_config ${application_id} does not exist!" >&2
    exit 1
  fi

  latest_deployed_version=$(oc ${OC_PARAMETERS} get dc/${application_id} -o json | jq -r '.status.latestVersion')
  if [ -z "${latest_deployed_version}" ]
  then
    exit 1
  fi
  current_status=$(oc ${OC_PARAMETERS} rollout history dc/${application_id} | awk '{print $1}' | grep "^${latest_deployed_version}")
  [ -z "${current_status}" ] && exit 1

  while [ "${current_status}" = "Running" ]
  do
    sleep 5
    current_status=$(oc ${OC_PARAMETERS} rollout history dc/${application_id} | awk '{print $1}' | grep "^${latest_deployed_version}") || exit 1
    [ -z "${current_status}" ] && exit 1
  done

  if [ "${current_status}" = "Failed" ]
  then
    echo "${application_id} Deployment Failed" >&2
    oc ${OC_PARAMETERS} logs dc/${application_id}
    exit 1
  fi
  echo "${application_id} Deployment Successful!" >&2
done
