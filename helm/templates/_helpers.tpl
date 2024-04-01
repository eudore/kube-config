{{- define "selectorLabels" -}}
app: "{{ .Release.Name }}"
{{- end }}


{{- define "hook-timezone" -}}
{{- $deployment := .Values.data.deployment }}
{{- $m := dict "name" "timezone" "mountPath" "/etc/localtime"}}
{{- $v := dict "name" "timezone" "hostPath" (dict "path" "/usr/share/zoneinfo/Asia/Shanghai" "type" "File")}}
{{- $_ := set $deployment "volumeMounts" (append ($deployment.volumeMounts | default list) $m)}}
{{- $_ := set $deployment "volumes" (append ($deployment.volumes | default list) $v)}}
{{- end }}


{{- define "hook-command" -}}
{{- $deployment := .Values.data.deployment }}
{{- if eq .Values.type "java" }}
  {{- $port := "8080" }}
  {{- $cmd := list "bash" "-c" (printf "/usr/bin/curl -s -v -XPOST http://localhost:%s/actuator/receiveStatus/down && sleep 30") $port }}
  {{- $_ := set $deployment "command" (list "java") }}
  {{- $_ := set $deployment "args" (list "-jar" "/app/app.jar" (printf "--server.port=%s" $port)) }}
  {{- $_ := set $deployment "lifecycle" (dict "preStop" (dict "exec" (dict "command" $cmd))) }}
{{- else if eq .Values.type "node" }}
  {{- $_ := set $deployment "command" (list "npm") }}
  {{- $_ := set $deployment "args" (list "run" (printf "start:%s" $deployment.image.branch)) }}
{{- end }}
{{- end }}


{{- define "hook-nacos" -}}
{{- $deployment := .Values.data.deployment }}
{{- if eq .Values.type "java" }}
  {{- $instanceid := dict "fieldRef" (dict "apiVersion" "v1" "fieldPath" "metadata.name") }}
  {{- $_ := set $deployment.env "SPRING_CLOUD_NACOS_DISCOVERY_METADATA_BUILD_INSTANCEID" $instanceid }}
  {{- $imageName := $deployment.image.name }}
  {{- $_ := set $deployment.env "SPRING_CLOUD_NACOS_DISCOVERY_METADATA_BUILD_IMAGE" $imageName }}
  {{- if $deployment.env.APP_BUILDAT }}
    {{- $buildat := $deployment.env.APP_BUILDAT | date "2006-01-02 15:04:05.999999999Z07:00" }}
    {{- $_ := set $deployment.env "SPRING_CLOUD_NACOS_DISCOVERY_METADATA_BUILD_BUILDAT" $buildat }}
  {{- end }}
  {{- if $deployment.env.APP_COMMITID }}
    {{- $_ := set $deployment.env "SPRING_CLOUD_NACOS_DISCOVERY_METADATA_BUILD_COMMITID" $deployment.env.APP_COMMITID }}
  {{- end }}
{{- end }}
{{- end }}