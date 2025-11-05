#!/bin/bash
# SPDX-FileCopyrightText: 2025 CoreWeave, Inc.
# SPDX-License-Identifier: GPL-2.0-or-later
# SPDX-PackageName: slurm-containers
set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <release-version>" 1>&2
  exit 1
fi

VERSION="$1"

# Check required env vars
for var in AUTH_FILE CI_REGISTRY; do
  if [[ -z "${!var}" ]]; then
    echo "ERROR: $var is not set" 1>&2
    exit 1
  fi
done

CI_COMMIT_SHORT_SHA=${CI_COMMIT_SHORT_SHA:-$(git rev-parse --short=8 HEAD)}

# Extract username and password from auth file
REGISTRY_USERNAME=$(jq -r ".auths[\"$CI_REGISTRY\"].username" "$AUTH_FILE")
REGISTRY_PASSWORD=$(jq -r ".auths[\"$CI_REGISTRY\"].password" "$AUTH_FILE")

# Select Docker images to tag.
success=true
docker_registry="docker://$CI_REGISTRY"
previous_version=$(git describe origin/main^ --tags --abbrev=0)
ci_file=".github/workflows/build-images.yaml"

# This extracts the images from the build-images.yaml file and handles cases where the image-tag-suffix is present
images=($(yq '.jobs[] | .steps[] | select(.uses == "./.github/actions/images/build-with-extras" and .with.image-name != null) | .with.image-name + ":'$CI_COMMIT_SHORT_SHA'-" + .with.image-tag-suffix' $ci_file | tr -d " "))
extrasImages=($(yq '.jobs[] | .steps[] | select(.uses == "./.github/actions/images/build-with-extras" and .with.image-name != null) | .with.image-name + "-extras:'$CI_COMMIT_SHORT_SHA'-" + .with.image-tag-suffix' $ci_file | tr -d " "))
osVersions=($(yq '(.env.build-settings | from_yaml).[].os' $ci_file))
cudaVersions=($(yq '(.env.build-settings | from_yaml).[].cuda.[].name' $ci_file))

# Process replacements in images
for image in "${extrasImages[@]}"; do
  for os in "${osVersions[@]}"; do
    if [[ $image != *"cuda_name"* ]]; then
      processed_image=$(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/")
      images+=("$processed_image")
      continue
    fi
    for cuda in "${cudaVersions[@]}"; do
      processed_image=$(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/" | sed "s/\${{matrix.build-settings.cuda_name}}/$cuda/")
      images+=("$processed_image")
    done
  done
done

# Also process the base images that might have template variables
temp_images=()
for image in "${images[@]}"; do
  for os in "${osVersions[@]}"; do
    if [[ $image != *"cuda_name"* ]]; then
      processed_image=$(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/")
      temp_images+=("$processed_image")
      continue
    fi
    for cuda in "${cudaVersions[@]}"; do
      processed_image=$(echo $image | sed "s/\${{matrix.build-settings.os}}/$os/" | sed "s/\${{matrix.build-settings.cuda_name}}/$cuda/")
      temp_images+=("$processed_image")
    done
  done
done
images=("${temp_images[@]}")

tag_cmds=()
for hash_image in "${images[@]}"; do
  version_image=$(echo $hash_image | sed "s/$CI_COMMIT_SHORT_SHA/$VERSION/")
  previous_image=$(echo $hash_image | sed "s/$CI_COMMIT_SHORT_SHA/$previous_version/")

  # Add the repository namespace to the image path
  full_hash_image="slurm-containers-public/$hash_image"
  full_version_image="slurm-containers-public/$version_image"
  full_previous_image="slurm-containers-public/$previous_image"

  if skopeo inspect --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD" "$docker_registry/$full_hash_image" > /dev/null 2>&1; then
    echo "Tagging $hash_image as $VERSION"
    cmd="skopeo copy --src-username '$REGISTRY_USERNAME' --src-password '$REGISTRY_PASSWORD' --dest-username '$REGISTRY_USERNAME' --dest-password '$REGISTRY_PASSWORD' --multi-arch all '$docker_registry/$full_hash_image' '$docker_registry/$full_version_image'"
    tag_cmds+=( "${cmd}" )
  else
    if skopeo inspect --username "$REGISTRY_USERNAME" --password "$REGISTRY_PASSWORD" "$docker_registry/$full_previous_image" > /dev/null 2>&1; then
      echo "Tagging $previous_image as $VERSION"
      cmd="skopeo copy --src-username '$REGISTRY_USERNAME' --src-password '$REGISTRY_PASSWORD' --dest-username '$REGISTRY_USERNAME' --dest-password '$REGISTRY_PASSWORD' --multi-arch all '$docker_registry/$full_previous_image' '$docker_registry/$full_version_image'"
      tag_cmds+=( "${cmd}" )
    else
      echo "ERROR: A new image for $hash_image was not built and an image for $previous_version was not found."
      echo "Please include a commit to modify $hash_image and try again."
      success=false
    fi
  fi
done

if [ $success = false ]; then
  exit 1
fi

# Run the image tagging commands.
for (( i = 0; i < ${#tag_cmds[@]}; i++ )); do
  eval "${tag_cmds[$i]}"
done
