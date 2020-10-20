# CRC Demo:

```bash
crc oc-env

eval $(crc oc-env)

which oc

oc login -u kubeadmin -p 6Dq36-mD6Ap-ySriA-wZmBr https://api.crc.testing:6443

crc console

htpasswd -B -c -b /tmp/htpasswd admin secret-password

oc create -n openshift-config secret generic htpasswd-secret --from-file=htpasswd=/tmp/htpasswd

oc apply -f ~/Documents/VSCode/GitHub-CGruver/okd4-upi-lab-setup/Provisioning/htpasswd-cr.yaml

oc adm policy add-cluster-role-to-user cluster-admin admin

oc login -u admin https://api.crc.testing:6443

cd ~/Documents/VSCode/GitHub-CGruver/tekton-pipeline-okd4/operator

oc apply -f operator_v1alpha1_config_crd.yaml

oc apply -f role.yaml -n openshift-operators

oc apply -f role_binding.yaml -n openshift-operators

oc apply -f service_account.yaml -n openshift-operators

oc apply -f operator.yaml 

oc apply -f operator_v1alpha1_config_cr.yaml

cd ~/tmp/namespace-configuration-operator

oc adm new-project namespace-configuration-operator

oc apply -f deploy/olm-deploy -n namespace-configuration-operator

cd ~/Documents/VSCode/GitHub-CGruver/tekton-pipeline-okd4/



oc apply -f quarkus-jvm-pipeline-template.yml -n openshift

oc process --local -f namespace-configuration.yml -p MVN_MIRROR_ID=homelab-central -p MVN_MIRROR_NAME=homelab-central -p MVN_MIRROR_URL=https://nexus.clg.lab:8443/repository/maven-public/ | oc apply -f -

oc new-project my-namespace

oc label namespace my-namespace pipeline=tekton

IMAGE_REGISTRY=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
docker login -u $(oc whoami) -p $(oc whoami -t) ${IMAGE_REGISTRY}

docker system prune --all --force

docker pull quay.io/openshift/origin-cli:4.5.0
docker tag quay.io/openshift/origin-cli:4.5.0 ${IMAGE_REGISTRY}/openshift/origin-cli:4.5.0
docker push ${IMAGE_REGISTRY}/openshift/origin-cli:4.5.0

docker build -t ${IMAGE_REGISTRY}/openshift/jdk-ubi-minimal:8.1 jdk-ubi-minimal/
docker push ${IMAGE_REGISTRY}/openshift/jdk-ubi-minimal:8.1

docker build -t ${IMAGE_REGISTRY}/openshift/maven-ubi-minimal:3.6.3-jdk-11 maven-ubi-minimal/
docker push ${IMAGE_REGISTRY}/openshift/maven-ubi-minimal:3.6.3-jdk-11

docker build -t ${IMAGE_REGISTRY}/openshift/buildah:noroot buildah-noroot/
docker push ${IMAGE_REGISTRY}/openshift/buildah:noroot

oc process openshift//quarkus-jvm-pipeline-dev -n my-namespace -p APP_NAME=home-library-catalog -p GIT_REPOSITORY=https://github.com/cgruver/home-library-catalog.git -p GIT_BRANCH=master | oc create -f -