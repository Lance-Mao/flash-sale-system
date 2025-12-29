# CI/CD 实施详细指南

本指南提供 CI/CD 从零到一的详细实施步骤。

## 📋 前置条件检查

### 必需工具
```bash
# 检查 Docker
docker --version  # >= 20.10

# 检查 kubectl
kubectl version --client  # >= 1.25

# 检查 Helm
helm version  # >= 3.14

# 检查 Go
go version  # >= 1.22

# 检查 Make
make --version  # >= 4.0
```

### 必需账号
- [ ] GitHub/GitLab 账号
- [ ] 容器镜像仓库（Harbor/Docker Hub/云服务）
- [ ] Kubernetes 集群访问权限
- [ ] 钉钉/企微机器人（可选）

## 🚀 阶段一：Git 仓库配置

### 1.1 推送代码到远程仓库

```bash
# 如果还没有远程仓库
git remote add origin https://github.com/Lance-Mao/flash-sale-system.git

# 推送代码
git add .
git commit -m "feat: initial commit with CI/CD configuration"
git push -u origin main
```

### 1.2 配置分支保护规则

**GitHub 设置路径**: Settings → Branches → Branch protection rules

```yaml
保护分支: main
规则:
  ✅ Require pull request reviews before merging
  ✅ Require status checks to pass before merging
     - lint-and-test
     - build-images
  ✅ Require branches to be up to date before merging
  ✅ Include administrators
```

### 1.3 配置 GitHub Secrets

**GitHub 设置路径**: Settings → Secrets and variables → Actions

```yaml
必需的 Secrets:
  HARBOR_USERNAME: harbor 用户名
  HARBOR_PASSWORD: harbor 密码
  KUBE_CONFIG_DEV: 开发环境 kubeconfig (base64 编码)
  KUBE_CONFIG_PROD: 生产环境 kubeconfig (base64 编码)
  DINGTALK_TOKEN: 钉钉机器人 webhook token

可选的 Secrets:
  SONAR_TOKEN: SonarQube token
  SONAR_HOST_URL: SonarQube 地址
```

**获取 kubeconfig base64 编码**:
```bash
# Linux/Mac
cat ~/.kube/config | base64 -w 0

# Windows PowerShell
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $env:USERPROFILE\.kube\config -Raw)))
```

## 🐳 阶段二：容器镜像仓库

### 2.1 选项 A: 部署 Harbor（推荐生产环境）

```bash
# 使用 Helm 部署 Harbor
helm repo add harbor https://helm.goharbor.io
helm repo update

helm install harbor harbor/harbor \
  --namespace harbor \
  --create-namespace \
  --set expose.type=nodePort \
  --set expose.tls.enabled=false \
  --set externalURL=http://harbor.example.com \
  --set harborAdminPassword=Harbor12345

# 等待部署完成
kubectl wait --for=condition=ready pod -l app=harbor -n harbor --timeout=300s

# 获取访问地址
kubectl get svc -n harbor
```

**Harbor 初始化配置**:
1. 访问 Harbor UI（用户名: admin）
2. 创建项目: `flashsale`
3. 创建机器人账号: Settings → Robot Accounts
4. 配置镜像扫描策略

### 2.2 选项 B: 使用 Docker Hub

```bash
# 登录 Docker Hub
docker login

# 修改 CI/CD 配置
# .github/workflows/ci-cd.yml 中的 REGISTRY 改为: docker.io/Lance-Mao
```

### 2.3 选项 C: 使用云服务

**阿里云 ACR**:
```bash
# 登录阿里云镜像仓库
docker login --username=your-username registry.cn-hangzhou.aliyuncs.com

# 修改 CI/CD 配置
# REGISTRY: registry.cn-hangzhou.aliyuncs.com/Lance-Mao
```

**AWS ECR / Azure ACR / Google GCR** 类似配置

## ☸️ 阶段三：Kubernetes 集群准备

### 3.1 选项 A: 本地开发（Minikube）

```bash
# 安装 Minikube
# Windows: choco install minikube
# Mac: brew install minikube
# Linux: 参考官网

# 启动集群
minikube start --cpus=4 --memory=8192 --driver=docker

# 启用 Ingress
minikube addons enable ingress

# 获取 kubeconfig
kubectl config view --raw
```

