
`values.yaml`文件可以不存在，运行时使用`values.yaml`生成`calcValues`模板数据，在其他对象中引用`calcValues`数据生成yaml。

Default value如果为空字段不设置值时不会被使用，如果包含`Noset`字段为自动生成不可设置，如果值为`{{  }}`模板表达式当字段为空时将使用计算值。

| Name | Description | Type | Default value |
| ---- | ----------- | ---- | ----- |
| type | `rules`匹配时使用。 | String |  |
| debug | 执行`upgrade`命令输出计算参数。 | Bool | false |
| rules | 基于`type namespace name`参数匹配，将配置合并到基础参数上。 | Array | **Noset** |
| hooks | 调用模板`hook-$name`修改`.Values`对象值，需要调用的模板必须已定义。 | Array |  |
| data | 保存动态计算的参数。 | String | **Noset** |
| data.rules | 动态计算时规则匹配结果。 | Array | **Noset** |
| data.hooks | 所有执行的hook名称。 | Array | **Noset** |
| data.message | 动态计算时输出提示消息。 | Array | **Noset** |
| deployment.labels |  | Map |  |
| deployment.annotations |  | Map |  |
| deployment.replicas | 副本数量，如果`hpa.enabled == true`自动移除`replicas`字段。 | Number | 2 |
| deployment.historyLimit | 保留历史版本数量。 | Number | 10 |
| deployment.strategy |  | Map | `    type: RollingUpdate<br>rollingUpdate:<br>  maxSurge: "100%"<br>  maxUnavailable: 0` |
| deployment.podlabels | pod使用的`labels`。 | Map |  |
| deployment.podannotations | pod使用的`annotations`。 | Map |  |
| deployment.image.repository | 容器镜像仓库地址。 | String |  |
| deployment.image.name | 容器镜像名称，如果为空根据名称生成。 | String | {{ printf %s-%s:%s .Release.Name image.branch image.tag }} |
| deployment.image.branch |  | String | master |
| deployment.image.tag |  | String | latest |
| deployment.image.policy |  | String | IfNotPresent |
| deployment.image.secrets |  | Array |  |
| deployment.command |  | Array |  |
| deployment.args |  | Array |  | 
| deployment.lifecycle |  | Map |  | 
| deployment.probe | 定义三种探针的基本配置参数。 | Map |  | 
| deployment.livenessProbe |  | Map |  | 
| deployment.readinessProbe |  | Map |  | 
| deployment.startupProbe |  | Map |  |
| deployment.ports | `Pod`定义端口，如果`service.enabled == true`生成yaml时自动添加`service.ports`。| Array |  |
| deployment.ports.[].protocol |  | String | TCP |
| deployment.ports.[].name |  | String |  |
| deployment.ports.[].port |  | Number |  |
| deployment.env |  | Map | `APP_NAME APP_NAMESPACE APP_INSTANCE` |
| deployment.resources |  | Map |  |
| deployment.config |  如果存在与`Release.Name`相同的`v1/ConfigMap`，将其挂载到指定路径。 | String |  |
| deployment.volumeMounts |  | Array |  |
| deployment.volumes |  | Array |  |
| service.enabled | 如果值为`true`会创建`v1/Service`对象，也会影响`ingress deployment`对象生成。 | Bool | **Noset** {{ service.port != 0 }} |
| service.labels |  | Map |  |
| service.annotations |  | Map |  |
| service.servicetype | 如果存在`nodeport`时值变为`NodePort`。 | String | **Noset** ClusterIP |
| service.ports | 如果声明端口不在`deployment.ports`时将自动追加。 | Array |  |
| service.ports.[].protocol |  | String |  TCP |
| service.ports.[].name |  |  String |  |
| service.ports.[].port |  | Number  |   |
| service.ports.[].targetPort |  | Number  | {{ $service.port }}  |
| service.ports.[].nodeport |  |  String |  |
| ingress.enabled | 如果值为`true`、`service.enabled == true`、`KubeVersion >= 1.19`会创建`networking.k8s.io/v1/Ingress`对象。 | Bool | **Noset** {{ ingress.domain != "" }} |
| ingress.labels |  | Map |  |
| ingress.annotations |  | Map |  |
| ingress.port | service第一个端口或满足`name == http`的端口。 | String | **Noset** |
| ingress.class |  | String | nginx |
| ingress.annotationsprefix | `ingress-nginx`默认使用的`annotations`前缀。 | String | nginx.ingress.kubernetes.io |
| ingress.debug | 如果为`true`将在响应Headers里面设置`X-Build-Commitid X-Build-At X-Build-Image`显示当前版本信息。 | Bool | false |
| ingress.range | 定义ingress`whitelist-source-range`白名单，值为ip段。 | Array |  |
| ingress.domain | 定义域名，如果类型为Map将获取`.Release.Name`映射域名，如果类型为字符串可以使用变量`${name} ${namespace}`。 | String |  |
| ingress.tls | 定义TLS使用的secrets名称，规则与domain一致。 | String |  |
| hpa.enabled | 如果值为`true`、`KubeVersion >= 1.23`会创建`autoscaling/v2/HorizontalPodAutoscaler`对象。 | Bool | **Noset** {{ min>0 && max>0 && hpa.metrics != nil }} |
| hpa.labels |  | Map |  |
| hpa.annotations |  | Map |  |
| hpa.min |  | Number | 0 |
| hpa.max |  | Number | 0 |
| hpa.up |  | Map |  |
| hpa.down |  | Map |  |
| hpa.up/down.select |  | String | Max |
| hpa.up/down.values |  | Array |  |
| hpa.up/down.window |  | Number |  |
| hpa.metrics | 定义简易hpa规则。 | Array |  |
| hpa.metrics.[].name |  定义metrics规则名称，metrcis类型默认为`pods`，如果`name`为`cpu memory`时metrcis类型为`resource`。 | String | **必要** |
| hpa.metrics.[].value | 定义指标值，可以使用`Number`、`avg Number`、`Number%`格式定义数值、平均值、比例值。 | String | **必要** |
| hpa.metrics.[].container | 如果`name`为`cpu memory`时指定容器名称，metrcis类型为`containerResource`。 | String |  |
| hpa.metrics.[].object | 设置metrcis类型为`object`。 | Map |  |
| hpa.metrics.[].object.name |  | String | {{ metrics.name or Release.Name }} |
| hpa.metrics.[].object.kind |  | String | Pod |
| hpa.metrics.[].object.apiVersion |  | String | v1 |
| hpa.metrics.[].external | 设置metrcis类型为`external`。 | Bool |  |
| pdb.enabled | 如果值为`true`、`KubeVersion >= 1.21`会创建`policy/v1/PodDisruptionBudget`对象。 | Bool | **Noset** {{ min>0 or max>0 }} |
| pdb.labels |  | Map |  |
| pdb.annotations |  | Map |  |
| pdb.min |  | Number | 0 |
| pdb.max |  | Number | 0 |
| pdb.policy | 如果`KubeVersion >= 1.26`时使用该配置。 | String |  |


