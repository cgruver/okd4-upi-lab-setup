## Designate Master nodes as Infrastructure nodes

1. Add a label to your master nodes:

    ```bash
    for i in 0 1 2
    do
      oc label nodes okd4-master-${i}.${LAB_DOMAIN} node-role.kubernetes.io/infra=""
    done
    ```

1. Remove the `worker` label from the master nodes:

    ```bash
    oc patch scheduler cluster --patch '{"spec":{"mastersSchedulable":false}}' --type=merge
    ```

1. Add `nodePlacement` and taint tolerations to the Ingress Controller:

    ```bash
    oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}},"tolerations":[{"key":"node.kubernetes.io/unschedulable","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","effect":"NoSchedule"}]}}}' --type=merge
    ```

1. Verify that your Ingress pods get provisioned onto the master nodes:

    ```bash
    oc get pod -n openshift-ingress -o wide
    ```

1. Repeat for the ImageRegistry:

    ```bash
    oc patch configs.imageregistry.operator.openshift.io cluster --patch '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra":""},"tolerations":[{"key":"node.kubernetes.io/unschedulable","effect":"NoSchedule"},{"key":"node-role.kubernetes.io/master","effect":"NoSchedule"}]}}' --type=merge
    ```

1. Finally for Cluster Monitoring:

    Create a file named `cluster-monitoring-config.yaml` with the following content:

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
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        prometheusK8s:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
           - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        alertmanagerMain:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        kubeStateMetrics:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        grafana:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        telemeterClient:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        k8sPrometheusAdapter:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        openshiftStateMetrics:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
        thanosQuerier:
          nodeSelector:
            node-role.kubernetes.io/infra: ""
          tolerations:
          - key: "node-role.kubernetes.io/master"
            operator: "Equal"
            value: ""
            effect: "NoSchedule"
    ```
# Work In Progress from here down:

## Designate selected Worker nodes as Infrastructure nodes

       for i in 0 1 2
       do
          oc label nodes okd4-infra-${i}.${LAB_DOMAIN} node-role.kubernetes.io/infra=""
          oc adm taint nodes okd4-infra-${i}.${LAB_DOMAIN} infra=infraNode:NoSchedule
          oc adm taint nodes okd4-infra-${i}.${LAB_DOMAIN} infra=infraNode:NoExecute
       done

## Move Workloads to the new Infra nodes

* IngressController: `oc patch -n openshift-ingress-operator ingresscontroller default --patch '{"spec":{"nodePlacement":{"nodeSelector":{"matchLabels":{"node-role.kubernetes.io/infra":""}},"tolerations":[{"key":"infra","value":"infraNode","effect":"NoSchedule"},{"key":"infra","value":"infraNode","effect":"NoExecute"}]}}}' --type=merge`

* ImageRegistry: `oc patch configs.imageregistry.operator.openshift.io cluster --patch '{"spec":{"nodeSelector":{"node-role.kubernetes.io/infra":""},"tolerations":[{"key":"infra","value":"infraNode","effect":"NoSchedule"},{"key":"infra","value":"infraNode","effect":"NoExecute"}]}}' --type=merge`

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
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    prometheusK8s:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    alertmanagerMain:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    kubeStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    grafana:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    telemeterClient:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    k8sPrometheusAdapter:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    openshiftStateMetrics:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
    thanosQuerier:
      nodeSelector:
        node-role.kubernetes.io/infra: ""
      tolerations:
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoSchedule"
      - key: "infra"
        operator: "Equal"
        value: "infraNode"
        effect: "NoExecute"
```

`oc apply -f cluster-monitoring-config.yaml -n openshift-monitoring`
