## Setting up HTPasswd as an Identity Provider

These instructions will help you set up an Identity provider so that you can remove the temporary kubeadmin user.

1. Create an htpasswd file with two users.  The `user` admin will be assigned the password that was created when you installed your cluster.  The user `devuser` will be assigned the password `devpwd`.  THe user `devuser` will have default permissions.

       mkdir -p ${OKD4_LAB_PATH}/okd-creds
       htpasswd -B -c -b ${OKD4_LAB_PATH}/okd-creds/htpasswd admin $(cat ${OKD4_LAB_PATH}/okd4-install-dir/auth/kubeadmin-password)
       htpasswd -b ${OKD4_LAB_PATH}/okd-creds/htpasswd devuser devpwd

1. Now, create a Secret with this htpasswd file:

       oc create -n openshift-config secret generic htpasswd-secret --from-file=htpasswd=${OKD4_LAB_PATH}/okd-creds/htpasswd

1. Create the Htpasswd Identity Provider:

    I have provided an Identity Provider custom resource configuration located at `./Provisioning/htpasswd-cr.yaml` in this project.

    From the root of this project run:

       oc apply -f ./Provisioning/htpasswd-cr.yaml

1. Make the user `admin` a Cluster Administrator:

       oc adm policy add-cluster-role-to-user cluster-admin admin

1. Now, log into the web console as your new admin user to verify access.  Select the `Htpasswd` provider when you log in.

1. Finally, remove temporary user:

       oc delete secrets kubeadmin -n kube-system
