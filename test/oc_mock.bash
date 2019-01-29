piped() {
  [ -p /dev/stdin ] && return
  false
}
export MOCK_OC_TEMPFILE
function mock_oc() {
  oc_mocks[${#oc_mocks[@]}]=$(join_string_by $'\t' "$@")
  [ -n "$MOCK_OC_TEMPFILE" ] || MOCK_OC_TEMPFILE="$(mktemp ${BATS_TMPDIR}/mock_oc_$(printf %03d ${BATS_TEST_NUMBER}).XXXX)"
  persist_oc_mocks
}

function persist_oc_mocks() {
  declare -p oc_mocks > "$MOCK_OC_TEMPFILE"
}

teardown_oc_mocks() {
  if [ $BATS_TEST_COMPLETED ]; then
    rm -f "$MOCK_OC_TEMPFILE"
  else
    echo "** Did not delete $MOCK_OC_TEMPFILE, as test failed **"
  fi
}

function join_string_by { local IFS="$1"; shift; echo "$*"; }

function oc() {
  args=$(join_string_by $'\t' "$@")
  if [ -n "${MOCK_OC_TEMPFILE}" ]
  then
    . "${MOCK_OC_TEMPFILE}"
  fi
  if [ ${#oc_mocks[@]} -gt 0 ]
  then
    for index in $(seq 1 ${#oc_mocks[@]})
    do
      mock="${oc_mocks[$index-1]}"
      match_length=$(expr "${mock}" : "${args}")
      if [ $match_length -gt 0 ]
      then
        unset oc_mocks[$index-1]
        oc_mocks=("${oc_mocks[@]}")
        persist_oc_mocks
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
  echo "oc error"
  return 22
}
export -f oc persist_oc_mocks