Values example:

```yaml
deployment:
  replicas: 2
  historyLimit: 4
  config: /app/config
  podannotations:
    prometheus.io/scrape: 'true'
    prometheus.io/port: '8080'
    prometheus.io/path: '/metrics'
  strategy: 
    type: RollingUpdate
    rollingUpdate:
      maxSurge: "100%"
      maxUnavailable: 0
  image:
    repository: registry.cn-shanghai.aliyuncs.com/eudore/
    name: ''
    branch: master
    tag: latest
    policy: IfNotPresent
    secrets: 
    - name: registry-aliyun
  env:
    APP_BUILDAT: 2023年3月31日
    APP_COMMITID: 2706c6cbff9a59511ef74b44701b5e402c8b93e2
    TZ: Asia/Shanghai
  resources:
    limits: 
      cpu: 10m
      memory: 32Mi
  livenessProbe:
    httpGet:
      port: http
      path: /healthy
    initialDelaySeconds: 3
    periodSeconds: 10
    timeoutSeconds: 1
    successThreshold: 1
  volumeMounts: 
  - mountPath: /logs
    name: host-logs
  volumes:
  - name: host-logs
    hostPath:
      path: /logs
      type: ""
  customPod:
    restartPolicy: Always
    enableServiceLinks: false
    automountServiceAccountToken: false
service:
  ports:
  - protocol: TCP
    port: 8080
    name: http
    nodeport: 30000
  annotations:
    prometheus.io/probe: 'true'
    prometheus.io/http-path: '/healthy'
ingress:
  domain: ${name}.local.eudore.cn
  tls: tls-${name}
  debug: true
  range:
  - 172.18.0.0/16
  class: nginx
  annotationsprefix: nginx.ingress
  annotations:
    nginx.ingress/hsts: 'false'
    nginx.ingress/hsts-max-age: "600" 
    nginx.ingress/ssl-redirect: 'false'
    nginx.ingress/configuration-snippet: |
      more_set_headers 'Cache-Control: no-cache';
    prometheus.io/probe: 'true'
    prometheus.io/path: '/healthy'
hpa:
  min: 2
  max: 8
  up:
    values: [4 15, 50% 15]
  down:
    window: 300
  metrics: 
  - name: cpu
    value: 40%
```