### 3.2 选项 B: 云服务（推荐）

**阿里云 ACK**:
```bash
# 在控制台创建集群后，下载 kubeconfig
# 设置环境变量
export KUBECONFIG=/path/to/kubeconfig
kubectl get nodes
```

**AWS EKS / Azure AKS / Google GKE** 类似

### 3.3 集群基础组件安装

```bash
# 1. 安装 Nginx Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

# 2. 安装 Cert-Manager (HTTPS 证书)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 3. 安装 Prometheus Operator (监控)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# 4. 创建应用命名空间
kubectl create namespace flashsale-dev
kubectl create namespace flashsale-prod
```

### 3.4 配置镜像拉取凭证

```bash
# 创建 Docker registry secret
kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.example.com \
  --docker-username=robot$flashsale \
  --docker-password=your-token \
  --namespace=flashsale-dev

kubectl create secret docker-registry harbor-secret \
  --docker-server=harbor.example.com \
  --docker-username=robot$flashsale \
  --docker-password=your-token \
  --namespace=flashsale-prod
```
 
## 🎯 阶段四：部署基础设施

### 4.1 部署 MySQL

```bash
# 选项 A: 使用 StatefulSet（生产推荐）
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: flashsale-dev
data:
  my.cnf: |
    [mysqld]
    max_connections=500
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
---
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: flashsale-dev
type: Opaque
stringData:
  root-password: PXDN93VRKUm8TeE7
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: flashsale-dev
spec:
  ports:
  - port: 3306
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: flashsale-dev
spec:
  serviceName: mysql
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0.28
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-secret
              key: root-password
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
        - name: config
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: config
        configMap:
          name: mysql-config
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 20Gi
EOF
```

```bash
# 选项 B: 使用云服务（推荐生产）
# RDS（阿里云）/ RDS（AWS）/ Cloud SQL（Google）
# 直接在配置中使用云服务地址
```

### 4.2 部署 Redis

```bash
# 使用 Helm 部署 Redis Cluster
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install redis bitnami/redis \
  --namespace flashsale-dev \
  --set auth.password=G62m50oigInC30sf \
  --set master.persistence.size=10Gi \
  --set replica.replicaCount=2
```

### 4.3 部署 Kafka

```bash
# 使用 Strimzi Operator 部署 Kafka
kubectl create namespace kafka
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# 创建 Kafka 集群
cat <<EOF | kubectl apply -f -
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka
  namespace: flashsale-dev
spec:
  kafka:
    version: 3.9.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
    storage:
      type: persistent-claim
      size: 10Gi
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF
```

### 4.4 初始化数据库

```bash
# 端口转发到本地
kubectl port-forward -n flashsale-dev svc/mysql 3306:3306 &

# 导入 SQL
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql
```

## 📦 阶段五：首次部署应用

### 5.1 修改 Helm values

编辑 `deploy/helm/values-dev.yaml`:

```yaml
# 修改镜像仓库地址
image:
  registry: harbor.example.com  # 改为你的实际地址
  prefix: flashsale

# 修改域名
ingress:
  hosts:
    - host: dev-api.yourdomain.com  # 改为你的域名
```

### 5.2 手动构建第一个镜像

```bash
# 构建镜像（以 usercenter-api 为例）
docker build -f deploy/dockerfile/usercenter-api/Dockerfile \
  -t harbor.example.com/flashsale/usercenter-api:v0.1.0 .

# 推送镜像
docker push harbor.example.com/flashsale/usercenter-api:v0.1.0

# 重复其他服务...
# 或者使用 Makefile
make docker-build docker-push
```

### 5.3 使用 Helm 部署

```bash
# 部署到开发环境
helm upgrade --install flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --create-namespace \
  --set image.tag=v0.1.0 \
  --values ./deploy/helm/values-dev.yaml \
  --wait --timeout 5m

# 查看部署状态
kubectl get pods -n flashsale-dev
kubectl get svc -n flashsale-dev
kubectl get ingress -n flashsale-dev
```

### 5.4 验证部署

```bash
# 检查 Pod 状态
kubectl get pods -n flashsale-dev

# 查看日志
kubectl logs -f deployment/usercenter-api -n flashsale-dev

# 端口转发测试
kubectl port-forward -n flashsale-dev svc/usercenter-api 1004:1004

# 测试健康检查
curl http://localhost:1004/healthz

# 测试 API（如果已配置 Ingress）
curl http://dev-api.yourdomain.com/usercenter/v1/user/login \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456"}'
```

