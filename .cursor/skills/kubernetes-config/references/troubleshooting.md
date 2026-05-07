# Kubernetes Troubleshooting

## Essential kubectl Commands

### Pod Inspection

```bash
# Get pods with details
kubectl get pods -n production -o wide
kubectl get pods --all-namespaces
kubectl get pods --selector app=web-app

# Describe pod (shows events)
kubectl describe pod <pod-name> -n production

# Get pod logs
kubectl logs <pod-name> -n production
kubectl logs <pod-name> -n production --previous  # Previous container
kubectl logs <pod-name> -n production -c init-container
kubectl logs -f <pod-name> -n production          # Follow logs
kubectl logs --tail=100 <pod-name> -n production
kubectl logs --since=1h <pod-name> -n production

# Execute commands in pod
kubectl exec -it <pod-name> -n production -- /bin/sh
kubectl exec <pod-name> -n production -- env

# Port forward
kubectl port-forward <pod-name> 8080:8080 -n production
kubectl port-forward service/web-app 8080:80 -n production
```

### Deployment Debugging

```bash
# Check deployment status
kubectl get deployment web-app -n production
kubectl describe deployment web-app -n production
kubectl rollout status deployment/web-app -n production
kubectl rollout history deployment/web-app -n production

# Rollback deployment
kubectl rollout undo deployment/web-app -n production
kubectl rollout undo deployment/web-app --to-revision=2 -n production

# Restart deployment (recreate pods)
kubectl rollout restart deployment/web-app -n production
```

### Network Debugging

```bash
# Get services and endpoints
kubectl get svc -n production
kubectl get endpoints web-app -n production
kubectl describe endpoints web-app -n production

# Get network policies
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-all -n production

# Get events (sorted by timestamp)
kubectl get events -n production --sort-by='.lastTimestamp'
```

## Debug Pod (Ephemeral Container)

```bash
# Attach debug container to running pod
kubectl debug -it <pod-name> -n production \
  --image=nicolaka/netshoot:latest \
  --target=web-app

# Create copy of pod with debug tools
kubectl debug <pod-name> -n production \
  -it \
  --image=ubuntu:latest \
  --share-processes \
  --copy-to=web-app-debug
```

## Common Issues and Solutions

### Pod in Pending State

```bash
# Check pod events
kubectl describe pod <pod-name> -n production

# Causes: insufficient resources, PVC not bound, ImagePullBackOff, affinity mismatch
kubectl top nodes
kubectl get pvc -n production
```

### CrashLoopBackOff

```bash
# Check logs from crashed container
kubectl logs <pod-name> -n production --previous

# Check if liveness probe is failing
kubectl describe pod <pod-name> -n production | grep -A 10 "Liveness"
```

### ImagePullBackOff

```bash
# Check image pull secret
kubectl get secret registry-credentials -n production -o yaml

# Create/update image pull secret
kubectl create secret docker-registry registry-credentials \
  --docker-server=myregistry.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  -n production
```

### Service Not Accessible

```bash
# Check endpoints match pod labels
kubectl get endpoints web-app -n production
kubectl get pod <pod-name> -n production --show-labels

# Test connectivity from debug pod
kubectl run debug --image=nicolaka/netshoot:latest -it --rm -n production -- bash
# Inside:
curl http://web-app.production.svc.cluster.local
nslookup web-app.production.svc.cluster.local
```

### NetworkPolicy Blocking Traffic

```bash
kubectl get networkpolicy -n production
kubectl describe networkpolicy default-deny-all -n production

# Test connectivity
kubectl run test --image=nicolaka/netshoot:latest -it --rm -n production -- bash
# Inside:
nc -zv web-app 80
```

### High Resource Usage

```bash
kubectl top nodes
kubectl top pods -n production
kubectl top pods -n production --sort-by=cpu
kubectl top pods -n production --sort-by=memory
```

## RBAC Debugging

```bash
# Check if ServiceAccount can perform action
kubectl auth can-i get pods \
  --as=system:serviceaccount:production:web-app-sa -n production

# List all permissions for ServiceAccount
kubectl auth can-i --list \
  --as=system:serviceaccount:production:web-app-sa -n production
```

## Quick Reference

### Pod States
- **Pending**: Waiting to be scheduled
- **ContainerCreating**: Pulling image / creating container
- **Running**: Pod is running
- **Succeeded**: All containers exited successfully
- **Failed**: At least one container failed
- **CrashLoopBackOff**: Container keeps crashing
- **ImagePullBackOff**: Cannot pull image
- **ErrImagePull**: Image pull error

### Common Exit Codes
- **0**: Success
- **1**: General error
- **137**: SIGKILL (OOMKilled - out of memory)
- **139**: SIGSEGV (segmentation fault)
- **143**: SIGTERM (graceful termination)

## Diagnostic Tools

### Network Tools Pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: netshoot
  namespace: production
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot:latest
    command: ["/bin/sleep", "3600"]
  restartPolicy: Never
```

## Best Practices

1. **Logs first**: Always check `kubectl logs` before anything else
2. **Events**: Use `kubectl describe` to see events for state changes
3. **Labels**: Consistent labels make filtering and debugging much easier
4. **Resources**: Properly sized requests/limits prevent OOMKill and throttling
5. **Health Checks**: Correct liveness/readiness probes prevent traffic to unhealthy pods
6. **Monitoring**: Set up Prometheus + Alertmanager for proactive alerting
