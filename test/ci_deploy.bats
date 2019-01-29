#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'helpers'
load 'oc_mock'

profile_script="./bin/ci/deploy"

setup() {
  export CI_COMMIT_REF_SLUG="CI_COMMIT_REF_SLUG"
  export CI_PROJECT_NAME="CI_PROJECT_NAME"
  export OPENSHIFT_API_URL="OPENSHIFT_API_URL"
  export OPENSHIFT_API_TOKEN="OPENSHIFT_API_TOKEN"
  export OPENSHIFT_PROJECT="OPENSHIFT_PROJECT"
}

teardown() {
  teardown_oc_mocks
}

@test "requires CI_COMMIT_REF_SLUG environment variable" {
  unset CI_COMMIT_REF_SLUG
  assert_empty "${CI_COMMIT_REF_SLUG}"
  run ${profile_script}
  assert_failure
  assert_output --partial "CI_COMMIT_REF_SLUG"
}

@test "requires CI_PROJECT_NAME environment variable" {
  unset CI_PROJECT_NAME
  assert_empty "${CI_PROJECT_NAME}"
  run ${profile_script}
  assert_failure
  assert_output --partial "CI_PROJECT_NAME"
}

@test "requires OPENSHIFT_API_URL environment variable" {
  unset OPENSHIFT_API_URL
  assert_empty "${OPENSHIFT_API_URL}"
  run ${profile_script}
  assert_failure
  assert_output --partial "OPENSHIFT_API_URL"
}

@test "requires OPENSHIFT_API_TOKEN environment variable" {
  unset OPENSHIFT_API_TOKEN
  assert_empty "${OPENSHIFT_API_TOKEN}"
  run ${profile_script}
  assert_failure
  assert_output --partial "OPENSHIFT_API_TOKEN"
}

@test "requires OPENSHIFT_PROJECT environment variable" {
  unset OPENSHIFT_PROJECT
  assert_empty "${OPENSHIFT_PROJECT}"
  run ${profile_script}
  assert_failure
  assert_output --partial "OPENSHIFT_PROJECT"
}

@test ".check_required_environment raises if required environment is missing" {
  unset OPENSHIFT_PROJECT
  source ${profile_script}
  function raise() { echo "${1} raised"; }
  export -f raise
  run check_required_environment
  assert_failure
  assert_output -p "missing ENVIRONMENT OPENSHIFT_PROJECT! raised"
}

@test ".check_required_environment is successful if requierd environment is present" {
  source ${profile_script}
  run check_required_environment
  assert_success
}

@test ".login raises on oc error" {
  source ${profile_script}
  function raise() { echo "${1} raised"; }
  export -f raise
  run login
  assert_failure
  assert_output -p "Could not login raised"
}

@test ".login logs in, prints user and changes to project" {
  expected_user="USER@host"
  source ${profile_script}
  mock_oc login "${OPENSHIFT_API_URL}" --token="${OPENSHIFT_API_TOKEN}"
  mock_oc whoami to_output "${expected_user}"
  mock_oc project "${OPENSHIFT_PROJECT}" to_output "${OPENSHIFT_PROJECT}"
  run login
  assert_success
  assert_output -e ".*${OPENSHIFT_API_URL}.*--token=${OPENSHIFT_API_TOKEN}.*"
  assert_output -p "${expected_user}"
  assert_output -p "${OPENSHIFT_PROJECT}"
}

@test ".login uses OC_PARAMETERS in oc calls" {
  export OC_PARAMETERS="--oc-parameters"
  source ${profile_script}
  mock_oc login "${OPENSHIFT_API_URL}" ${OC_PARAMETERS} --token="${OPENSHIFT_API_TOKEN}"
  mock_oc ${OC_PARAMETERS} whoami
  mock_oc ${OC_PARAMETERS} project "${OPENSHIFT_PROJECT}"
  run login
  assert_success
  assert_output -e ".*${OPENSHIFT_API_URL}.*${OC_PARAMETERS}.*--token=${OPENSHIFT_API_TOKEN}.*"
  assert_output -p "${OC_PARAMETERS} whoami"
  assert_output -p "${OC_PARAMETERS} project ${OPENSHIFT_PROJECT}"
}

@test ".deployments takes application and environment and returns a list of names of deployment_configs" {
  this_app="this-application"
  this_environment="this-environment"
  expected_dcs='{"items":[{"metadata":{"name":"dc1"}},{"metadata":{"name":"dc2"}}]}'
  expected_dc_names="dc1"$'\n'"dc2"
  source ${profile_script}
  mock_oc get dc -l app=${this_app},environment=${this_environment} -o json to_output "${expected_dcs}"
  run deployments "${this_app}" "${this_environment}"
  assert_success
  assert_output -p "${expected_dc_names}"
}

@test ".deployments fails if oc call fails" {
  this_app="this-application"
  this_environment="this-environment"
  source ${profile_script}
  mock_oc get dc -l app=${this_app},environment=${this_environment} -o json to_output "Error" and_fail
  run deployments "${this_app}" "${this_environment}"
  assert_failure
  assert_output -p "Error"
}

