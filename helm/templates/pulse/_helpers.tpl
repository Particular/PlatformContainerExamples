{{/*
Fullname
*/}}
{{- define "particular.pulse.fullname" -}}
{{ include "particular.fullname" . }}-pulse
{{- end }}

{{/*
Common labels
*/}}
{{- define "particular.pulse.labels" -}}
{{ include "particular.labels" . }}
app.kubernetes.io/component: "ServicePulse"
app.kubernetes.io/component-instance: {{ .Release.Name }}-pulse
{{- end }}

{{/*
Selector labels
*/}}
{{- define "particular.pulse.selectorLabels" -}}
{{ include "particular.selectorLabels" . }}
app.kubernetes.io/component: service-pulse
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "particular.pulse.serviceAccountName" -}}
{{- if .Values.pulse.serviceAccount.create -}}
{{- default (printf "%s-service-pulse" (include "particular.fullname" .)) .Values.pulse.serviceAccount.name }}
{{- else -}}
{{- default "default" .Values.pulse.serviceAccount.name }}
{{- end -}}
{{- end }}

{{/*
Patch affinity
*/}}
{{- define "particular.pulse.patchAffinity" -}}
{{- if and .Values.pulse.affinity (hasKey .Values.pulse.affinity "podAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.pulse.affinity.podAffinity "_selectorLabelsTemplate" "particular.pulse.selectorLabels") .) }}
{{- end }}
{{- if and .Values.pulse.affinity (hasKey .Values.pulse.affinity "podAntiAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.pulse.affinity.podAntiAffinity "_selectorLabelsTemplate" "particular.pulse.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
Patch topology spread constraints
*/}}
{{- define "particular.pulse.patchTopologySpreadConstraints" -}}
{{- range $constraint := .Values.pulse.topologySpreadConstraints }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $constraint "_selectorLabelsTemplate" "particular.pulse.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
The image to use
*/}}
{{- define "particular.pulse.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.pulse.image.repository (default "latest" .Values.pulse.image.tag) }}
{{- end }}