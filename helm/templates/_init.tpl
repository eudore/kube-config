{{- define "init" -}}
{{- if not .Values.data }}
  {{- $env := dict "APP_NAME" $.Release.Name "APP_NAMESPACE" $.Release.Namespace "APP_INSTANCE" (dict "fieldRef" (dict "apiVersion" "v1" "fieldPath" "metadata.name")) }}
  {{- $deployment := dict "labels" dict "annotations" dict "podlabels" dict "podannotations" dict "replicas" 2 "historyLimit" 10 "strategy" (dict "type" "RollingUpdate" "rollingUpdate" (dict "maxSurge" "100%" "maxUnavailable" 0)) "image" (dict "policy" "IfNotPresent") "env" $env "ports" list}}
  {{- $service := dict "servicetype" "ClusterIP" "ports" list "labels" dict "annotations" dict }}
  {{- $ingress := dict "domain" "" "class" "nginx" "annotationsprefix" "nginx.ingress.kubernetes.io" "labels" dict "annotations" dict }}
  {{- $hpa := dict "min" 0 "max" 0 "metrics" list "labels" dict "annotations" dict }}
  {{- $pdb := dict "labels" dict "annotations" dict }}
  {{- $_ := set .Values "data" (dict "hooks" (default list .Values.hooks) "rules" list "message" list) }}
  {{- $_ := set .Values.data "deployment" (mergeOverwrite $deployment (default dict .Values.deployment)) }}
  {{- $_ := set .Values.data "service" (mergeOverwrite $service (default dict .Values.service)) }}
  {{- $_ := set .Values.data "ingress" (mergeOverwrite $ingress (default dict .Values.ingress)) }}
  {{- $_ := set .Values.data "hpa" (mergeOverwrite $hpa (default dict .Values.hpa)) }}
  {{- $_ := set .Values.data "pdb" (mergeOverwrite $pdb (default dict .Values.pdb)) }}

  {{- if hasKey .Values "rules" }}
    {{- $deployment = mergeOverwrite $deployment .Values.deployment }}
    {{- range $group := .Values.rules }}
      {{- $exp := (printf "^%s %s %s$" (coalesce $group.type $.Values.type) (coalesce $group.namespace $.Release.Namespace) (coalesce $group.name $.Release.Name))}}
      {{- $val := (printf "%s %s %s" $.Values.type $.Release.Namespace $.Release.Name)}}
      {{- $match := or (eq $exp (printf "^%s$" $val)) (ne "" (regexFind $exp $val)) }}
      {{- $_ := set $.Values.data "rules" (append $.Values.data.rules $match) }}
      {{- if $match }}
        {{- range $key := list "deployment" "service" "ingress" "hpa" "pdb" }}
          {{- if hasKey $group $key }}
            {{- $_ := set $.Values.data $key (mergeOverwrite (get $.Values.data $key) (get $group $key)) }}
          {{- end }}
        {{- end }}
        {{- if hasKey $group "hooks" }}
          {{- $_ := set $.Values.data "hooks" (concat $.Values.data.hooks $group.hooks) }}
        {{- end }}
      {{- end }}
    {{- end }}
    {{- $_ = unset $deployment "type" }}
    {{- $_ = unset $deployment "namespace" }}
    {{- $_ = unset $deployment "name" }}
  {{- end }}

  {{- $_ := include "init-deployment" . }}
  {{- $_ := include "init-service" . }}
  {{- $_ := include "init-ingress" . }}
  {{- $_ := include "init-hpa" . }}
  {{- $_ := include "init-pdb" . }}
  {{- range $hook := .Values.data.hooks }}
    {{- $_ = include (printf "hook-%s" $hook) $ }}
  {{- end }}
{{- end }}
{{- end }}

