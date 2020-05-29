## Designate Master nodes as Infrastructure nodes

1. Add a label to your master nodes:

       for i in 0 1 2
       do
          oc label nodes okd4-master-${i}.${LAB_DOMAIN} node-role.kubernetes.io/infra=""
       done

1. Remove the `worker` label from the master nodes:

       oc patch scheduler cluster --patch '{"spec":{"mastersSchedulable":false}}' --type=merge

1. Add `nodePlacement` and taint tolerations to the Ingress Controller:

       oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}},"tolerations":[{"key":"node.kubernetes.io/unschedulable","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","effect":"NoSchedule"}]}}}' --type=merge

1. Verify that your Ingress pods get provisioned onto the master nodes:

       oc get pod -n openshift-ingress -o wide
