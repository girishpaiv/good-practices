#!/bin/bash

# A script used to validate a commit message against the below conventions
#
# Title must be on a single line
# Title format: <TYPE>(TICKET):<space>Title
#   An example title: "FEAT(TKT-1234): Add my new cool feature"
# The TYPE in the title represents the reason for the change. Valid types are
#  - FEAT   - To implement a Feature
#  - BUG    - To fix a bug identified in the code
#  - IMPR   - To Improve the code be it refactor, cleanup or any sort of improvement
#  - DEPLOY - Deployment related trivial and recurrent changes like version updates etc
# Body is optional but is recommended if it can add additional context
# Title and body (if any) must be separated by a blank line
# Every line in the message both title and body must be wrapped at max 72 characters

# Range of commits to verify, this is provided by the caller
commits_range="$1..$2"

# Get commit SHAs within the range
commit_shas=$(git log --no-merges --format="%H" $commits_range)

declare -a failed_commits
declare -a failed_commits_errors
all_pass=1  # True

# Loop through commits and verify!
# TODO: Separate out the validation part as a function and add UTs with valid and invalid commit messages
for sha in $commit_shas; do
  commit_msg=$(git log --format="%B" -n 1 $sha)  # Fetch the commit message from SHA
  title=$(echo "$commit_msg" | awk 'NR==1{print; exit}')
  printf "\n\n== Checking commit ## $sha\n$commit_msg\n"

  # Check Title format
  # TODO: IMPROVEMENT and FEATURE are kept for backward compatibility. Remove once all PRs are having the new types
  if ! echo "$title" | grep -qE '^(FEAT|IMPR|BUG|DEPLOY)\([A-Z][A-Z0-9_]+-[0-9]{1,5}\): .'; then
    failed_commits+=("$sha: $title")
    failed_commits_errors+=("Incorrect title format")
    all_pass=0
    continue
  fi

  # Check Title length
  if ! echo "$title" | grep -qE '^.{1,71}$'; then
    failed_commits+=("$sha: $title")
    failed_commits_errors+=("Incorrect length of title (Max 72 characters)")
    all_pass=0
    continue
  fi

  # If 2nd line exists, confirm it is blank
  if ! echo "$commit_msg" | awk 'NR==2 { exit ($0 != "" ? 1 : 0) }'; then
    failed_commits+=("$sha: $title")
    failed_commits_errors+=("Second line is not blank")
    all_pass=0
    continue
  fi

  # If a body exist, ensure every line is wrapped at 72 characters
  body=$(echo "$commit_msg" | sed -n '3,$p')
  if [ ! -z "$body" ]; then
    while IFS= read -r line; do
      if ! [ ${#line} -lt 72 ]; then
        failed_commits+=("$sha: $title")
        failed_commits_errors+=("Body is not wrapped at 72 characters")
        all_pass=0
      fi
    done <<< "$body"
  fi
done

# Print Final result
if [ "$all_pass" -eq 1 ]; then
  printf "\n==============\n Final Result: PASS !!!\n==============\n"
else
  printf "\n==============\n Final Result: FAIL !!!\n==============\n"
  printf "\nCommits with errors:\n"
  length=${#failed_commits[@]}
  for ((i=0; i<$length; i++)); do
    echo "${failed_commits[$i]}:         ${failed_commits_errors[$i]}"
  done
  printf "Please follow conventions on commit messages. Refer the above section for failures"
  exit 1
fi