{{- define "init-deployment" -}}
{{- $deployment := .Values.data.deployment }}
{{/* init image name */}}
{{- if not $deployment.image.name }}
  {{- $branch := print (coalesce $deployment.image.branch "master") }}
  {{- $tag := print (coalesce $deployment.image.tag "latest") }}
  {{- $_ := set $deployment.image "name" (printf "%s-%s:%s" .Release.Name $branch $tag) }}
{{- end }}
{{/* init ports*/}}
{{- range $port := $deployment.ports }}
  {{- if not $port.protocol }}
    {{- $_ := set $port "protocol" "TCP" }}
  {{- end }}
  {{- if $port.port }}
    {{- $_ := set $port "containerPort" $port.port }}
    {{- $_ := unset $port "port" }}
  {{- end }}
  {{- if not $port.containerPort }}
    {{- $_ := set $.Values.data "message" (append $.Values.data.message "deployment: containerPort is empty") }}
    {{- set $deployment "ports" (without $deployment.ports $port) }}
  {{- end }}
{{- end }}
{{/* format buildat */}}
{{- if $deployment.env.APP_BUILDAT }}
  {{- $_ := set $deployment.env "APP_BUILDAT" ($deployment.env.APP_BUILDAT | date "2006-01-02 15:04:05.999999999Z07:00") }}
{{- end }}
{{/* init probe */}}
{{- if $deployment.probe }}
  {{- $_ := set $deployment "livenessProbe" (mergeOverwrite (default dict $deployment.livenessProbe) $deployment.probe) }}
  {{- $_ := set $deployment "readinessProbe" (mergeOverwrite (default dict $deployment.readinessProbe) $deployment.probe) }}
  {{- $_ := set $deployment "startupProbe" (mergeOverwrite (default dict $deployment.startupProbe) $deployment.probe) }}
  {{- $_ := unset $deployment "probe" }}
{{- end }}
{{/* mount configmaps */}}
{{/* if using --dry-run flag, lookup value is empty map */}}
{{- if and $deployment.config (lookup "v1" "ConfigMap" .Release.Namespace .Release.Name) }}
  {{- $_ := set $deployment "volumes" (append ($deployment.volumes | default list) (dict "name" "configmap" "configMap" (dict "name" .Release.Name)))}}
  {{- $_ := set $deployment "volumeMounts" (append ($deployment.volumeMounts | default list) (dict "name" "configmap" "mountPath" $deployment.config))}}
{{- end }}
{{- end }}

{{- define "init-service" -}}
{{/* merge data */}}
{{- $service := .Values.data.service }}
{{/* init port */}}
{{- $containerPorts := .Values.data.deployment.ports }}
{{- $hasPorts := list }}
{{- range $port := $containerPorts }}
  {{- $hasPorts = append $hasPorts (printf "%s-%v" $port.protocol $port.containerPort) }}
{{- end }}
{{- range $port := $service.ports }}
  {{- if not $port.protocol }}
    {{- $_ := set $port "protocol" "TCP" }}
  {{- end }}
  {{- if not $port.targetPort }}
    {{- $_ := set $port "targetPort" $port.port }}
  {{- end }}
  {{- if gt (int $port.nodePort) 1024 }}
    {{- $_ := set $service "servicetype" "NodePort"}}
  {{- end }}
  {{- if $port.port }}
    {{- if not (has (printf "%s-%v" $port.protocol $port.targetPort) $hasPorts) }}
      {{- $cport := dict "protocol" $port.protocol "containerPort" $port.targetPort}}
      {{- if $port.name }}
        {{- set $cport "name" $port.name }}
      {{- end }}
      {{- $containerPorts = append $containerPorts $cport }}
      {{- $_ := set $.Values.data.deployment "ports" $containerPorts }}
    {{- end }}
  {{- else }}
    {{- $_ := set $.Values.data "message" (append $.Values.data.message "service: port is empty") }}
    {{- set $service "ports" (without $service.ports $port) }}
  {{- end }}
{{- end }}
{{- $_ := set $service "enabled" (ne (len $service.ports) 0) }}
{{- if not $service.enabled }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "service: disabled by ports is nil") }}
{{- end }}
{{- end }}

{{- define "init-ingress" -}}
{{- $ingress := .Values.data.ingress }}
{{/* init domain*/}}
{{- range $key := list "domain" "tls" }}
  {{- $val := get $ingress $key}}
  {{- if kindIs "map" $val }}
    {{- $_ := set $ingress $key (get $val $.Release.Name)}}
  {{- else if kindIs "string" $val }}
    {{- $val = replace "${name}" $.Release.Name $val }}
    {{- $val = replace "${namespace}" $.Release.Namespace $val }}
    {{- $_ := set $ingress $key $val}}
  {{- end }}
{{- end }}
{{/* ing port */}}
{{- range $i, $port := .Values.data.service.ports }}
  {{- if or (eq $i 0) (eq (print $port.name) "http") }}
    {{- $_ := set $ingress "port" $port.port }}
  {{- end }}
{{- end }}
{{/* debug info */}}
{{- if $ingress.debug }}
  {{- $deployment := .Values.data.deployment }}
  {{- $prefix := printf "%s/configuration-snippet" $ingress.annotationsprefix }}
  {{- $snippet := get $ingress.annotations $prefix }}
  {{- if $deployment.env }}
    {{- if $deployment.env.APP_COMMITID }}
      {{- $snippet = printf "more_set_headers 'X-Build-Commitid: %s';\n%s" $deployment.env.APP_COMMITID $snippet }}
    {{- end }}
    {{- if $deployment.env.APP_BUILDAT }}
      {{- $snippet = printf "more_set_headers 'X-Build-At: %s';\n%s" $deployment.env.APP_BUILDAT $snippet }}
    {{- end }}
    {{- $snippet = printf "more_set_headers 'X-Build-Image: %s';\n%s" $deployment.image.name $snippet }}
  {{- end }}
  {{- $_ := set $ingress.annotations $prefix $snippet }}
{{- end }}
{{/* white list*/}}
{{- if $ingress.range }}
  {{- $_ := set $ingress.annotations (printf "%s/whitelist-source-range" $ingress.annotationsprefix) (join "," $ingress.range) }}
{{- end }}
{{- $_ := set $ingress "enabled" (ne $ingress.domain "") }}
{{- if not $ingress.enabled }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "ingress: disabled by domain is empty") }}
{{- end }}
{{- end }}

