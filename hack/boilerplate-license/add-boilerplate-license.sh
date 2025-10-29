#!/bin/bash

# (c) 2025 by CoreWeave, Inc.
#
# This file is part of Slurm Containers.
#
# Slurm Containers is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 2 of the License,
# or (at your option) any later version.
#
# Slurm Containers is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Slurm Containers; if not, write to the
# Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301 USA

set -e

EXT=$1
UPDATE_DIR=$2
EXEC_DIR=$(dirname $0)

ARGS=("$@")
INPUT_FILES=("${ARGS[@]:2}")

STAGED_FILES_OPTION="--staged-files"
UPDATED_FILES=()

USAGE=$(cat <<EOF
Add boilerplate-license.<ext>.txt to all .<ext> files missing it in a specified directory
or which are being committed.

*NOTE: valid extensions are "sh", "yaml", "yml", "md" or "all"
<DIR>: is relative to where the script is called

Usage: (from repository root)
         ./hack/boilerplate-license/add-boilerplate-license.sh <EXT> <DIR>
       (with pre-commit)
         When a commit is made, the license-header-check pre-commit hook
         will execute this script with the first two arguments being 'all'
         and '--staged-files' (the first specifies <EXT> and the second is used
         to modify the script's behavior for pre-commit) and the rest being
         the staged files.

Example: (from repository root)
         ./hack/boilerplate-license/add-boilerplate-license.sh yaml .github/workflows
EOF
)

init() {

  if [[ -z "${EXT}" || -z "${UPDATE_DIR}" ]]; then
    echo "${USAGE}"
    exit 1
  fi

  if ! [[ "${EXT}" =~ ^(sh|go|yaml|yml|md|all)$ ]]; then
    echo -e "*** extention must be sh, yaml, yml, go, md or all\n"
    echo "${USAGE}"
    exit 1
  fi
}

get_files_to_update() {

  if [ "${ARGS[1]}" = ${STAGED_FILES_OPTION} ]; then
    UPDATE_TARGET=(${INPUT_FILES[@]})
  else
    UPDATE_TARGET=("${UPDATE_DIR}")
  fi

  if FILES_TO_UPDATE=$(grep -rLE "\(c\) [0-9]+ by CoreWeave, Inc." "${UPDATE_TARGET[@]}" | grep -E "\."${EXT}"\$"); then
    echo -e "files to update: \n${FILES_TO_UPDATE}"
    UPDATED_FILES+=(${FILES_TO_UPDATE})
  else
    echo "no ${EXT} files to update"
  fi
}

# Get creation time from git history, or default to current year
get_git_create_date() {
  git_commit=$(git log --diff-filter=A --follow --format=%H -1 -- "${1}")

  git_date=$(git log --diff-filter=A --follow --format=%ad --date=format:%Y -1 -- "${1}")
  # Fallback to current year if not found
  if [[ -z "${git_date}" ]]; then
    git_date=$(date +%Y)
  fi
  echo $git_date
}

# Update a file with simple operations, can be used for most files
simple_update_file () {
    current_file=$1

    tmpfile=$(mktemp)
    file_date=$(get_git_create_date "${current_file}")

    sed -E "s/(\(c\)) [0-9]+/\1 $file_date/g" -- "${EXEC_DIR}/boilerplate-license.${EXT}.txt" > ${tmpfile}
    echo >> ${tmpfile}
    cat ${1} >> ${tmpfile}
    mv ${tmpfile} ${1}
}

# Update a markdown file
update_md_file () {
  current_file=$1

  # Get git file creation date and replace it in the header contents
  file_date=$(get_git_create_date "${current_file}")
  updated_header=$(sed -E "s/(\(c\)) [0-9]+/\1 $file_date/g" -- "${EXEC_DIR}/boilerplate-license.${EXT}.txt")

  # If title is already in there, insert copyright line after it
  if grep -q "^title: " "${current_file}"; then
    title_line=$(grep "^title: " "${current_file}")
    tmpfile=$(mktemp)
    {
      echo "${title_line}"
      echo
      echo "${updated_header}"
      echo
      grep -v "^title: " "${current_file}"
    } > ${tmpfile}
    mv ${tmpfile} ${current_file}
  else
    # No title line, skipping it
    echo -e "\nNo title line found in ${current_file}, skipping"
  fi
}

sh_add_license() {

  get_files_to_update

  for current_file in ${FILES_TO_UPDATE}
  do
    # Check for shebang
    first_line=$(head -n 1 "${current_file}")
    if [[ "${first_line}" =~ "#!" ]]; then
      # add shebang to top of tmp file to retain it
      tmpfile=$(mktemp)
      echo -e "${first_line}\n" > ${tmpfile}
      # remove existing shebang in file so it and the license block can be added in
      sed -i -e "1d" ${current_file}
    fi

    file_date=$(get_git_create_date "${current_file}")
    sed -E "s/(\(c\)) [0-9]+/\1 $file_date/g" -- ${EXEC_DIR}/boilerplate-license."${EXT}".txt >> ${tmpfile}
    echo >> ${tmpfile}
    cat ${current_file} >> ${tmpfile}
    mv ${tmpfile} ${current_file}
  done
}

yaml_add_license() {

  get_files_to_update

  EXT="yaml"
  for current_file in ${FILES_TO_UPDATE}; do
    simple_update_file ${current_file}
  done
}

md_add_license() {

  get_files_to_update

  for current_file in ${FILES_TO_UPDATE}; do
    update_md_file ${current_file}
  done
}

main() {

  init

  case $EXT in
  "sh")
    echo -e "\nAdding boilerplate license to \"sh\" files."
    sh_add_license
    ;;
  "yaml"|"yml")
    echo -e "\nAdding boilerplate license to \"yaml\" files."
    EXT="yaml"
    yaml_add_license

    echo -e "\nAdding boilerplate license to \"yml\" files."
    EXT="yml"
    yaml_add_license
    ;;
  "md")
    echo -e "\nAdding boilerplate license to \"md\" files."
    md_add_license
    ;;
  "all")
    echo -e "\nAdding boilerplate license to \"yaml\" files."
    EXT="yaml"
    yaml_add_license

    echo -e "\nAdding boilerplate license to \"yml\" files."
    EXT="yml"
    yaml_add_license

    echo -e "\nAdding boilerplate license to \"sh\" files."
    EXT="sh"
    sh_add_license

    echo -e "\nAdding boilerplate license to \"md\" files."
    EXT="md"
    md_add_license

    EXT="all"
    ;;
  *)
    echo "*** error - no files updated"
    echo "${USAGE}"
    exit 1
    ;;
  esac

  echo -e "\nSuccessfully processed ${EXT} files"

  if [ "${ARGS[1]}" = ${STAGED_FILES_OPTION} ]; then
    echo -e  "\nAdded license headers to the files below. These changes are unstaged. After reviewing them, add them with \"git add <files>\".\n"
    printf '%s\n' "${UPDATED_FILES[@]}"
  fi
}

main
