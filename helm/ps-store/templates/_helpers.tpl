{{/*
Shared helpers for the ps-store chart.

Most helpers take a `dict` as input so we can pass both the chart context
(`ctx`) and a per-component value (e.g. the component name or image block).
*/}}

{{/* Chart name — safely truncated and DNS-1123 compliant. */}}
{{- define "ps-store.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Chart label (helm.sh/chart). */}}
{{- define "ps-store.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels applied to every resource.
Usage: {{- include "ps-store.labels" (dict "ctx" . "component" "order-service") | nindent 4 }}
*/}}
{{- define "ps-store.labels" -}}
{{- $ctx := .ctx -}}
helm.sh/chart: {{ include "ps-store.chart" $ctx }}
{{ include "ps-store.selectorLabels" . }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
app.kubernetes.io/part-of: {{ include "ps-store.name" $ctx }}
app.kubernetes.io/component: {{ .component }}
{{- end -}}

{{/*
Selector labels — must be a STRICT subset of common labels (no chart/version).
Usage: {{- include "ps-store.selectorLabels" (dict "ctx" . "component" "order-service") | nindent 6 }}
*/}}
{{- define "ps-store.selectorLabels" -}}
{{- $ctx := .ctx -}}
app.kubernetes.io/name: {{ .component }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
{{- end -}}

{{/*
Image reference. Respects .Values.global.imageRegistry when set.
Usage: image: {{ include "ps-store.image" (dict "ctx" . "img" .Values.orderService.image) | quote }}
*/}}
{{- define "ps-store.image" -}}
{{- $reg := .ctx.Values.global.imageRegistry | default "" -}}
{{- $repo := required "image.repository is required" .img.repository -}}
{{- $tag := required "image.tag is required — never use :latest" .img.tag -}}
{{- if $reg -}}
{{ $reg }}/{{ $repo }}:{{ $tag }}
{{- else -}}
{{ $repo }}:{{ $tag }}
{{- end -}}
{{- end -}}

{{/*
Rendered imagePullSecrets block (or nothing).
Usage: {{- include "ps-store.imagePullSecrets" . | nindent 6 }}
*/}}
{{- define "ps-store.imagePullSecrets" -}}
{{- with .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range . }}
  - name: {{ . }}
{{- end }}
{{- end -}}
{{- end -}}

{{/*
Postgres host — in-chart service name or external host.
Usage: {{ include "ps-store.pgHost" . }}
*/}}
{{- define "ps-store.pgHost" -}}
{{- if .Values.postgres.enabled -}}
postgres
{{- else -}}
{{- required "postgres.external.host required when postgres.enabled=false" .Values.postgres.external.host -}}
{{- end -}}
{{- end -}}

{{/*
Postgres port — in-chart service port or external port.
*/}}
{{- define "ps-store.pgPort" -}}
{{- if .Values.postgres.enabled -}}
{{ .Values.postgres.service.port }}
{{- else -}}
{{ .Values.postgres.external.port | default 5432 }}
{{- end -}}
{{- end -}}

{{/*
Postgres libpq URI (Python / Node services).
Usage: {{ include "ps-store.pgUri" (dict "ctx" . "db" "order_db") | quote }}
*/}}
{{- define "ps-store.pgUri" -}}
{{- $ctx := .ctx -}}
{{- $user := $ctx.Values.postgres.auth.username -}}
{{- $pass := $ctx.Values.postgres.auth.password -}}
{{- $host := include "ps-store.pgHost" $ctx -}}
{{- $port := include "ps-store.pgPort" $ctx -}}
postgresql://{{ $user }}:{{ $pass }}@{{ $host }}:{{ $port }}/{{ .db }}
{{- end -}}

{{/*
Postgres .NET connection string (user-service).
Usage: {{ include "ps-store.pgDotnet" (dict "ctx" . "db" "user_db") | quote }}
*/}}
{{- define "ps-store.pgDotnet" -}}
{{- $ctx := .ctx -}}
{{- $user := $ctx.Values.postgres.auth.username -}}
{{- $pass := $ctx.Values.postgres.auth.password -}}
{{- $host := include "ps-store.pgHost" $ctx -}}
{{- $port := include "ps-store.pgPort" $ctx -}}
Host={{ $host }};Port={{ $port }};Database={{ .db }};Username={{ $user }};Password={{ $pass }}
{{- end -}}

{{/*
ServiceAccount name for a component.
Usage: {{ include "ps-store.serviceAccountName" (dict "ctx" . "sa" .Values.orderService.serviceAccount "default" "order-service") }}
*/}}
{{- define "ps-store.serviceAccountName" -}}
{{- if .sa.create -}}
{{- default .default .sa.name -}}
{{- else -}}
{{- default "default" .sa.name -}}
{{- end -}}
{{- end -}}
