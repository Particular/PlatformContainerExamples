{{/*
Fullname
*/}}
{{- define "particular.monitor.fullname" -}}
{{ include "particular.fullname" . }}-monitor
{{- end }}

{{/*
Common labels
*/}}
{{- define "particular.monitor.labels" -}}
{{ include "particular.labels" . }}
app.kubernetes.io/component: "ServiceControl.Monitor"
app.kubernetes.io/component-instance: {{ .Release.Name }}-monitor
{{- end }}

{{/*
Selector labels
*/}}
{{- define "particular.monitor.selectorLabels" -}}
{{ include "particular.selectorLabels" . }}
app.kubernetes.io/component: servicecontrol-monitor
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "particular.monitor.serviceAccountName" -}}
{{- if .Values.monitor.serviceAccount.create -}}
{{- default (printf "%s-servicecontrol-monitor" (include "particular.fullname" .)) .Values.monitor.serviceAccount.name }}
{{- else -}}
{{- default "default" .Values.monitor.serviceAccount.name }}
{{- end -}}
{{- end }}

{{/*
Patch affinity
*/}}
{{- define "particular.monitor.patchAffinity" -}}
{{- if and .Values.monitor.affinity (hasKey .Values.monitor.affinity "podAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.monitor.affinity.podAffinity "_selectorLabelsTemplate" "particular.monitor.selectorLabels") .) }}
{{- end }}
{{- if and .Values.monitor.affinity (hasKey .Values.monitor.affinity "podAntiAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.monitor.affinity.podAntiAffinity "_selectorLabelsTemplate" "particular.monitor.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
Patch topology spread constraints
*/}}
{{- define "particular.monitor.patchTopologySpreadConstraints" -}}
{{- range $constraint := .Values.monitor.topologySpreadConstraints }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $constraint "_selectorLabelsTemplate" "particular.monitor.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
The image to use
*/}}
{{- define "particular.monitor.image" -}}
{{- $tag := .Values.monitor.image.tag | default .Chart.AppVersion -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.monitor.image.repository $tag -}}
{{- end }}