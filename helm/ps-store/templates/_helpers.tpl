{{/*
Common chart helpers.
*/}}

{{- define "ps-store.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ps-store.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := include "ps-store.name" . -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ps-store.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{/*
Standard labels (do not use in selectors).
Usage:
  labels: {{- include "ps-store.labels" (dict "ctx" . "component" "frontend") | nindent 4 }}
*/}}
{{- define "ps-store.labels" -}}
{{- $ctx := .ctx -}}
app.kubernetes.io/name: {{ .component | quote }}
app.kubernetes.io/instance: {{ $ctx.Release.Name | quote }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
app.kubernetes.io/component: {{ .component | quote }}
app.kubernetes.io/part-of: {{ include "ps-store.name" $ctx | quote }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service | quote }}
helm.sh/chart: {{ include "ps-store.chart" $ctx | quote }}
{{- with $ctx.Values.commonLabels }}
{{- toYaml . }}
{{- end }}
{{- end -}}

{{/*
Selector labels (immutable).
Usage:
  selector: {{- include "ps-store.selectorLabels" (dict "ctx" . "component" "frontend") | nindent 4 }}
*/}}
{{- define "ps-store.selectorLabels" -}}
app.kubernetes.io/name: {{ .component | quote }}
app.kubernetes.io/instance: {{ .ctx.Release.Name | quote }}
app.kubernetes.io/component: {{ .component | quote }}
{{- end -}}

{{/*
Image reference helper.
Usage:
  image: {{ include "ps-store.image" (dict "ctx" . "img" .Values.frontend.image) | quote }}
*/}}
{{- define "ps-store.image" -}}
{{- printf "%s:%s" .img.repository (.img.tag | default .ctx.Chart.AppVersion) -}}
{{- end -}}

{{/*
Image pull secrets helper.
*/}}
{{- define "ps-store.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml .Values.imagePullSecrets | nindent 2 }}
{{- end }}
{{- end -}}

{{/*
Pod annotations for config checksum to trigger rollout on changes.
*/}}
{{- define "ps-store.podAnnotations" -}}
{{- $ctx := .ctx -}}
{{- if $ctx.Values.commonAnnotations }}
{{- toYaml $ctx.Values.commonAnnotations }}
{{- end }}
checksum/config: {{ .config | sha256sum }}
{{- end -}}
