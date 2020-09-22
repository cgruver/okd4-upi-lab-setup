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

## WIP from here down:

Assume node taints of: `infra=reserved:NoSchedule`, `infra=reserved:NoExecute`

* IngressController: `oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}},"tolerations":[{"key":"infra","value":"reserved","effect":"NoSchedule"},{"key":"infra","value":"reserved","effect":"NoExecute"}]}}}' --type=merge`

* ImageRegistry: `oc patch configs.imageregistry.operator.openshift.io cluster --patch '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra":""},"tolerations":[{"key":"infra","value":"reserved","effect":"NoSchedule"},{"key":"infra","value":"reserved","effect":"NoExecute"}]}}' --type=merge`

* Cluster Monitoring:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    prometheusOperator:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    openshiftStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
    thanosQuerier:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoSchedule"
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "reserved"
        effect: "NoExecute"
```

`oc apply -f cluster-monitoring-config.yaml -n openshift-monitoring`
