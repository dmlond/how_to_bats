piped() {
  [ -p /dev/stdin ] && return
  false
}
export MOCK_DOCKER_TEMPFILE
function mock_docker() {
  docker_mocks[${#docker_mocks[@]}]=$(join_string_by $'\t' "$@")
  [ -n "$MOCK_DOCKER_TEMPFILE" ] || MOCK_DOCKER_TEMPFILE="$(mktemp ${BATS_TMPDIR}/mock_docker_$(printf %03d ${BATS_TEST_NUMBER}).XXXX)"
  persist_docker_mocks
}

function persist_docker_mocks() {
  declare -p docker_mocks > "$MOCK_DOCKER_TEMPFILE"
}

teardown_docker_mocks() {
  if [ $BATS_TEST_COMPLETED ]; then
    rm -f "$MOCK_DOCKER_TEMPFILE"
  else
    echo "** Did not delete $MOCK_DOCKER_TEMPFILE, as test failed **"
  fi
}

function join_string_by { local IFS="$1"; shift; echo "$*"; }

function docker() {
  args=$(join_string_by $'\t' "$@")
  if [ -n "${MOCK_DOCKER_TEMPFILE}" ]
  then
    . "${MOCK_DOCKER_TEMPFILE}"
  fi
  if [ ${#docker_mocks[@]} -gt 0 ]
  then
    for index in $(seq 1 ${#docker_mocks[@]})
    do
      mock="${docker_mocks[$index-1]}"
      match_length=$(expr "${mock}" : "${args}")
      if [ $match_length -gt 0 ]
      then
        unset docker_mocks[$index-1]
        docker_mocks=("${docker_mocks[@]}")
        persist_docker_mocks
        expected_exit_status=0
        echo "${mock}" | grep 'and_fail' > /dev/null 2>&1
        if [ $? -eq 0 ]
        then
          echo "Error" >&2
          expected_exit_status=1
          mock="$(echo "${mock%$'\t'and_fail}")"
        fi

        echo "${mock}" | grep 'to_output' >/dev/null 2>&1
        if [ $? -gt 0 ]
        then
          echo "${*}"
        else
          echo "${mock##*$'\t'}"
        fi
        if piped
        then
          read piped_input
          echo "${piped_input} piped"
        fi
        return $expected_exit_status
      fi
    done
  fi
  echo "docker error"
  return 22
}
export -f docker persist_docker_mocks
