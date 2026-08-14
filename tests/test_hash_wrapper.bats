#!/usr/bin/env bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../actions/checksum_menu@pwlcz/hash_wrapper.sh"

setup() {
  export LC_ALL=C
  export LANG=C
  export LANGUAGE=en

  MOCK_BIN="${BATS_TMPDIR}/mock_bin"
  mkdir -p "$MOCK_BIN"

  export PATH="${MOCK_BIN}:${PATH}"

  export CLIPBOARD_FILE="${BATS_TMPDIR}/clipboard.txt"
  export ZENITY_LOG="${BATS_TMPDIR}/zenity.log"

  rm -f "$CLIPBOARD_FILE" "$ZENITY_LOG"

  # Mock md5sum: print a deterministic hash and the filename
  cat << 'EOF' > "${MOCK_BIN}/md5sum"
#!/bin/bash
echo "deadbeef1234567890abcdef12345678 $1"
EOF
  chmod +x "${MOCK_BIN}/md5sum"

  # Mock zenity: log calls, simulate extra-button behavior and consume stdin
  cat << 'EOF' > "${MOCK_BIN}/zenity"
#!/bin/bash
echo "ZENITY_CALL: $@" >> "$ZENITY_LOG"

# If called with --extra-button=..., echo that button label to stdout (simulate click)
for a in "$@"; do
  case "$a" in
    --extra-button=*)
      label="${a#--extra-button=}"
      echo "$label"
      ;;
  esac
done

# Consume stdin when piped
if [ ! -t 0 ]; then
  cat > /dev/null
fi
exit 0
EOF
  chmod +x "${MOCK_BIN}/zenity"

  # Mock xclip: write stdin to CLIPBOARD_FILE
  cat << 'EOF' > "${MOCK_BIN}/xclip"
#!/bin/bash
cat > "$CLIPBOARD_FILE"
EOF
  chmod +x "${MOCK_BIN}/xclip"

  TEST_FILE="${BATS_TMPDIR}/sample_file.txt"
  echo 'Sample contents' > "$TEST_FILE"
}

teardown() {
  rm -rf "${MOCK_BIN}" "$TEST_FILE" "$CLIPBOARD_FILE" "$ZENITY_LOG"
}

@test "Single file shows Copy Hash button and copies hash to clipboard" {
  run bash "$SCRIPT_UNDER_TEST" md5sum "MD5" "$TEST_FILE"

  [ "$status" -eq 0 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --info"* ]]
  [[ "$output" == *"--extra-button="* ]]

  # Verify xclip received the hash we expect
  run cat "$CLIPBOARD_FILE"
  [[ "$output" == "deadbeef1234567890abcdef12345678"* ]]
}

@test "Multiple files show no Copy Hash button" {
  FILE2="${BATS_TMPDIR}/sample_file2.txt"
  echo 'Another file' > "$FILE2"

  run bash "$SCRIPT_UNDER_TEST" md5sum "MD5" "$TEST_FILE" "$FILE2"

  [ "$status" -eq 0 ]

  run cat "$ZENITY_LOG"
  # Should be a normal info dialog but without the extra-button argument
  [[ "$output" == *"ZENITY_CALL: --info"* ]]
  [[ "$output" != *"--extra-button="* ]]
}

@test "Missing file is reported as missing" {
  MISSING="${BATS_TMPDIR}/no_such_file"

  run bash "$SCRIPT_UNDER_TEST" md5sum "MD5" "$MISSING"

  [ "$status" -eq 1 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --info"* ]]
  [[ "$output" == *"missing file"* ]]
}