@test ".deployments uses OC_PARAMETERS" {
  export OC_PARAMETERS='--oc-parameters foo'
  this_app="this-application"
  this_environment="this-environment"
  expected_dcs='{"items":[{"metadata":{"name":"dc1"}},{"metadata":{"name":"dc2"}}]}'
  expected_dc_names="dc1"$'\n'"dc2"
  source ${profile_script}
  mock_oc ${OC_PARAMETERS} get dc -l app=${this_app},environment=${this_environment} -o json to_output "${expected_dcs}"
  run deployments "${this_app}" "${this_environment}"
  assert_success
  assert_output -p "${expected_dc_names}"
}

@test ".deploy_latest takes application_id and rolls out the latest deployment" {
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc rollout latest dc/${this_app_id}
  run deploy_latest "${this_app_id}"
  assert_success
  assert_output -p "rollout latest dc/${this_app_id}"
}

@test ".deploy_latest fails if oc call fails" {
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc rollout latest dc/${this_app_id} to_output "Error" and_fail
  run deploy_latest "${this_app_id}"
  assert_failure
  assert_output -p "Error"
}

@test ".deploy_latest uses OC_PARAMETERS" {
  export OC_PARAMETERS='--oc-parameters foo'
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc ${OC_PARAMETERS} rollout latest dc/${this_app_id}
  run deploy_latest "${this_app_id}"
  assert_success
  assert_output -p "rollout latest dc/${this_app_id}"
}

@test ".latest_deployed_version takes application_id returns the latest deployed version of the dc" {
  this_app_id="this-application-id"
  expected_latest_version="3"
  expected_dc="{\"status\":{\"latestVersion\":\"${expected_latest_version}\"}}"
  source ${profile_script}
  mock_oc get dc/${this_app_id} -o json to_output "${expected_dc}"
  run latest_deployed_version "${this_app_id}"
  assert_success
  assert_output -p "${expected_latest_version}"
}

@test ".latest_deployed_version fails if oc call fails" {
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc get dc/${this_app_id} -o json to_output "Error" and_fail
  run latest_deployed_version "${this_app_id}"
  assert_failure
  assert_output -p "could not get latest version for ${this_app_id}"
}

@test ".latest_deployed_version uses OC_PARAMETERS" {
  export OC_PARAMETERS='--oc-parameters foo'
  this_app_id="this-application-id"
  expected_latest_version="3"
  expected_dc="{\"status\":{\"latestVersion\":\"${expected_latest_version}\"}}"
  source ${profile_script}
  mock_oc ${OC_PARAMETERS} get dc/${this_app_id} -o json to_output "${expected_dc}"
  run latest_deployed_version "${this_app_id}"
  assert_success
  assert_output -p "${expected_latest_version}"
}

@test ".deployment_status takes application_id and version returns status of the deployment" {
  this_app_id="this-application-id"
  this_version="2"
  expected_status="Complete"
  expected_dc="${this_version} ${expected_status} manual change"
  source ${profile_script}
  mock_oc rollout history dc/${this_app_id} to_output "${expected_dc}"
  run deployment_status "${this_app_id}" "${this_version}"
  assert_success
  assert_output "${this_version}"
}

@test ".deployment_status fails if oc fails" {
  this_app_id="this-application-id"
  this_version="2"
  source ${profile_script}
  mock_oc rollout history dc/${this_app_id} and_fail
  run deployment_status "${this_app_id}" "${this_version}"
  assert_failure
  assert_output -p "could not get status for ${this_app_id} ${this_version}"
}

@test ".deployment_status fails if rollout version is not found" {
  this_app_id="this-application-id"
  this_version="2"
  expected_status="Complete"
  expected_dc="10 ${expected_status} manual change"
  source ${profile_script}
  mock_oc rollout history dc/${this_app_id} to_output "${expected_dc}"
  run deployment_status "${this_app_id}" "${this_version}"
  assert_failure
  assert_output -p "could not get status for ${this_app_id} ${this_version}"
}

@test ".deployment_status uses OC_PARAMETERS" {
  export OC_PARAMETERS='--oc-parameters foo'
  this_app_id="this-application-id"
  this_version="2"
  expected_status="Complete"
  expected_dc="${this_version} ${expected_status} manual change"
  source ${profile_script}
  mock_oc ${OC_PARAMETERS} rollout history dc/${this_app_id} to_output "${expected_dc}"
  run deployment_status "${this_app_id}" "${this_version}"
  assert_success
  assert_output -p "${this_version}"
}

@test ".print_log takes application_id prints the log of the dc" {
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc logs dc/${this_app_id}
  run print_log "${this_app_id}"
  assert_success
  assert_output -p "logs dc/${this_app_id}"
}

@test ".print_log uses OC_PARAMETERS" {
  export OC_PARAMETERS='--oc-parameters foo'
  this_app_id="this-application-id"
  source ${profile_script}
  mock_oc ${OC_PARAMETERS} logs dc/${this_app_id}
  run print_log "${this_app_id}"
  assert_success
  assert_output -p "logs dc/${this_app_id}"
}
