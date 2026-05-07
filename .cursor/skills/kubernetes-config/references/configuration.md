# Kubernetes Configuration Management

## ConfigMap Patterns

### Basic ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: production
data:
  database.host: "postgres-service.database.svc.cluster.local"
  database.port: "5432"
  database.name: "appdb"

  app.properties: |
    server.port=8080
    logging.level=INFO
    cache.enabled=true
    cache.ttl=3600

  config.yaml: |
    server:
      port: 8080
      timeout: 30s
    database:
      pool_size: 20
      max_connections: 100
```

## Secret Patterns

### Opaque Secret (Generic)

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
  namespace: production
type: Opaque
stringData:
  db-password: "MySecurePassword123!"
  api-key: "sk-1234567890abcdef"
  jwt-secret: "super-secret-jwt-key"
```

### TLS Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-tls
  namespace: production
type: kubernetes.io/tls
stringData:
  tls.crt: |
    -----BEGIN CERTIFICATE-----
    ...
    -----END CERTIFICATE-----
  tls.key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

### Docker Registry Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: registry-credentials
  namespace: production
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "myregistry.io": {
          "username": "myuser",
          "password": "mypassword",
          "email": "user@example.com",
          "auth": "bXl1c2VyOm15cGFzc3dvcmQ="
        }
      }
    }
```

## Using ConfigMaps and Secrets

### Environment Variables

```yaml
spec:
  containers:
  - name: app
    image: myapp:v1.0.0
    env:
    - name: DATABASE_HOST
      valueFrom:
        configMapKeyRef:
          name: app-config
          key: database.host
    - name: DATABASE_PASSWORD
      valueFrom:
        secretKeyRef:
          name: app-secrets
          key: db-password
    envFrom:
    - configMapRef:
        name: app-config
      prefix: CONFIG_
    - secretRef:
        name: app-secrets
      prefix: SECRET_
```

### Volume Mounts (preferred for Secrets)

```yaml
spec:
  containers:
  - name: app
    image: myapp:v1.0.0
    volumeMounts:
    - name: config-volume
      mountPath: /etc/config
      readOnly: true
    - name: secrets-volume
      mountPath: /etc/secrets
      readOnly: true
    - name: tls-certs
      mountPath: /etc/tls
      readOnly: true
  volumes:
  - name: config-volume
    configMap:
      name: app-config
  - name: secrets-volume
    secret:
      secretName: app-secrets
      defaultMode: 0400  # Read-only for owner
  - name: tls-certs
    secret:
      secretName: example-tls
```

## Immutable ConfigMaps and Secrets

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: immutable-config
  namespace: production
immutable: true
data:
  key: value
---
apiVersion: v1
kind: Secret
metadata:
  name: immutable-secret
  namespace: production
type: Opaque
immutable: true
stringData:
  password: "MyPassword123"
```

## External Secrets Operator

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: db-password
    remoteRef:
      key: prod/database/password
  - secretKey: api-key
    remoteRef:
      key: prod/api/key
```

## Sealed Secrets (GitOps)

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: app-secrets
  namespace: production
spec:
  encryptedData:
    db-password: AgBj8xK5...encrypted...base64
    api-key: AgCY9mL2...encrypted...base64
  template:
    metadata:
      name: app-secrets
      namespace: production
    type: Opaque
```

## Downward API (Pod Metadata as Env)

```yaml
env:
- name: POD_NAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
- name: POD_NAMESPACE
  valueFrom:
    fieldRef:
      fieldPath: metadata.namespace
- name: POD_IP
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
- name: MEMORY_LIMIT
  valueFrom:
    resourceFieldRef:
      containerName: app
      resource: limits.memory
```

## Best Practices

1. **Separation**: ConfigMaps for non-sensitive data, Secrets for credentials
2. **Immutability**: Mark production configs as immutable for safety
3. **Least Privilege**: Mount secrets as files with restrictive permissions (0400)
4. **External Secrets**: Use External Secrets Operator for cloud secret managers
5. **No Hardcoding**: Never hardcode secrets in container images
6. **Encryption**: Enable encryption at rest for Secrets in etcd
7. **GitOps**: Use Sealed Secrets or SOPS for safe GitOps workflows
8. **Rotation**: Implement secret rotation strategies
9. **Never commit plaintext Secrets** to version control
