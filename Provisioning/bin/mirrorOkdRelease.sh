#!/bin/bash

OKD_REGISTRY=${OKD_STABLE_REGISTRY}
NIGHTLY=false

for i in "$@"
do
case $i in
    -n|--nightly)
    NIGHTLY=true
    shift
    ;;
    *)
          # unknown option
    ;;
esac
done

if [[ ${NIGHTLY} == "true" ]]
then
  OKD_REGISTRY=${OKD_NIGHTLY_REGISTRY}
fi

getOkdCmds.sh

oc adm -a ${LOCAL_SECRET_JSON} release mirror --from=${OKD_REGISTRY}:${OKD_RELEASE} --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OKD_RELEASE}