{{- define "init-hpa" -}}
{{- $hpa := .Values.data.hpa }}
{{/* init metric type */}}
{{- $val := printf "%s %s %s" (coalesce .Values.type "-") .Release.Namespace .Release.Name }}
{{- $kindmap := dict "Ingress" "networking.k8s.io/v1" "Deployment" "apps/v1"}}
{{- range $metric := $hpa.metrics }}
  {{- if and (hasKey $metric "name") (hasKey $metric "value") }}
    {{- if eq $metric.name "cpu" "memory "}}
      {{- if $metric.container }}
        {{- $_ := set $metric "type" "containerResource" }}
        {{- $_ := set $metric "container" (regexReplaceAll "(.*) (.*) (.*)" $val $metric.container) }}
      {{- else }}
        {{- $_ := set $metric "type" "resource" }}
      {{- end }}
      {{- $_ := set $metric "value" ($metric.value | trimPrefix "avg " ) }}
    {{- else if $metric.object }}
      {{- $name := regexReplaceAll "(.*) (.*) (.*)" $val (coalesce $metric.object.name "${3}") }}
      {{- $kind := coalesce $metric.object.kind "Pod" }}
      {{- $api := coalesce $metric.object.apiVersion (get $kindmap $kind) "v1" }}
      {{- $_ := set $metric "type" "object" }}
      {{- $_ := set $metric "object" (dict "apiVersion" $api "kind" $kind "name" $name )}}
      {{- $_ := set $metric "value" ($metric.value | trimSuffix "%" ) }}
    {{- else if $metric.external }}
      {{- $_ := set $metric "type" "external" }}
      {{- $_ := set $metric "value" ($metric.value | trimSuffix "%" ) }}
    {{- else }}
      {{- $_ := set $metric "type" "pods" }}
      {{- $_ := set $metric "value" ($metric.value | trimPrefix "avg " | trimSuffix "%" ) }}
    {{- end }}
    {{- $value := (regexFind "(\\d+)" $metric.value) | int }}
    {{- if le $value 0 }}
      {{- set $hpa "metrics" (without $hpa.metrics $metric) }}
      {{- $_ := set $.Values.data "message" (append $.Values.data.message "hpa: target value must be positive") }}
    {{- end }}
  {{- else }}
    {{- set $hpa "metrics" (without $hpa.metrics $metric) }}
    {{- $_ := set $.Values.data "message" (append $.Values.data.message "hpa: target metric must has key name/value") }}

  {{- end }}
{{- end }}
{{/* return */}}
{{- $_ := set $hpa "min" (int $hpa.min) -}}
{{- $_ := set $hpa "max" (int $hpa.max) -}}
{{- $_ := set $hpa "enabled" (and (gt $hpa.min 0) (gt $hpa.max 0) (lt $hpa.min $hpa.max) (ne (len $hpa.metrics) 0)) }}
{{- if and $hpa.enabled }}
  {{- $_ := unset .Values.data.deployment "replicas" }}
{{- else if eq (len $hpa.metrics) 0 }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "hpa: disabled by metrics is nil") }}
{{- else }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "hpa: disabled by min or max is invalid") }}
{{- end }}
{{- end }}

{{- define "init-pdb" -}}
{{- $pdb := .Values.data.pdb }}
{{- if and $pdb.min $pdb.max }}
  {{- $_ := set $pdb "enabled" false }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "pdb: disabled by minAvailable and maxUnavailable cannot be both set") }}
{{- else if and (not $pdb.min) (not $pdb.max) }}
  {{- $_ := set $pdb "enabled" false }}
  {{- $_ := set $.Values.data "message" (append $.Values.data.message "pdb: disabled by minAvailable and maxUnavailable cannot set") }}
{{- else }}
  {{- $_ := set $pdb "enabled" true }}
{{- end }}
{{- end }}