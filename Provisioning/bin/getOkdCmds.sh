
#!/bin/bash

OKD_REGISTRY=${OKD_STABLE_REGISTRY}

for i in "$@"
do
case $i in
-n|--nightly)
    OKD_REGISTRY=${OKD_NIGHTLY_REGISTRY}
    shift
    ;;
    *)
          # put usage here:
    ;;
esac
done

mkdir -p ${OKD4_LAB_PATH}/okd-release-tmp
cd ${OKD4_LAB_PATH}/okd-release-tmp
oc adm release extract --command='openshift-install' ${OKD_REGISTRY}:${OKD_RELEASE}
oc adm release extract --command='oc' ${OKD_REGISTRY}:${OKD_RELEASE}
mv -f openshift-install ~/bin
mv -f oc ~/bin
cd ..
rm -rf okd-release-tmp
