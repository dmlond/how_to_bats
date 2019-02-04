assert_empty(){
  assert [ -z "${1}" ]
}
refute_empty(){
  assert [ ! -z "${1}" ]
}
