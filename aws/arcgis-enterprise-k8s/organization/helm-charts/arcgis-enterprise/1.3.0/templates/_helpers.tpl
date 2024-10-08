

{{/*
Docker image pull secret
*/}}
{{- define "imagePullSecret" }}
{{- with .Values.image }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}

{{/*
Get a generic registry image path

Call with {{ include "imagePath" ( dict "image" "enterprise-admin-tools" "global" . ) }}
*/}}
{{- define "imagePath" }}
{{- if .global.Values.image.repository }}
{{- printf "%s/%s/%s:%v" .global.Values.image.registry .global.Values.image.repository .image .global.Values.image.tag }}
{{- else }}
{{- printf "%s/%s:%v" .global.Values.image.registry .image .global.Values.image.tag }}
{{- end }}
{{- end }}