## 🔄 阶段六：触发 CI/CD

### 6.1 第一次 CI 构建

```bash
# 创建功能分支
git checkout -b feature/test-ci

# 修改代码（任意修改）
echo "# Test CI" >> README.md

# 提交并推送
git add .
git commit -m "feat: test CI pipeline"
git push origin feature/test-ci
```

### 6.2 创建 Pull Request

1. 在 GitHub 上创建 PR: `feature/test-ci` → `main`
2. 观察 CI 流程自动运行:
   - ✅ lint-and-test
   - ✅ build-images
3. 如果失败，查看日志并修复
4. 合并 PR

### 6.3 自动部署到 dev

```bash
# 合并到 main 后，自动触发部署
git checkout main
git pull

# 查看 GitHub Actions 运行状态
# Actions → CI/CD Pipeline → 最新运行

# 查看 K8s 中的更新
kubectl get pods -n flashsale-dev -w
```

### 6.4 生产环境发布

```bash
# 打 tag 触发生产部署
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# 在 GitHub 手动审批部署
# Actions → CI/CD Pipeline → deploy-prod → Review deployments → Approve

# 监控部署
kubectl get pods -n flashsale-prod -w
```

## 🔍 阶段七：监控和告警

### 7.1 访问 Prometheus

```bash
# 端口转发
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# 浏览器访问: http://localhost:9090
```

### 7.2 访问 Grafana

```bash
# 获取密码
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# 端口转发
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 浏览器访问: http://localhost:3000
# 用户名: admin
```

### 7.3 配置钉钉告警

编辑 AlertManager 配置:

```yaml
kubectl edit configmap -n monitoring prometheus-kube-prometheus-alertmanager

# 添加 webhook 配置
receivers:
- name: 'dingtalk'
  webhook_configs:
  - url: 'http://your-dingtalk-webhook-proxy/webhook'
    send_resolved: true
```

## ✅ 验收清单

### 最终检查

- [ ] CI 流程能自动运行（lint + test + build）
- [ ] 代码提交后自动构建镜像
- [ ] 镜像推送到 Harbor 成功
- [ ] main 分支自动部署到 dev 环境
- [ ] tag 触发生产部署（需审批）
- [ ] Pod 健康检查正常
- [ ] Ingress 域名可访问
- [ ] Prometheus 能抓取指标
- [ ] Grafana 能查看监控
- [ ] 钉钉通知正常

### 性能测试

```bash
# 简单压测
ab -n 1000 -c 10 http://dev-api.yourdomain.com/usercenter/v1/user/ping

# 或使用 k6
k6 run load-test.js
```

## 🐛 常见问题

### 问题 1: ImagePullBackOff

```bash
# 检查 Secret
kubectl get secret harbor-secret -n flashsale-dev -o yaml

# 重新创建 Secret
kubectl delete secret harbor-secret -n flashsale-dev
kubectl create secret docker-registry harbor-secret ...
```

### 问题 2: Pod CrashLoopBackOff

```bash
# 查看日志
kubectl logs -f pod-name -n flashsale-dev

# 查看事件
kubectl describe pod pod-name -n flashsale-dev

# 常见原因: 数据库连接失败、配置错误
```

### 问题 3: Ingress 无法访问

```bash
# 检查 Ingress
kubectl get ingress -n flashsale-dev
kubectl describe ingress flashsale -n flashsale-dev

# 检查 Ingress Controller
kubectl get pods -n ingress-nginx

# 如果是本地 Minikube
minikube service list
```

### 问题 4: CI 构建失败

```bash
# 本地测试 lint
make lint

# 本地测试构建
make build

# 本地测试 Docker 构建
docker build -f deploy/dockerfile/usercenter-api/Dockerfile .
```

## 📚 下一步

完成以上步骤后，你的 CI/CD 流程已经就绪！

接下来可以：
1. 阅读 `FEATURE_ROADMAP.md` 了解功能扩展计划
2. 添加更多测试用例
3. 配置灰度发布（Flagger）
4. 集成更多监控指标

## 🎉 恭喜

你已经成功搭建了一个企业级的 CI/CD 流程！
