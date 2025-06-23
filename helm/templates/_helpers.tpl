{{/*
Expand the name of the chart.
*/}}
{{- define "particular.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "particular.fullname" -}}
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
{{- define "particular.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "particular.labels" -}}
helm.sh/chart: {{ include "particular.chart" . }}
{{ include "particular.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "particular.selectorLabels" -}}
app.kubernetes.io/name: {{ include "particular.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "particular.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "particular.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Patch the label selector on an object
*/}}
{{- define "particular.patchLabelSelector" -}}
{{- if not (hasKey ._target "labelSelector") }}
{{- $selectorLabels := (include ._selectorLabelsTemplate .) | fromYaml }}
{{- $_ := set ._target "labelSelector" (dict "matchLabels" $selectorLabels) }}
{{- end }}
{{- end }}

{{/*
Patch pod affinity
*/}}
{{- define "particular.patchPodAffinity" -}}
{{- if (hasKey ._podAffinity "requiredDuringSchedulingIgnoredDuringExecution") }}
{{- range $term := ._podAffinity.requiredDuringSchedulingIgnoredDuringExecution }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $term) $) }}
{{- end }}
{{- end }}
{{- if (hasKey ._podAffinity "preferredDuringSchedulingIgnoredDuringExecution") }}
{{- range $weightedTerm := ._podAffinity.preferredDuringSchedulingIgnoredDuringExecution }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $weightedTerm.podAffinityTerm) $) }}
{{- end }}
{{- end }}
{{- end }}