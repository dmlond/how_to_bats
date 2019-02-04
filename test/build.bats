#!/usr/bin/env ./test/libs/bats/bin/bats
load 'libs/bats-support/load'
load 'libs/bats-assert/load'
load 'helpers'
load 'docker_mock'

profile_script="./bin/build.sh"

setup() {
  export CI_COMMIT_REF_SLUG="CI_COMMIT_REF_SLUG"
  export CI_PROJECT_NAME="CI_PROJECT_NAME"
}

teardown() {
  teardown_docker_mocks
}

setup_publish() {
  # required to publish
  export CI_REGISTRY="CI_REGISTRY"
  export CI_REGISTRY_USER="CI_REGISTRY_USER"
  export CI_REGISTRY_PASSWORD="CI_REGISTRY_PASSWORD"
  export CI_REGISTRY_IMAGE="CI_REGISTRY_IMAGE"
}

@test ".check_required_environment requires CI_COMMIT_REF_SLUG environment variable" {
  unset CI_COMMIT_REF_SLUG
  assert_empty "${CI_COMMIT_REF_SLUG}"
  source ${profile_script}
  run check_required_environment
  assert_failure
  assert_output --partial "CI_COMMIT_REF_SLUG"
}

@test ".check_required_environment requires CI_PROJECT_NAME environment variable" {
  unset CI_PROJECT_NAME
  assert_empty "${CI_PROJECT_NAME}"
  source ${profile_script}
  run check_required_environment
  assert_failure
  assert_output --partial "CI_PROJECT_NAME"
}

@test ".check_required_environment is successful if required environment is present" {
  source ${profile_script}
  run check_required_environment
  assert_success
}

@test ".check_required_publish_environment requires CI_REGISTRY environment variable when DO_NOT_PUBLISH is not present" {
  setup_publish
  unset CI_REGISTRY
  assert_empty "${CI_REGISTRY}"
  source ${profile_script}
  run check_required_publish_environment
  assert_failure
  assert_output --partial "CI_REGISTRY"
}

@test ".check_required_publish_environment does not require CI_REGISTRY environment variable when DO_NOT_PUBLISH is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  unset CI_REGISTRY
  assert_empty "${CI_REGISTRY}"
  source ${profile_script}
  run check_required_publish_environment
  assert_success
  refute_output --partial "CI_REGISTRY"
}

@test ".check_required_publish_environment requires CI_REGISTRY_USER environment variable when DO_NOT_PUBLISH is not present" {
  setup_publish
  unset CI_REGISTRY_USER
  assert_empty "${CI_REGISTRY_USER}"
  source ${profile_script}
  run check_required_publish_environment
  assert_failure
  assert_output --partial "CI_REGISTRY_USER"
}

@test ".check_required_publish_environment does not require CI_REGISTRY_USER environment variable when DO_NOT_PUBLISH is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  unset CI_REGISTRY_USER
  assert_empty "${CI_REGISTRY_USER}"
  source ${profile_script}
  run check_required_publish_environment
  assert_success
  refute_output --partial "CI_REGISTRY_USER"
}

@test ".check_required_publish_environment requires CI_REGISTRY_PASSWORD environment variable when DO_NOT_PUBLISH is not present" {
  setup_publish
  unset CI_REGISTRY_PASSWORD
  assert_empty "${CI_REGISTRY_PASSWORD}"
  source ${profile_script}
  run check_required_publish_environment
  assert_failure
  assert_output --partial "CI_REGISTRY_PASSWORD"
}

@test ".check_required_publish_environment does not require CI_REGISTRY_PASSWORD environment variable when DO_NOT_PUBLISH is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  unset CI_REGISTRY_PASSWORD
  assert_empty "${CI_REGISTRY_PASSWORD}"
  source ${profile_script}
  run check_required_publish_environment
  assert_success
  refute_output --partial "CI_REGISTRY_PASSWORD"
}

@test ".check_required_publish_environment requires CI_REGISTRY_IMAGE environment variable when DO_NOT_PUBLISH is not present" {
  setup_publish
  unset CI_REGISTRY_IMAGE
  assert_empty "${CI_REGISTRY_IMAGE}"
  source ${profile_script}
  run check_required_publish_environment
  assert_failure
  assert_output --partial "CI_REGISTRY_IMAGE"
}

@test ".check_required_publish_environment does not require CI_REGISTRY_IMAGE environment variable when DO_NOT_PUBLISH is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  unset CI_REGISTRY_IMAGE
  assert_empty "${CI_REGISTRY_IMAGE}"
  source ${profile_script}
  run check_required_publish_environment
  assert_success
  refute_output --partial "CI_REGISTRY_IMAGE"
}

