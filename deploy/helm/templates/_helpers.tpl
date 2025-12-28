{{/*
Expand the name of the chart.
*/}}
{{- define "flashsale.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flashsale.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "flashsale.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "flashsale.labels" -}}
helm.sh/chart: {{ include "flashsale.chart" . }}
{{ include "flashsale.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "flashsale.selectorLabels" -}}
app.kubernetes.io/name: {{ include "flashsale.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service specific labels
*/}}
{{- define "flashsale.serviceLabels" -}}
app: flashsale
service: {{ .serviceName }}
{{- end }}

{{/*
Service specific selector labels
*/}}
{{- define "flashsale.serviceSelectorLabels" -}}
app: flashsale
service: {{ .serviceName }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "flashsale.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "flashsale.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image pull secrets
*/}}
{{- define "flashsale.imagePullSecrets" -}}
{{- if .Values.imagePullSecrets }}
imagePullSecrets:
{{- range .Values.imagePullSecrets }}
  - name: {{ .name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Generate full image name
*/}}
{{- define "flashsale.image" -}}
{{- $registry := .root.Values.image.registry | default "docker.io" }}
{{- $prefix := .root.Values.image.prefix | default "flashsale" }}
{{- $tag := .root.Values.image.tag | default .root.Chart.AppVersion | default "latest" }}
{{- printf "%s/%s/%s:%s" $registry $prefix .serviceName $tag }}
{{- end }}

{{/*
Get service type (api, rpc, or mq)
*/}}
{{- define "flashsale.serviceType" -}}
{{- if hasSuffix "-api" .serviceName }}
{{- print "api" }}
{{- else if hasSuffix "-rpc" .serviceName }}
{{- print "rpc" }}
{{- else }}
{{- print "mq" }}
{{- end }}
{{- end }}

{{/*
Get service resources
*/}}
{{- define "flashsale.resources" -}}
{{- $serviceType := include "flashsale.serviceType" . }}
{{- if eq $serviceType "api" }}
{{- toYaml .root.Values.resources.api }}
{{- else if eq $serviceType "rpc" }}
{{- toYaml .root.Values.resources.rpc }}
{{- else }}
{{- toYaml .root.Values.resources.mq }}
{{- end }}
{{- end }}
