# Custom Operators

## CustomResourceDefinition (CRD)

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.mycompany.io
spec:
  group: mycompany.io
  names:
    kind: Database
    listKind: DatabaseList
    plural: databases
    singular: database
    shortNames:
      - db
  scope: Namespaced
  versions:
    - name: v1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              required:
                - engine
                - version
                - storage
              properties:
                engine:
                  type: string
                  enum: [postgres, mysql, mongodb]
                version:
                  type: string
                storage:
                  type: string
                  pattern: '^[0-9]+Gi$'
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 5
                  default: 1
            status:
              type: object
              properties:
                phase:
                  type: string
                  enum: [Pending, Creating, Running, Failed, Terminating]
                ready:
                  type: boolean
                message:
                  type: string
                endpoint:
                  type: string
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Engine
          type: string
          jsonPath: .spec.engine
        - name: Status
          type: string
          jsonPath: .status.phase
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
```

## Custom Resource Instance

```yaml
apiVersion: mycompany.io/v1
kind: Database
metadata:
  name: orders-db
  namespace: production
spec:
  engine: postgres
  version: "15.4"
  storage: 100Gi
  replicas: 3
```

## Operator SDK Project Structure

```
my-operator/
├── Dockerfile
├── Makefile
├── PROJECT
├── config/
│   ├── crd/bases/
│   ├── manager/manager.yaml
│   └── rbac/
├── api/v1/
│   ├── database_types.go
│   └── zz_generated.deepcopy.go
├── controllers/
│   └── database_controller.go
└── main.go
```

## API Type Definition (Go)

```go
// api/v1/database_types.go
package v1

import metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"

type DatabaseSpec struct {
    // +kubebuilder:validation:Enum=postgres;mysql;mongodb
    Engine string `json:"engine"`
    Version string `json:"version"`
    // +kubebuilder:validation:Pattern=`^[0-9]+Gi$`
    Storage string `json:"storage"`
    // +kubebuilder:validation:Minimum=1
    // +kubebuilder:validation:Maximum=5
    // +kubebuilder:default=1
    // +optional
    Replicas int32 `json:"replicas,omitempty"`
}

type DatabaseStatus struct {
    Phase    string `json:"phase,omitempty"`
    Ready    bool   `json:"ready,omitempty"`
    Message  string `json:"message,omitempty"`
    Endpoint string `json:"endpoint,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
type Database struct {
    metav1.TypeMeta   `json:",inline"`
    metav1.ObjectMeta `json:"metadata,omitempty"`
    Spec   DatabaseSpec   `json:"spec,omitempty"`
    Status DatabaseStatus `json:"status,omitempty"`
}
```

## Operator RBAC

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: database-operator
  namespace: operators
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: database-operator-role
rules:
  - apiGroups: ["mycompany.io"]
    resources: ["databases", "databases/status", "databases/finalizers"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: ["apps"]
    resources: ["statefulsets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["services", "configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: database-operator-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: database-operator-role
subjects:
  - kind: ServiceAccount
    name: database-operator
    namespace: operators
```

## Operator Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-operator
  namespace: operators
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database-operator
  template:
    metadata:
      labels:
        app: database-operator
    spec:
      serviceAccountName: database-operator
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: manager
          image: myregistry.io/database-operator:v1.0.0
          args:
            - --leader-elect
            - --health-probe-bind-address=:8081
          securityContext:
            allowPrivilegeEscalation: false
            capabilities:
              drop: ["ALL"]
            readOnlyRootFilesystem: true
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8081
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /readyz
              port: 8081
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            limits:
              cpu: 500m
              memory: 128Mi
            requests:
              cpu: 10m
              memory: 64Mi
```

## Operator SDK Commands

```bash
# Initialize new operator project
operator-sdk init --domain mycompany.io --repo github.com/mycompany/database-operator

# Create new API (CRD + controller)
operator-sdk create api --group mycompany --version v1 --kind Database --resource --controller

# Generate manifests (CRD, RBAC)
make manifests

# Generate deep copy methods
make generate

# Build and deploy
make docker-build docker-push IMG=myregistry.io/database-operator:v1.0.0
make deploy IMG=myregistry.io/database-operator:v1.0.0
```

## Best Practices

1. **Use finalizers** for cleanup of external resources before CR deletion
2. **Set owner references** so owned resources are garbage collected with the CR
3. **Implement idempotent reconciliation** — same input should produce same output
4. **Use status subresource** to separate desired state (spec) from observed state (status)
5. **Add OpenAPI validation** to the CRD schema
6. **Emit events** for significant state changes
7. **Use leader election** for high availability (`--leader-elect`)
8. **Set resource limits** on the operator deployment itself
9. **Follow least privilege** RBAC principles
10. **Test with envtest** for unit testing controllers
