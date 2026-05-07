# Cost Optimization

## Resource Right-Sizing

### Analyze Current Usage

```bash
# View resource requests vs actual usage
kubectl top pods -n production
kubectl top pods -n production --sort-by=cpu
kubectl top pods -n production --sort-by=memory

# Get resource requests/limits per pod
kubectl get pods -n production -o custom-columns=\
"NAME:.metadata.name,\
CPU_REQ:.spec.containers[*].resources.requests.cpu,\
CPU_LIM:.spec.containers[*].resources.limits.cpu,\
MEM_REQ:.spec.containers[*].resources.requests.memory,\
MEM_LIM:.spec.containers[*].resources.limits.memory"

# Get VPA recommendations (if VPA installed)
kubectl get vpa -n production -o yaml
```

### Right-Sized Resource Spec

```yaml
resources:
  requests:
    cpu: 100m      # Set to average usage + 10-20% buffer
    memory: 128Mi
  limits:
    cpu: 500m      # 2-4x requests for burst
    memory: 256Mi  # 1.5-2x requests (OOM prevention)
```

## Vertical Pod Autoscaler (VPA)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: myapp-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  updatePolicy:
    # Off = recommendations only; Auto = apply with restart
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: myapp
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 2000m
          memory: 2Gi
        controlledResources: ["cpu", "memory"]
        controlledValues: RequestsAndLimits
```

## Horizontal Pod Autoscaler (HPA) Tuning

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  minReplicas: 2
  maxReplicas: 20
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Prevent thrashing
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

## Spot/Preemptible Instances

### Workload Tolerating Spot Nodes

```yaml
spec:
  tolerations:
    - key: cloud.google.com/gke-spot
      operator: Equal
      value: "true"
      effect: NoSchedule
    - key: kubernetes.azure.com/scalesetpriority
      operator: Equal
      value: spot
      effect: NoSchedule
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 100
          preference:
            matchExpressions:
              - key: cloud.google.com/gke-spot
                operator: In
                values: ["true"]
```

### Pod Disruption Budget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: myapp-pdb
  namespace: production
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: myapp
```

## Namespace Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: production
spec:
  hard:
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    persistentvolumeclaims: "10"
    pods: "50"
    services: "20"
```

## LimitRange (Defaults)

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: production-limits
  namespace: production
spec:
  limits:
    - type: Container
      default:
        cpu: 500m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
      min:
        cpu: 50m
        memory: 64Mi
      max:
        cpu: 4000m
        memory: 8Gi
    - type: PersistentVolumeClaim
      min:
        storage: 1Gi
      max:
        storage: 100Gi
```

## Scheduled Scaling (Dev Environments)

```yaml
# Scale down dev overnight
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-dev
  namespace: development
spec:
  schedule: "0 20 * * 1-5"  # 8 PM Mon-Fri
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: scaler
          containers:
            - name: kubectl
              image: bitnami/kubectl:latest
              command:
                - /bin/sh
                - -c
                - kubectl scale deployment --all --replicas=0 -n development
          restartPolicy: OnFailure
```

## Priority Classes

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "Critical production workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: false
preemptionPolicy: Never
description: "Batch jobs that can be preempted"
```

## Best Practices

1. **Set resource requests** on all containers (enables efficient scheduling)
2. **Use VPA recommendations** to right-size workloads
3. **Tune HPA stabilization** to prevent thrashing
4. **Leverage spot instances** for fault-tolerant / batch workloads
5. **Implement PDBs** to maintain availability during disruptions
6. **Set namespace quotas** to prevent resource hogging
7. **Use LimitRanges** to enforce sensible defaults
8. **Label resources** for cost attribution (`cost-center`, `team`)
9. **Schedule dev environments** to scale down off-hours
10. **Use priority classes** to ensure critical workloads run first
11. **Review unused resources** regularly (idle deployments, orphaned PVCs)
12. **Monitor with Kubecost** or cloud cost tools
