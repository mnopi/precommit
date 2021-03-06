#!/usr/bin/env bash
# bashsupport disable=BP5001
# Transcrypt pre-commit hook: fail if secret file in staging lacks the magic prefix "Salted" in B64
tmp=$(mktemp)
IFS=$'\n'
slow_mode_if_failed() {
  for secret_file in $(git -c core.quotePath=false ls-files | git -c core.quotePath=false check-attr --stdin filter | \
    awk 'BEGIN { FS = ":" }; /crypt$/{ print $1 }'); do
    # Skip symlinks, they contain the linked target file path not plaintext
    if [[ -L $secret_file ]]; then
      continue
    fi

    # Get prefix of raw file in Git's index using the :FILENAME revision syntax
    firstbytes=$(git show :"${secret_file}" | head -c8)
    # An empty file does not need to be, and is not, encrypted
    if [[ $firstbytes == "" ]]; then
      : # Do nothing
    # The first bytes of an encrypted file must be "Salted" in Base64
    elif [[ $firstbytes != "U2FsdGVk" ]]; then
      printf 'Transcrypt managed file is not encrypted in the Git index: %s\n' "$secret_file" >&2
      printf '\n' >&2
      printf 'You probably staged this file using a tool that does not apply' >&2
      printf ' .gitattribute filters as required by Transcrypt.\n' >&2
      printf '\n' >&2
      printf 'Fix this by re-staging the file with a compatible tool or with'
      printf ' Git on the command line:\n' >&2
      printf '\n' >&2
      printf '    git reset -- %s\n' "$secret_file" >&2
      printf '    git add %s\n' "$secret_file" >&2
      printf '\n' >&2
      exit 1
    fi
  done
}

# validate file to see if it failed or not, We don't care about the filename currently for speed, we only care about pass/fail, slow_mode_if_failed() is for what failed.
validate_file() {
  secret_file=${1}
  # Skip symlinks, they contain the linked target file path not plaintext
  if [[ -L $secret_file ]]; then
    return
  fi
  # Get prefix of raw file in Git's index using the :FILENAME revision syntax
  # The first bytes of an encrypted file are always "Salted" in Base64
  firstbytes=$(git show :"${secret_file}" | head -c8)
  if [[ $firstbytes != "U2FsdGVk" ]]; then
    echo "true" >>"${tmp}"
  fi
}

# if bash version is 4.4 or greater than fork to number of threads otherwise run normally
if [[ "${BASH_VERSINFO[0]}" -ge 4 ]] && [[ "${BASH_VERSINFO[1]}" -ge 4 ]]; then
  num_procs=$(nproc)
  num_jobs="\j"
  for secret_file in $(git -c core.quotePath=false ls-files | git -c core.quotePath=false check-attr --stdin filter | \
    awk 'BEGIN { FS = ":" }; /crypt$/{ print $1 }'); do
    while ((${num_jobs@P} >= num_procs)); do
      wait -n
    done
    validate_file "${secret_file}" &
  done
  wait
  if [[ -s ${tmp} ]]; then
    slow_mode_if_failed
    rm -f "${tmp}"
    exit 1
  fi
else
  slow_mode_if_failed
fi

rm -f "${tmp}"
unset IFS
