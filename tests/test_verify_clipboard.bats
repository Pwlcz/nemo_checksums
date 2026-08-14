#!/usr/bin/env bats

SCRIPT_UNDER_TEST="${BATS_TEST_DIRNAME}/../actions/checksum_menu@pwlcz/verify_clipboard.sh"

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

  cat << 'EOF' > "${MOCK_BIN}/xclip"
#!/bin/bash
if [[ -f "$CLIPBOARD_FILE" ]]; then
  cat "$CLIPBOARD_FILE"
fi
EOF
  chmod +x "${MOCK_BIN}/xclip"

  cat << 'EOF' > "${MOCK_BIN}/zenity"
#!/bin/bash
# Log the arguments called
echo "ZENITY_CALL: $@" >> "$ZENITY_LOG"

# Read stdin to prevent piped processes (e.g. progress bar) from hanging
if [ ! -t 0 ]; then
  cat > /dev/null
fi
exit 0
EOF
  chmod +x "${MOCK_BIN}/zenity"

  TEST_FILE="${BATS_TMPDIR}/sample_file.txt"
  echo 'Hello, World!' > "$TEST_FILE"
  # Pre-calculate known hashes of 'Hello, World!'
  # SHA-256: c98c24b677eff44860afea6f493bbaec5bb1c4cbb209c6fc2bbb47f66ff2ad31
  # BLAKE2:  94d8520fe182add62bec85b531a17a779fcd39f23248cfabd18347b86ce9f8b73a0c151dd7ce171843dd8a14e5329dde6b73149d26d6638e94ef4c634f3f1a7b
}

teardown() {
  rm -rf "${MOCK_BIN}" "$TEST_FILE" "$CLIPBOARD_FILE" "$ZENITY_LOG"
}

# ------------------------------------------------------------------------------
# TESTS
# ------------------------------------------------------------------------------

@test "Warning when clipboard is empty" {
  echo "" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 1 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --warning"* ]]
  [[ "$output" == *"The clipboard is empty or does not contain text."* ]]
  [[ "$output" == *"No Clipboard Content"* ]]
}

@test "Fail when clipboard contains no valid hash" {
  echo "Just some random text with no hash" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 1 ]
  
  # Verify that zenity warning was triggered
  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --warning"* ]]
  [[ "$output" == *"No Checksum Found"* ]]
  [[ "$output" == *"Could not find a valid hash string in the clipboard."* ]]
}

@test "Warning/Fail when clipboard hash length is unsupported" {
  # 10 character hex string (invalid length)
  echo "a1b2c3d4e5" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 1 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --error"* || "$output" == *"ZENITY_CALL: --warning"* ]]
  [[ "$output" == *"Unsupported Hash Length"* || "$output" == *"Could not find a valid hash string in the clipboard."* ]]
}

@test "Successfully match a valid SHA-256 hash from clipboard" {
  # Known SHA-256 for 'Hello, World!\n'
  echo "c98c24b677eff44860afea6f493bbaec5bb1c4cbb209c6fc2bbb47f66ff2ad31" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 0 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --info"* ]]
  [[ "$output" == *"Checksum Match"* ]]
}

@test "Detect a SHA-256 mismatch when hash is wrong" {
  # Valid 64-char length, but wrong value
  echo "0000000000000000000000000000000000000000000000000000000000000000" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 0 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"ZENITY_CALL: --error"* ]]
  [[ "$output" == *"Checksum Mismatch"* ]]
}

@test "Successfully match BLAKE2 hash" {
  # Known BLAKE2 for 'Hello, World!\n'
  echo "94d8520fe182add62bec85b531a17a779fcd39f23248cfabd18347b86ce9f8b73a0c151dd7ce171843dd8a14e5329dde6b73149d26d6638e94ef4c634f3f1a7b" > "$CLIPBOARD_FILE"

  run bash "$SCRIPT_UNDER_TEST" "$TEST_FILE"

  [ "$status" -eq 0 ]

  run cat "$ZENITY_LOG"
  [[ "$output" == *"Checksum Match"* ]]
}