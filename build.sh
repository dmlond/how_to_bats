#!/bin/bash


local required_env="CI_COMMIT_REF_SLUG CI_PROJECT_NAME"

for reqvar in $required_env
do
  if [ -z ${!reqvar} ]
  then
    echo "missing ENVIRONMENT ${reqvar}!" >&2
    exit 1
  fi
done

if [ ! ${DO_NOT_PUBLISH} ]
then
  local required_publish_env="CI_REGISTRY CI_REGISTRY_USER CI_REGISTRY_PASSWORD CI_REGISTRY_IMAGE"

  for reqvar in $required_publish_env
  do
    if [ -z ${!reqvar} ]
    then
      echo "missing ENVIRONMENT ${reqvar} REQUIRED TO PUBLISH!
      SET DO_NOT_PUBLISH=1 TO SKIP PUBLISHING TO THE GITLAB REGISTRY
      " >&2
      exit 1
    fi
  done

  echo "
  logging into ${CI_REGISTRY}
  "
  if [ ${DRY_RUN} ]
  then
    echo "skipping for dry run" >&2
  else
    docker login -u ${CI_REGISTRY_USER} -p ${CI_REGISTRY_PASSWORD} ${CI_REGISTRY}
  fi
fi

environment=$(echo "${CI_COMMIT_REF_SLUG}" | sed "s/\-deployment.*//" | sed "s/\_/\-/g")
application=$(echo "${CI_PROJECT_NAME}" | sed "s/\_/\-/g")

local candidate_image="${application}-candidate:${environment}"
echo "
Building candidate ${candidate_image}
" >&2

if [ ${DRY_RUN} ]
then
  echo "skipping for dry run" >&2
else
  docker build --pull -t "${candidate_image}" .
  if [ $? -gt 0 ]
  then
    echo "Problem in the Build" >&2
    exit 1
  fi
fi

if [ -z ${DO_NOT_PUBLISH} ]
then
  local publishable_image="${CI_REGISTRY_IMAGE}/${candidate_image}"
  echo "
  tagging ${image} as ${publishable_image}
  "
  if [ ${DRY_RUN} ]
  then
    echo "skipping for dry run" >&2
  else
    docker tag "${image}" "${publishable_image}"
    if [ $? -gt 0 ]
    then
      echo "Problem Tagging" >&2
      exit 1
    fi
  fi
  echo "
  pushing image to gitlab registry
  "
  if [ ${DRY_RUN} ]
  then
    echo "skipping for dry run" >&2
  else
    docker push "${publishable_image}"
  fi
fi
echo "ALL COMPLETE" >&2