@test ".check_required_publish_environment is successful when DO_NOT_PUBLISH is absent and required environment is present" {
  setup_publish
  source ${profile_script}
  run check_required_publish_environment
  assert_success
}

@test ".dry_run returns true if the DRY_RUN environment is present" {
  export DRY_RUN=1
  source ${profile_script}
  run dry_run
  assert_success
}

@test ".dry_run returns false if the DRY_RUN environment is not present" {
  assert_empty "${DRY_RUN}"
  source ${profile_script}
  run dry_run
  assert_failure
}

@test ".login does not call check_required_publish_environment, print information, or run docker login when DO_NOT_PUBLISH environment variable is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  function check_required_publish_environment() { echo "check_required_publish_environment called"; }
  export -f check_required_publish_environment
  mock_docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
  source ${profile_script}
  run login
  assert_success
  refute_output -p "check_required_environment called"
  refute_output -p "logging into ${CI_REGISTRY}"
  refute_output -p "login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}"
  unset DO_NOT_PUBLISH
}
@test ".login calls check_required_publish_environment and prints information without calling docker login when DO_NOT_PUBLISH environment variable is not present but it is a dry_run" {

  setup_publish
  source ${profile_script}
  function dry_run() { echo "dry_run called"; return; };
  function check_required_publish_environment() { echo "check_required_publish_environment called"; return; }
  export -f dry_run check_required_publish_environment
  mock_docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
  run login
  assert_output -p "check_required_publish_environment called"
  assert_output -p "logging into ${CI_REGISTRY}"
  refute_output -p "login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}"
}

@test ".login calls check_required_publish_environment, prints information, and calls docker login when DO_NOT_PUBLISH environment variable is not present and it is not a dry_run" {
  source ${profile_script}
  setup_publish
  function check_required_publish_environment() { echo "check_required_publish_environment called"; }
  export -f check_required_publish_environment
  mock_docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
  run login
  assert_output -p "check_required_publish_environment called"
  assert_output -p "logging into ${CI_REGISTRY}"
  assert_output -p "login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}"
}

@test ".build_candidate takes an application and environment to use in naming the candidate image, prints information, runs docker build and publish_image on the candidate image when its not a dry_run" {
  local application='application'
  local environment='environment'
  local expected_candidate_image="${application}-candidate:${environment}"
  source ${profile_script}
  mock_docker build --pull -t "${expected_candidate_image}" .
  function publish_image() { echo "publishing ${1}"; }
  export -f publish_image
  run build_candidate "${application}" "${environment}"
  assert_success
  assert_output -p "Building candidate ${expected_candidate_image}"
  assert_output -p "build --pull -t ${expected_candidate_image} ."
  assert_output -p "publishing ${expected_candidate_image}"
}

@test ".build_candidate fails when docker build fails" {
  local application='application'
  local environment='environment'
  local expected_candidate_image="${application}-candidate:${environment}"
  source ${profile_script}
  mock_docker build --pull -t "${expected_candidate_image}" . and_fail
  function publish_image() { echo "publishing ${1}"; }
  export -f publish_image
  run build_candidate "${application}" "${environment}"
  assert_failure
  assert_output -p "Building candidate ${expected_candidate_image}"
  assert_output -p "build --pull -t ${expected_candidate_image} ."
  refute_output -p "publishing ${expected_candidate_image}"
  assert_output -p "Problem in the Build"
}

@test ".build_candidate fails when publish_image fails" {
  local application='application'
  local environment='environment'
  local expected_candidate_image="${application}-candidate:${environment}"
  source ${profile_script}
  mock_docker build --pull -t "${expected_candidate_image}" .
  function publish_image() { echo "publishing ${1}"; return 1; }
  export -f publish_image
  run build_candidate "${application}" "${environment}"
  assert_failure
  assert_output -p "Building candidate ${expected_candidate_image}"
  assert_output -p "build --pull -t ${expected_candidate_image} ."
  assert_output -p "publishing ${expected_candidate_image}"
}

@test ".build_candidate only prints information and runs publish_image when its a dry_run" {
  local application='application'
  local environment='environment'
  local expected_candidate_image="${application}-candidate:${environment}"
  source ${profile_script}
  mock_docker build --pull -t "${expected_candidate_image}" .
  function publish_image() { echo "publishing ${1}"; }
  export -f publish_image
  function dry_run() { return; }
  run build_candidate "${application}" "${environment}"
  assert_success
  assert_output -p "Building candidate ${expected_candidate_image}"
  refute_output -p "build --pull -t ${expected_candidate_image} ."
  assert_output -p "publishing ${expected_candidate_image}"
}

