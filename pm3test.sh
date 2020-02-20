#!/usr/bin/env bash

PM3PATH=$(dirname "$0")
cd "$PM3PATH" || exit 1

if [ "$1" == "long" ]; then
    SLOWTESTS=true
else
    SLOWTESTS=false
fi

C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

# title, file name or file wildcard to check
function CheckFileExist() {

  if [ -f "$2" ]; then
    echo -e "$1 ${C_GREEN}[OK]${C_NC}"
    return 0
  fi

  if ls $2 1> /dev/null 2>&1; then
    echo -e "$1 ${C_GREEN}[OK]${C_NC}"
    return 0
  fi

  echo -e "$1 ${C_RED}[Fail]${C_NC}"
  return 1
}

# title, command line, check result, repeat several times if failed, ignore if fail
function CheckExecute() {

  if [ $4 ]; then
    local RETRY="1 2 3 e"
  else
    local RETRY="e"
  fi

  for I in $RETRY
  do
    RES=$(eval "$2")
    if echo "$RES" | grep -q "$3"; then
      echo -e "$1 ${C_GREEN}[OK]${C_NC}"
      return 0
    fi
    if [ ! $I == "e" ]; then echo "retry $I"; fi
  done


  if [ $5 ]; then
    echo -e "$1 ${C_YELLOW}[Ignored]${C_NC}"
    return 0
  fi

  echo -e "$1 ${C_RED}[Fail]${C_NC}"
  echo -e "Execution trace:\n$RES"
  return 1
}

# Checks whether a given file's interpreter can be found by attempting to exec
# the file and checking whether the return code doesn't indicate that:
# - the interpreter couldn't be found; or
# - `env` couldn't find the command
function CheckInvoke() {
  RES=$(eval "$2" 2>&1)
  RET=$?
  # bash returns 126 if interpreter not found
  # env (in GNU coreutils) returns 127 if command not found
  if [ $RET -ne 126 ] && [ $RET -ne 127 ]; then
    echo -e "$1 ${C_GREEN}[OK]${C_NC}"
    return 0
  fi

  echo -e "$1 ${C_RED}[Fail]${C_NC}"
  echo -e "Execution trace:\n$RES"
  return 1
}

printf "\n${C_BLUE}RRG/Iceman Proxmark3 test tool ${C_NC}\n\n"

printf "work directory: "
pwd

if [ "$TRAVIS_COMMIT" ]; then
  if [ "$TRAVIS_PULL_REQUEST" == "false" ]; then
    echo "Travis branch: $TRAVIS_BRANCH slug: $TRAVIS_REPO_SLUG commit: $TRAVIS_COMMIT"
  else
    echo "Travis pull request: $TRAVIS_PULL_REQUEST branch: $TRAVIS_BRANCH slug: $TRAVIS_PULL_REQUEST_SLUG commit: $TRAVIS_COMMIT"
  fi
fi

printf "git branch: "
git describe --all
printf "git sha: "
git rev-parse HEAD
echo ""

