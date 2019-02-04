#!/bin/bash
# This script builds the nodejs image for the application
# with its devDependencies as ${application}-candidate:${environment}
# so that it can be used for testing in later pipeline stages
raise()
{
  echo "${1}" >&2
}

check_required_environment() {
  local required_env="CI_COMMIT_REF_SLUG CI_PROJECT_NAME"

  for reqvar in $required_env
  do
    if [ -z ${!reqvar} ]
    then
      raise "missing ENVIRONMENT ${reqvar}!"
      return 1
    fi
  done
}

check_required_publish_environment() {
  [ ${DO_NOT_PUBLISH} ] && return
  local required_publish_env="CI_REGISTRY CI_REGISTRY_USER CI_REGISTRY_PASSWORD CI_REGISTRY_IMAGE"

  for reqvar in $required_publish_env
  do
    if [ -z ${!reqvar} ]
    then
      raise "missing ENVIRONMENT ${reqvar} REQUIRED TO PUBLISH!
      SET DO_NOT_PUBLISH=1 TO SKIP PUBLISHING TO THE GITLAB REGISTRY
      "
      return 1
    fi
  done
}

login() {
  [ ${DO_NOT_PUBLISH} ] && return

  check_required_publish_environment || return 1
  echo "
  logging into ${CI_REGISTRY}
  "
  dry_run && return
  docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
}

dry_run() {
  [ ${DRY_RUN} ] && raise "skipping for dry run" && return
  return 1
}

build_candidate() {
  local candidate_image="${1}-candidate:${2}"
  raise "
  Building candidate ${candidate_image}
  "

  if ! dry_run
  then
    docker build --pull -t "${candidate_image}" .
    if [ $? -gt 0 ]
    then
      raise "Problem in the Build"
      return 1
    fi
  fi
  publish_image "${candidate_image}"
}

publish_image() {
  [ ${DO_NOT_PUBLISH} ] && return
  local image="${1}"
  local publishable_image="${CI_REGISTRY_IMAGE}/${image}"
  echo "
  tagging ${image} as ${publishable_image}
  "
  if ! dry_run
  then
    docker tag "${image}" "${publishable_image}"
    if [ $? -gt 0 ]
    then
      raise "Problem Tagging"
      return 1
    fi
  fi
  echo "
  pushing image to gitlab registry
  "

  dry_run && return
  docker push "${publishable_image}"
}

run_main() {
  check_required_environment || exit 1
  login || exit 1

  environment=$(echo "${CI_COMMIT_REF_SLUG}" | sed "s/\-deployment.*//" | sed "s/\_/\-/g")
  application=$(echo "${CI_PROJECT_NAME}" | sed "s/\_/\-/g")

  build_candidate "${application}" "${environment}" || return 1
  raise "ALL COMPLETE"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
  run_main
  if [ $? -gt 0 ]
  then
    exit 1
  fi
fi
