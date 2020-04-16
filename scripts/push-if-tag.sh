#!/usr/bin/env bash

# If HEAD is on a tag, we want to push the images
if git describe --exact-match --tags HEAD >/dev/null; then
  echo "Current HEAD is a tag.  Pushing images to Quay and Docker Hub"
else
  echo "Current HEAD is not a tag.  Will not push images"
fi