@test ".publish_image does not print information, docker tag, or docker push if DO_NOT_PUBLISH environment variable is present" {
  setup_publish
  export DO_NOT_PUBLISH=1
  local expected_image="image"
  local expected_publishable_image="${CI_REGISTRY_IMAGE}/${expected_image}"
  source ${profile_script}
  mock_docker tag "${expected_image}" "${expected_publishable_image}"
  mock_docker push "${expected_publishable_image}"
  run publish_image "${expected_image}"
  assert_success
  refute_output -p "tagging ${expected_image} as ${expected_publishable_image}"
  refute_output -p "tag ${expected_image} ${expected_publishable_image}"
  refute_output -p "pushing image to gitlab registry"
  refute_output -p "push ${expected_publishable_image}"
}

@test ".publish_image prints information, runs docker tag, and docker push if DO_NOT_PUBLISH environment variable is not present" {
  setup_publish
  local expected_image="image"
  local expected_publishable_image="${CI_REGISTRY_IMAGE}/${expected_image}"
  source ${profile_script}
  mock_docker tag "${expected_image}" "${expected_publishable_image}"
  mock_docker push "${expected_publishable_image}"
  run publish_image "${expected_image}"
  assert_success
  assert_output -p "tagging ${expected_image} as ${expected_publishable_image}"
  assert_output -p "tag ${expected_image} ${expected_publishable_image}"
  assert_output -p "pushing image to gitlab registry"
  assert_output -p "push ${expected_publishable_image}"
}

@test ".publish_image fails if docker tag fails" {
  setup_publish
  local expected_image="image"
  local expected_publishable_image="${CI_REGISTRY_IMAGE}/${expected_image}"
  source ${profile_script}
  mock_docker tag "${expected_image}" "${expected_publishable_image}" and_fail
  mock_docker push "${expected_publishable_image}"
  run publish_image "${expected_image}"
  assert_failure
  assert_output -p "tagging ${expected_image} as ${expected_publishable_image}"
  assert_output -p "tag ${expected_image} ${expected_publishable_image}"
  refute_output -p "pushing image to gitlab registry"
  refute_output -p "push ${expected_publishable_image}"
}

@test ".publish_image fails if docker push fails" {
  setup_publish
  local expected_image="image"
  local expected_publishable_image="${CI_REGISTRY_IMAGE}/${expected_image}"
  source ${profile_script}
  mock_docker tag "${expected_image}" "${expected_publishable_image}"
  mock_docker push "${expected_publishable_image}" and_fail
  run publish_image "${expected_image}"
  assert_failure
  assert_output -p "tagging ${expected_image} as ${expected_publishable_image}"
  assert_output -p "tag ${expected_image} ${expected_publishable_image}"
  assert_output -p "pushing image to gitlab registry"
  assert_output -p "push ${expected_publishable_image}"
}

@test ".publish_image prints information, does not run docker tag or docker push if DO_NOT_PUBLISH environment variable is not present but its a dry_run" {
  setup_publish
  local expected_image="image"
  local expected_publishable_image="${CI_REGISTRY_IMAGE}/${expected_image}"
  source ${profile_script}
  mock_docker tag "${expected_image}" "${expected_publishable_image}"
  mock_docker push "${expected_publishable_image}"
  function dry_run() { return; }
  export -f dry_run
  run publish_image "${expected_image}"
  assert_success
  assert_output -p "tagging ${expected_image} as ${expected_publishable_image}"
  refute_output -p "tag ${expected_image} ${expected_publishable_image}"
  assert_output -p "pushing image to gitlab registry"
  refute_output -p "push ${expected_publishable_image}"
}

@test ".run_main calls check_required_environment, login, and build_candidate when the environment" {
  setup_publish
  local expected_environment=$(echo "${CI_COMMIT_REF_SLUG}" | sed "s/\-deployment.*//" | sed "s/\_/\-/g")
  local expected_application=$(echo "${CI_PROJECT_NAME}" | sed "s/\_/\-/g")
  source ${profile_script}

  function check_required_environment() { echo "check_required_environment called"; }
  export -f check_required_environment
  function login() { echo "login called"; }
  export -f login
  function build_candidate() { echo "build_candidate ${*} called"; }
  export -f build_candidate;

  run run_main
  assert_success
  assert_output -p "check_required_environment called"
  assert_output -p "login called"
  assert_output -p "build_candidate ${expected_application} ${expected_environment}"
}