while true; do
  printf "\n${C_BLUE}Testing files:${C_NC}\n"
  if ! CheckFileExist "proxmark3 exists" "./client/proxmark3"; then break; fi
  if ! CheckFileExist "arm image exists" "./armsrc/obj/fullimage.elf"; then break; fi
  if ! CheckFileExist "bootrom exists" "./bootrom/obj/bootrom.elf"; then break; fi
  if ! CheckFileExist "hardnested tables exists" "./client/resources/hardnested_tables/*.z"; then break; fi

  printf "\n${C_BLUE}Testing interpreters for executable scripts:${C_NC}\n"
  if ! CheckInvoke "pm3 interpreter" "./pm3 -h"; then break; fi
  if ! CheckInvoke "pm3-flash interpreter" "./pm3-flash -h"; then break; fi
  if ! CheckInvoke "pm3-flash-all interpreter" "./pm3-flash-all -h"; then break; fi
  if ! CheckInvoke "pm3-flash-bootrom interpreter" "./pm3-flash-bootrom -h"; then break; fi
  if ! CheckInvoke "pm3-flash-fullimage interpreter" "./pm3-flash-fullimage -h"; then break; fi
  if ! CheckInvoke "tools/analyzesize.py interpreter" "./tools/analyzesize.py -h"; then break; fi
  if ! CheckInvoke "tools/findbits.py interpreter" "./tools/findbits.py"; then break; fi
  if ! CheckInvoke "tools/mkversion.sh interpreter" "./tools/mkversion.sh"; then break; fi
  if ! CheckInvoke "tools/pm3_amii_bin2eml.pl interpeter" "tools/pm3_amii_bin2eml.pl"; then break; fi
  if ! CheckInvoke "tools/pm3_cs8.pl interpreter" "./tools/pm3_cs8.pl"; then break; fi
  if ! CheckInvoke "tools/pm3_eml2lower.sh interpreter" "./tools/pm3_eml2lower.sh"; then break; fi
  if ! CheckInvoke "tools/pm3_eml2mfd.py interpreter" "./tools/pm3_eml2mfd.py"; then break; fi
  if ! CheckInvoke "tools/pm3_eml2upper.sh interpreter" "./tools/pm3_eml2upper.sh"; then break; fi
  if ! CheckInvoke "tools/pm3_eml_mfd_test.py interpreter" "./tools/pm3_eml_mfd_test.py"; then break; fi
  if ! CheckInvoke "tools/pm3_mf7b_wipe.py interpreter" "./tools/pm3_mf7b_wipe.py"; then break; fi
  if ! CheckInvoke "tools/pm3_mfd2eml.py interpreter" "./tools/pm3_mfd2eml.py"; then break; fi
  if ! CheckInvoke "tools/pm3_mfdread.py interpreter" "./tools/pm3_mfdread.py"; then break; fi
  if ! CheckInvoke "tools/pm3_pm32wav.py interpreter" "./tools/pm3_pm32wav.py"; then break; fi
  if ! CheckInvoke "tools/xorcheck.py interpeter" "./tools/xorcheck.py"; then break; fi

  printf "\n${C_BLUE}Testing basic help:${C_NC}\n"
  if ! CheckExecute "proxmark help" "./client/proxmark3 -h" "wait"; then break; fi
  if ! CheckExecute "proxmark help text ISO7816" "./client/proxmark3 -t 2>&1" "ISO7816"; then break; fi
  if ! CheckExecute "proxmark help text hardnested" "./client/proxmark3 -t 2>&1" "hardnested"; then break; fi

  printf "\n${C_BLUE}Testing data manipulation:${C_NC}\n"
  if ! CheckExecute "reveng test" "./client/proxmark3 -c 'reveng -w 8 -s 01020304e3 010204039d'" "CRC-8/SMBUS"; then break; fi

  printf "\n${C_BLUE}Testing LF:${C_NC}\n"
  if ! CheckExecute "lf em4x05 test" "./client/proxmark3 -c 'data load traces/em4x05.pm3;lf search'" "FDX-B ID found"; then break; fi

  printf "\n${C_BLUE}Testing HF:${C_NC}\n"
  if ! CheckExecute "hf mf offline text" "./client/proxmark3 -c 'hf mf'" "at_enc"; then break; fi
  if $SLOWTESTS; then
    if ! CheckExecute "hf mf hardnested test" "./client/proxmark3 -c 'hf mf hardnested t 1 000000000000'" "found:" "repeat" "ignore"; then break; fi
    if ! CheckExecute "hf iclass test" "./client/proxmark3 -c 'hf iclass loclass t l'" "verified ok"; then break; fi
    if ! CheckExecute "emv test" "./client/proxmark3 -c 'emv test -l'" "Test(s) \[ OK"; then break; fi
  else
    if ! CheckExecute "hf iclass test" "./client/proxmark3 -c 'hf iclass loclass t'" "OK!"; then break; fi
    if ! CheckExecute "emv test" "./client/proxmark3 -c 'emv test'" "Test(s) \[ OK"; then break; fi
  fi

  printf "\n${C_BLUE}Testing tools:${C_NC}\n"
  # Need a decent example for mfkey32...
  if ! CheckExecute "mfkey32v2 test" "tools/mfkey/mfkey32v2 12345678 1AD8DF2B 1D316024 620EF048 30D6CB07 C52077E2 837AC61A" "Found Key: \[a0a1a2a3a4a5\]"; then break; fi
  if ! CheckExecute "mfkey64 test" "tools/mfkey/mfkey64 9c599b32 82a4166c a1e458ce 6eea41e0 5cadf439" "Found Key: \[ffffffffffff\]"; then break; fi
  if ! CheckExecute "mfkey64 long trace test" "tools/mfkey/./mfkey64 14579f69 ce844261 f8049ccb 0525c84f 9431cc40 7093df99 9972428ce2e8523f456b99c831e769dced09 8ca6827b ab797fd369e8b93a86776b40dae3ef686efd c3c381ba 49e2c9def4868d1777670e584c27230286f4 fbdcd7c1 4abd964b07d3563aa066ed0a2eac7f6312bf 9f9149ea" "Found Key: \[091e639cb715\]"; then break; fi
  if ! CheckExecute "nonce2key test" "tools/nonce2key/nonce2key e9cadd9c a8bf4a12 a020a8285858b090 050f010607060e07 5693be6c00000000" "key recovered: fc00018778f7"; then break; fi
  printf "\n${C_GREEN}Tests [OK]${C_NC}\n\n"
  exit 0
done

printf "\n${C_RED}Tests [FAIL]${C_NC}\n\n"
exit 1
