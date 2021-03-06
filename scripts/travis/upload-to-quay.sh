#!/bin/bash

set -e

BRANCH=${BRANCH:?'missing BRANCH env var'}
IMAGE="${REPO:?'missing REPO env var'}:latest"

unset major minor patch
if [[ "$BRANCH" == "master" ]]; then
  TAG="latest"
elif [[ $BRANCH =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  major="${BASH_REMATCH[1]}"
  minor="${BASH_REMATCH[2]}"
  patch="${BASH_REMATCH[3]}"
  TAG=${major}.${minor}.${patch}
  echo "BRANCH is a release tag: major=$major, minor=$minor, patch=$patch"
else
  # TODO why do we do /// ?
  TAG="${BRANCH///}"
fi
echo "TRAVIS_BRANCH=$TRAVIS_BRANCH, REPO=$REPO, BRANCH=$BRANCH, TAG=$TAG, IMAGE=$IMAGE"

# add major, major.minor and major.minor.patch tags
if [[ -n $major ]]; then
  docker tag $IMAGE $REPO:${major}
  if [[ -n $minor ]]; then
    docker tag $IMAGE $REPO:${major}.${minor}
    if [[ -n $patch ]]; then
        docker tag $IMAGE $REPO:${major}.${minor}.${patch}
    fi
  fi
fi

if [[ -f $HOME/.docker/config.json ]]; then
  rm -f $HOME/.docker/config.json
else
  echo "$HOME/.docker/config.json doesn't exist"
fi

# Do not enable echo before the `docker login` command to avoid revealing the password.
set -x
docker login quay.io -u $QUAY_USER -p $QUAY_PASS 
echo "Quay login successful"

function push_to_quay {
  docker pull $1
  IMAGE_ID=$(docker images $1 -q)
  echo "the image id is:" $IMAGE_ID
  docker tag $IMAGE_ID "quay.io/$2:$3"
  docker push "quay.io/$2:$3"
  #delete the pulled image
  docker rmi -f $IMAGE_ID
}

if [[ "${REPO}" == "jaegertracing/jaeger-opentelemetry-collector" || "${REPO}" == "jaegertracing/jaeger-opentelemetry-agent" || "${REPO}" == "jaegertracing/jaeger-opentelemetry-ingester" || "${REPO}" == "jaegertracing/opentelemetry-all-in-one" ]]; then
  # TODO remove once Jaeger OTEL collector is stable
echo "pushing image to quay.io:" "$REPO:latest"  
push_to_quay "$REPO:latest" $REPO "latest" 

elif [[ "${REPO}" == "$REPO-snapshot" ]]; then
echo "pushing snapshot image to quay.io:" "$REPO-snapshot:$TRAVIS_COMMIT"
push_to_quay "$REPO-snapshot:$TRAVIS_COMMIT" "$REPO-snapshot" $TRAVIS_COMMIT 

else
# push all tags, therefore push to repo
echo "pushing image to quay.io:" $REPO:$TAG
push_to_quay $REPO:$TAG $REPO $TAG
fi


