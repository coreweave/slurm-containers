#!/bin/bash

# SPDX-FileCopyrightText: © 2025 CoreWeave, Inc. <sunk@coreweave.com>
#
# CoreWeave SUNK Software
#
# Copyright 2025 CoreWeave, Inc.
#
# See accompanying NOTICE.  This product includes software that is subject to the LICENSE.

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release-version>" 1>&2
  exit 1
fi

VERSION="v$1"

# Check required env vars
for var in AUTH_FILE CI_REGISTRY; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var is not set" 1>&2
    exit 1
  fi
done

CI_COMMIT_SHORT_SHA=${CI_COMMIT_SHORT_SHA:-$(git rev-parse --short=8 HEAD)}

# Setup Skopeo
skopeo login --compat-auth-file $AUTH_FILE $CI_REGISTRY

# Select Docker images to tag.
success=true
docker_registry="docker://$CI_REGISTRY"
previous_version=$(git describe origin/main^ --tags --abbrev=0)
ci_file=".github/workflows/build-images.yaml"

# This extracts the images from the build-images.yaml file and handles cases where the image-tag-suffix is present
images=($(yq '.jobs[] | .steps[] | select(.with.image-target != null and .uses != "*extras" and ( .with | has("image-tag-suffix") | not)) | .with.image-target + ":'$CI_COMMIT_SHORT_SHA'"' $ci_file))
extrasImages=($(yq '.jobs[] | .steps[] | select(.with.image-target != null and .uses == "*extras") | .with.image-target + ":'$CI_COMMIT_SHORT_SHA'-" + .with.image-tag-suffix' $ci_file | tr -d " " ))
extrasImages+=($(yq '.jobs[] | .steps[] | select(.with.image-target != null and .uses == "*extras" and ( .with | has("image-tag-suffix"))) | .with.image-target + "-extras:'$CI_COMMIT_SHORT_SHA'-" + .with.image-tag-suffix' $ci_file | tr -d " "))
extrasImages+=($(yq '.jobs[] | .steps[] | select(.with.image-target != null and .uses != "*extras" and ( .with | has("image-tag-suffix"))) | .with.image-target + ":'$CI_COMMIT_SHORT_SHA'-" + .with.image-tag-suffix' $ci_file | tr -d " "))
osVersions=($(yq '(.env.build-settings | from_yaml).[].os' $ci_file))
cudaVersions=($(yq '(.env.build-settings | from_yaml).[].cuda.[].name' $ci_file))

# Process replacements in images
for image in "${extrasImages[@]}"; do
  for os in "${osVersions[@]}"; do
    if [[ $image != *"cuda_name"* ]]; then
      images+=($(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/"))
      continue
    fi
    for cuda in "${cudaVersions[@]}"; do
      images+=($(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/" | sed "s/\${{matrix.build-settings.cuda_name}}/$cuda/"))
    done
  done
done

tag_cmds=()
for hash_image in "${images[@]}"; do
  version_image=$(echo $hash_image | sed "s/$CI_COMMIT_SHORT_SHA/$VERSION/")
  previous_image=$(echo $hash_image | sed "s/$CI_COMMIT_SHORT_SHA/$previous_version/")
  if skopeo inspect "$docker_registry/$hash_image" > /dev/null 2>&1; then
    echo "Tagging $hash_image as $VERSION"
    cmd="skopeo copy --multi-arch all '$docker_registry/$hash_image' '$docker_registry/$version_image'"
    tag_cmds+=( "${cmd}" )
  elif skopeo inspect "$docker_registry/$previous_image" > /dev/null 2>&1; then
    echo "Tagging $previous_image as $VERSION"
    cmd="skopeo copy --multi-arch all '$docker_registry/$previous_image' '$docker_registry/$version_image'"
    tag_cmds+=( "${cmd}" )
  else
    echo "ERROR: A new image for $hash_image was not built and an image for $previous_version was not found."
    echo "Please include a commit to modify $hash_image and try again."
    success=false
  fi
done

if [ $success = false ]; then
  exit 1
fi

# Run the image tagging commands.
for (( i = 0; i < ${#tag_cmds[@]}; i++ )); do
  eval "${tag_cmds[$i]}"
done
