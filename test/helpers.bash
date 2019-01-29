assert_file_exists() {
  assert [ -f "$1" ]
}
assert_dir_exists() {
  assert [ -d "$1" ]
}
refute_file_exists() {
  assert [ ! -f "$1" ]
}
refute_dir_exists() {
  assert [ ! -d "$1" ]
}
assert_empty(){
  assert [ -z "${1}" ]
}
refute_empty(){
  assert [ ! -z "${1}" ]
}
