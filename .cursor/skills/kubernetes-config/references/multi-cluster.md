# Multi-Cluster Management

## Cluster API

### Installation

```bash
# Install clusterctl CLI
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.6.0/clusterctl-linux-amd64 -o clusterctl
chmod +x clusterctl && sudo mv clusterctl /usr/local/bin/

# Initialize management cluster with AWS provider
clusterctl init --infrastructure aws
```

### Cluster Definition

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: production-cluster
  namespace: clusters
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["192.168.0.0/16"]
    services:
      cidrBlocks: ["10.96.0.0/12"]
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: production-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta2
    kind: AWSCluster
    name: production-cluster
```

## Cross-Cluster Networking

### Submariner

```bash
# Deploy broker
subctl deploy-broker --kubeconfig kubeconfig-cluster1

# Join workload clusters
subctl join --kubeconfig kubeconfig-cluster1 broker-info.subm --clusterid cluster1
subctl join --kubeconfig kubeconfig-cluster2 broker-info.subm --clusterid cluster2

subctl show all
```

### ServiceExport/ServiceImport

```yaml
# Export service from cluster1
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: myapp
  namespace: production
# Auto-imported to other clusters as:
# myapp.production.svc.clusterset.local
```

### Cilium Cluster Mesh

```bash
cilium clustermesh enable --context cluster1
cilium clustermesh enable --context cluster2
cilium clustermesh connect --context cluster1 --destination-context cluster2
```

```yaml
# Global service accessible from all clusters
apiVersion: v1
kind: Service
metadata:
  name: myapp
  namespace: production
  annotations:
    service.cilium.io/global: "true"
spec:
  type: ClusterIP
  selector:
    app: myapp
  ports:
    - port: 80
```

## ArgoCD Multi-Cluster (ApplicationSet)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: myapp-global
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
  template:
    metadata:
      name: 'myapp-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/myorg/myapp-manifests.git
        targetRevision: main
        path: overlays/production
      destination:
        server: '{{server}}'
        namespace: production
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
```

## Disaster Recovery with Velero

```bash
# Install Velero with S3
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket velero-backups \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file ./credentials-velero
```

```yaml
# Scheduled backup
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - production
      - staging
    storageLocation: default
    volumeSnapshotLocations:
      - default
    ttl: 720h  # 30 days
```

## Kubeconfig Management

```bash
# Switch between clusters
kubectl config use-context us-west
kubectl config use-context us-east

# Run command against specific cluster
kubectl --context=us-west get pods
kubectl --context=us-east get pods

# Use kubectx for easier switching
kubectx us-west
```

## Best Practices

1. **Use Cluster API** for declarative cluster lifecycle management
2. **Implement service mesh** for secure cross-cluster communication
3. **Set up DNS-based routing** for global service discovery
4. **Configure automated backups** with Velero across clusters
5. **Use GitOps** (ArgoCD/Flux) for consistent multi-cluster deployments
6. **Implement NetworkPolicies** consistently across clusters
7. **Centralize observability** with cross-cluster metrics and logs
8. **Test failover procedures** regularly with chaos engineering
9. **Use namespaces consistently** across clusters
10. **Document cluster topology** and dependencies
11. **Monitor cluster health** from a centralized dashboard (Rancher, Lens)
