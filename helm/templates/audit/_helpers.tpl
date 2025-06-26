{{/*
Fullname
*/}}
{{- define "particular.audit.fullname" -}}
{{ include "particular.fullname" . }}-audit
{{- end }}

{{/*
Common labels
*/}}
{{- define "particular.audit.labels" -}}
{{ include "particular.labels" . }}
app.kubernetes.io/component: "ServiceControl.Audit"
app.kubernetes.io/component-instance: {{ .Release.Name }}-audit
{{- end }}

{{/*
Selector labels
*/}}
{{- define "particular.audit.selectorLabels" -}}
{{ include "particular.selectorLabels" . }}
app.kubernetes.io/component: servicecontrol-audit
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "particular.audit.serviceAccountName" -}}
{{- if .Values.audit.serviceAccount.create -}}
{{- default (printf "%s-servicecontrol-audit" (include "particular.fullname" .)) .Values.audit.serviceAccount.name }}
{{- else -}}
{{- default "default" .Values.audit.serviceAccount.name }}
{{- end -}}
{{- end }}

{{/*
Patch affinity
*/}}
{{- define "particular.audit.patchAffinity" -}}
{{- if and .Values.audit.affinity (hasKey .Values.audit.affinity "podAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.audit.affinity.podAffinity "_selectorLabelsTemplate" "particular.audit.selectorLabels") .) }}
{{- end }}
{{- if and .Values.audit.affinity (hasKey .Values.audit.affinity "podAntiAffinity") }}
{{- include "particular.patchPodAffinity" (merge (dict "_podAffinity" .Values.audit.affinity.podAntiAffinity "_selectorLabelsTemplate" "particular.audit.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
Patch topology spread constraints
*/}}
{{- define "particular.audit.patchTopologySpreadConstraints" -}}
{{- range $constraint := .Values.audit.topologySpreadConstraints }}
{{- include "particular.patchLabelSelector" (merge (dict "_target" $constraint "_selectorLabelsTemplate" "particular.audit.selectorLabels") .) }}
{{- end }}
{{- end }}

{{/*
The image to use
*/}}
{{- define "particular.audit.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.audit.image.repository (default "latest" .Values.audit.image.tag) }}
{{- end }}

{{/*
Instances
*/}}
{{- define "particular.audit.instances" -}}
{{- range (until (.Values.audit.instances | int)) }}
{{ printf "- %s-%s" (include "particular.audit.fullname" $) (toString .) }}
{{- end }}
{{- end }}