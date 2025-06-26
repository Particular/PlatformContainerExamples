{{/*
Fullname
*/}}
{{- define "particular.error.fullname" -}}
{{ include "particular.fullname" . }}-error
{{- end }}

{{/*
Common labels
*/}}
{{- define "particular.error.labels" -}}
{{ include "particular.labels" . }}
app.kubernetes.io/component: "ServiceControl.Error"
app.kubernetes.io/component-instance: {{ .Release.Name }}-error
{{- end }}

{{/*
Selector labels
*/}}
{{- define "particular.error.selectorLabels" -}}
{{ include "particular.selectorLabels" . }}
app.kubernetes.io/component: servicecontrol-error
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "particular.error.serviceAccountName" -}}
{{- if .Values.error.serviceAccount.create -}}
{{- default (printf "%s-servicecontrol-error" (include "particular.fullname" .)) .Values.error.serviceAccount.name }}
{{- else -}}
{{- default "default" .Values.error.serviceAccount.name }}
{{- end -}}
{{- end }}

{{/*
Patch affinity
*/}}
{{- define "particular.error.patchAffinity" -}}
{{- if and .Values.error.affinity (hasKey .Values.error.affinity "podAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.error.affinity.podAffinity "_selectorLabelsTemplate" "particular.error.selectorLabels") .) }}
{{- end }}
{{- if and .Values.error.affinity (hasKey .Values.error.affinity "podAntiAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.error.affinity.podAntiAffinity "_selectorLabelsTemplate" "particular.error.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
Patch topology spread constraints
*/}}
{{- define "particular.error.patchTopologySpreadConstraints" -}}
{{- range $constraint := .Values.error.topologySpreadConstraints }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $constraint "_selectorLabelsTemplate" "particular.error.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
The image to use
*/}}
{{- define "particular.error.image" -}}
{{- $tag := .Values.error.image.tag | default .Chart.AppVersion -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.error.image.repository $tag -}}
{{- end }}

{{/*
Audit instances
*/}}
{{- define "particular.error.auditInstances" -}}
[
{{- $instances := include "particular.audit.instances" . | fromYamlArray -}}
{{- range $index, $instance := $instances -}}
{{- if $index }}, {{ end -}}
{ "api_uri": "http://{{ $instance }}:{{ $.Values.audit.service.port }}/api" }
{{- end -}}
]
{{- end }}