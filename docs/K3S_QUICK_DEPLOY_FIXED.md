# K3s 轻量部署指南（完整版）

## 概述

K3s 是轻量级 Kubernetes，资源占用低、安装简单，非常适合中小型项目。

**特点**：
- 单文件二进制，安装包 < 100MB
- 内存占用 < 512MB（vs 标准K8s 4GB+）
- 一条命令完成安装
- 100% 兼容 K8s API

**部署时间估算**：
- K3s 安装: 5分钟
- 基础组件: 10分钟
- 基础设施: 20分钟
- 应用部署: 10分钟
- **总计: 约45-60分钟**

---

## 一、服务器准备

### 1.1 服务器要求

**最小配置（单节点测试）**：
```
CPU: 2核
内存: 4GB（注意：比原文档增加了2GB，因为需要运行更多服务）
硬盘: 30GB
系统: Ubuntu 20.04/22.04、CentOS 7/8、Debian
```

**推荐配置（生产环境）**：
```
CPU: 4核
内存: 8GB
硬盘: 50GB SSD
网络: 10Mbps+
```

### 1.2 资源需求明细

| 组件 | 内存 | CPU | 存储 |
|------|------|-----|------|
| K3s 自身 | 512MB | 0.5核 | 1GB |
| MySQL | 1GB | 0.5核 | 10GB |
| Redis | 512MB | 0.2核 | 5GB |
| Kafka + Zookeeper | 3GB | 0.8核 | 7GB |
| 应用服务 (11个) | 2GB | 2核 | 2GB |
| Nginx Ingress | 256MB | 0.2核 | - |
| 监控 (可选) | 2GB | 0.8核 | 10GB |
| **总计** | **~10GB** | **~5核** | **~35GB** |

### 1.3 系统准备（必做）

```bash
# SSH 登录到服务器后执行

# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 安装必要工具
sudo apt install -y curl wget git vim net-tools

# 3. 关闭 swap（K8s 要求）
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# 4. 配置防火墙
# 方式1: 关闭防火墙（仅测试环境）
sudo ufw disable

# 方式2: 开放必要端口（推荐）
sudo ufw allow 6443/tcp   # K8s API
sudo ufw allow 80/tcp     # HTTP
sudo ufw allow 443/tcp    # HTTPS
sudo ufw allow 10250/tcp  # Kubelet
sudo ufw enable

# 5. 配置主机名（可选，但推荐）
sudo hostnamectl set-hostname k3s-master

# 6. 验证资源
free -h  # 检查内存
df -h    # 检查磁盘
nproc    # 检查CPU核心数
```

---

## 二、安装 K3s（5分钟）

### 2.1 单节点安装（推荐）

```bash
# 一键安装（国内镜像加速）
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  INSTALL_K3S_VERSION=v1.28.5+k3s1 \
  sh -s - server \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --disable servicelb

# 说明:
# --write-kubeconfig-mode 644: 允许普通用户访问 kubectl
# --disable traefik: 禁用默认 Ingress（我们用 Nginx Ingress）
# --disable servicelb: 禁用默认 LoadBalancer
```

**安装过程**：
```
[INFO]  Finding release for channel stable
[INFO]  Using v1.28.5+k3s1 as release
[INFO]  Downloading...
[INFO]  systemd: Starting k3s
```

### 2.2 验证安装

```bash
# 等待30秒，让 K3s 完全启动
sleep 30

# 查看集群状态
kubectl get nodes

# 预期输出:
# NAME         STATUS   ROLES                  AGE   VERSION
# k3s-master   Ready    control-plane,master   1m    v1.28.5+k3s1

# 查看系统 Pod
kubectl get pods -A

# 预期所有 Pod 都是 Running 状态
```

### 2.3 配置远程访问（重要）

```bash
# === 在服务器上执行 ===

# 1. 查看 kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml

# 2. 复制输出内容
```

```bash
# === 在本地电脑执行 ===

# Windows PowerShell:
mkdir -p $env:USERPROFILE\.kube
notepad $env:USERPROFILE\.kube\config-k3s

# macOS/Linux:
mkdir -p ~/.kube
nano ~/.kube/config-k3s

# 粘贴上面复制的内容，并修改第 5 行:
# 原内容: server: https://127.0.0.1:6443
# 改为:   server: https://你的服务器公网IP:6443

# 保存文件
```

```bash
# 测试远程连接
export KUBECONFIG=~/.kube/config-k3s  # Linux/macOS
$env:KUBECONFIG="$env:USERPROFILE\.kube\config-k3s"  # Windows PowerShell

kubectl get nodes

# 如果看到节点信息，说明连接成功！
```

---

## 三、安装基础组件（10分钟）

### 3.1 安装 Nginx Ingress

```bash
# 安装
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

# 等待部署完成
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# 查看服务
kubectl get svc -n ingress-nginx

# 如果是 NodePort，记录端口号（通常是 80:3xxxx 和 443:3xxxx）
```

### 3.2 安装 Helm

```bash
# 安装 Helm（包管理工具）
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证
helm version

# 预期输出: version.BuildInfo{Version:"v3.x.x", ...}
```

### 3.3 创建命名空间

```bash
# 创建应用命名空间
kubectl create namespace flashsale-dev
kubectl create namespace flashsale-prod
kubectl create namespace infra

# 添加标签便于管理
kubectl label namespace flashsale-dev environment=dev
kubectl label namespace flashsale-prod environment=prod
kubectl label namespace infra tier=infrastructure

# 验证
kubectl get namespaces --show-labels
```

---

## 四、部署基础设施（20分钟）

### 4.1 部署 MySQL

```bash
# 创建部署文件
cat > /tmp/mysql-k3s.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
  namespace: infra
type: Opaque
stringData:
  root-password: PXDN93VRKUm8TeE7
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-pvc
  namespace: infra
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path  # K3s 默认存储类
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: infra
spec:
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
        - name: TZ
          value: Asia/Shanghai
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: mysql-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: infra
spec:
  selector:
    app: mysql
  ports:
  - port: 3306
    targetPort: 3306
  type: ClusterIP
EOF

# 部署
kubectl apply -f /tmp/mysql-k3s.yaml

# 验证（等待30秒）
kubectl get pods -n infra -w
# 按 Ctrl+C 停止监控

# 测试连接
kubectl exec -it deploy/mysql -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7 -e "SELECT VERSION();"
```

### 4.2 部署 Redis

```bash
# 使用 Helm 部署
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm install redis bitnami/redis \
  --namespace infra \
  --set auth.password=G62m50oigInC30sf \
  --set master.persistence.size=5Gi \
  --set replica.replicaCount=1 \
  --set master.resources.requests.memory=256Mi \
  --set master.resources.requests.cpu=100m \
  --set master.resources.limits.memory=512Mi \
  --set master.resources.limits.cpu=500m

# 等待部署（约2分钟）
kubectl get pods -n infra -l app.kubernetes.io/name=redis -w
# 按 Ctrl+C 停止

# 测试连接
kubectl exec -it redis-master-0 -n infra -- redis-cli -a G62m50oigInC30sf PING
# 输出: PONG
```

### 4.3 部署 Kafka

```bash
# 安装 Strimzi Operator
kubectl create namespace kafka
kubectl apply -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# 等待 Operator 就绪
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s

# 部署 Kafka 集群（单节点轻量版）
cat > /tmp/kafka-k3s.yaml <<'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: flashsale-kafka
  namespace: infra
spec:
  kafka:
    version: 3.6.1
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
    storage:
      type: persistent-claim
      size: 5Gi
    resources:
      requests:
        memory: 1Gi
        cpu: 250m
      limits:
        memory: 2Gi
        cpu: 500m
  zookeeper:
    replicas: 1
    storage:
      type: persistent-claim
      size: 2Gi
    resources:
      requests:
        memory: 512Mi
        cpu: 100m
      limits:
        memory: 1Gi
        cpu: 250m
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF

kubectl apply -f /tmp/kafka-k3s.yaml

# 等待部署（约3-5分钟）
echo "等待 Kafka 集群就绪，这可能需要 3-5 分钟..."
kubectl wait kafka/flashsale-kafka --for=condition=Ready --timeout=600s -n infra

# 验证
kubectl get kafka -n infra
kubectl get pods -n infra -l strimzi.io/cluster=flashsale-kafka
```

### 4.4 创建 Kafka Topics（重要！新增步骤）

```bash
# 等待 Kafka 完全就绪
sleep 30

# 创建临时客户端 Pod
cat > /tmp/kafka-topics.yaml <<'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: payment-update
  namespace: infra
  labels:
    strimzi.io/cluster: flashsale-kafka
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000  # 7天
    segment.bytes: 1073741824
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: order-update
  namespace: infra
  labels:
    strimzi.io/cluster: flashsale-kafka
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000  # 7天
    segment.bytes: 1073741824
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: pay-callback
  namespace: infra
  labels:
    strimzi.io/cluster: flashsale-kafka
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000
---
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: close-order
  namespace: infra
  labels:
    strimzi.io/cluster: flashsale-kafka
spec:
  partitions: 3
  replicas: 1
  config:
    retention.ms: 604800000
EOF

kubectl apply -f /tmp/kafka-topics.yaml

# 验证 Topic 创建
kubectl get kafkatopics -n infra

# 预期输出:
# NAME             CLUSTER           PARTITIONS   REPLICATION FACTOR   READY
# payment-update   flashsale-kafka   3            1                    True
# order-update     flashsale-kafka   3            1                    True
# pay-callback     flashsale-kafka   3            1                    True
# close-order      flashsale-kafka   3            1                    True
```

### 4.5 初始化数据库（重要！修复版）

```bash
# === 第一步：创建数据库 ===
kubectl exec -it deploy/mysql -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7 <<'EOF'
CREATE DATABASE IF NOT EXISTS flashsale_usercenter DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_order DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_payment DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE DATABASE IF NOT EXISTS flashsale_product DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
SHOW DATABASES;
EOF

# 预期输出应该包含上面4个数据库

# === 第二步：端口转发（在新终端） ===
kubectl port-forward -n infra svc/mysql 3306:3306 &
PF_PID=$!

# 等待端口转发就绪
sleep 3

# === 第三步：导入表结构（在项目根目录执行） ===
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 flashsale_usercenter < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 flashsale_order < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 flashsale_payment < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 flashsale_product < deploy/sql/flashsale_product.sql

# === 第四步：验证 ===
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 -e "
USE flashsale_usercenter; SHOW TABLES;
USE flashsale_order; SHOW TABLES;
USE flashsale_payment; SHOW TABLES;
USE flashsale_product; SHOW TABLES;
"

# === 第五步：停止端口转发 ===
kill $PF_PID  # Linux/macOS
# Windows: 在任务管理器中结束 kubectl 进程
```

### 4.6 验证基础设施（新增）

```bash
# 检查所有基础设施 Pod 状态
kubectl get pods -n infra

# 预期输出（所有 Pod 都是 Running）:
# NAME                                          READY   STATUS    RESTARTS   AGE
# mysql-xxxxx                                   1/1     Running   0          5m
# redis-master-0                                1/1     Running   0          4m
# flashsale-kafka-kafka-0                       1/1     Running   0          3m
# flashsale-kafka-zookeeper-0                   1/1     Running   0          3m
# flashsale-kafka-entity-operator-xxxxx         2/2     Running   0          2m

# 检查存储
kubectl get pvc -n infra

# 检查服务
kubectl get svc -n infra

# 检查资源使用
kubectl top pods -n infra
kubectl top nodes
```

---

## 五、准备应用配置（重要！新增章节）

### 5.1 更新 Helm Values 配置

编辑 `deploy/helm/values-dev.yaml`，添加完整配置：

```bash
# 备份原文件
cp deploy/helm/values-dev.yaml deploy/helm/values-dev.yaml.bak

# 编辑配置
cat > deploy/helm/values-dev.yaml <<'EOF'
# 开发环境配置
replicaCount: 1

env: dev

image:
  tag: "main-latest"

resources:
  api:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  rpc:
    limits:
      cpu: 500m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi
  mq:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 20m
      memory: 32Mi

autoscaling:
  enabled: false

serviceMonitor:
  enabled: false

ingress:
  hosts:
    - host: dev-api.flashsale.com
      paths:
        - path: /usercenter
          pathType: Prefix
          service: usercenter-api
        - path: /product
          pathType: Prefix
          service: travel-api  # 注意: travel 是 product 的别名
        - path: /order
          pathType: Prefix
          service: order-api
        - path: /payment
          pathType: Prefix
          service: payment-api
  tls:
    - secretName: flashsale-dev-tls
      hosts:
        - dev-api.flashsale.com

# 【重要】完整配置
config:
  mysql:
    host: mysql.infra.svc.cluster.local
    port: 3306
    username: root
    password: PXDN93VRKUm8TeE7
  redis:
    host: redis-master.infra.svc.cluster.local
    port: 6379
    password: G62m50oigInC30sf
  kafka:
    brokers: flashsale-kafka-kafka-bootstrap.infra.svc.cluster.local:9092
  jwt:
    secret: your-jwt-secret-change-this-in-production
  logLevel: info
  logMode: console

# Asynq 配置（延迟队列）
asynq:
  redis:
    addr: redis-master.infra.svc.cluster.local:6379
    password: G62m50oigInC30sf
    db: 0
EOF

echo "配置文件已更新！"
```

### 5.2 生成 JWT Secret（重要）

```bash
# 生成随机 JWT secret
JWT_SECRET=$(openssl rand -base64 32)
echo "生成的 JWT Secret: $JWT_SECRET"

# 更新到 values-dev.yaml
sed -i "s|your-jwt-secret-change-this-in-production|$JWT_SECRET|g" deploy/helm/values-dev.yaml

# 验证
grep "jwt:" deploy/helm/values-dev.yaml -A 1
```

### 5.3 配置域名访问（可选但推荐）

**方式1: 配置 hosts 文件（测试用）**

```bash
# 获取服务器 IP
SERVER_IP=$(curl -s ifconfig.me)
echo "服务器公网 IP: $SERVER_IP"

# 在本地电脑添加 hosts 记录
# Windows: C:\Windows\System32\drivers\etc\hosts
# Linux/Mac: /etc/hosts
# 添加一行:
# <SERVER_IP> dev-api.flashsale.com

# Linux/Mac 快速添加:
echo "$SERVER_IP dev-api.flashsale.com" | sudo tee -a /etc/hosts

# Windows PowerShell (管理员):
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "$SERVER_IP dev-api.flashsale.com"
```

**方式2: 使用真实域名（生产环境）**

```bash
# 1. 在域名服务商添加 A 记录
#    主机记录: dev-api
#    记录类型: A
#    记录值: <服务器公网IP>
#    TTL: 600

# 2. 验证 DNS 解析
nslookup dev-api.flashsale.com

# 3. 配置 SSL 证书（使用 cert-manager）
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.3/cert-manager.yaml

# 等待 cert-manager 就绪
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

# 创建 Let's Encrypt Issuer
cat > /tmp/letsencrypt-issuer.yaml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com  # 修改为你的邮箱
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

kubectl apply -f /tmp/letsencrypt-issuer.yaml
```

---

## 六、CI/CD 集成

### 6.1 配置镜像拉取凭证

```bash
# 创建 Docker Hub Secret（开发环境）
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=你的DockerHub用户名 \
  --docker-password=你的DockerHub密码或Token \
  --namespace=flashsale-dev

# 创建 Docker Hub Secret（生产环境）
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=你的DockerHub用户名 \
  --docker-password=你的DockerHub密码或Token \
  --namespace=flashsale-prod

# 验证
kubectl get secret docker-registry-secret -n flashsale-dev
kubectl get secret docker-registry-secret -n flashsale-prod
```

**获取 Docker Hub Token**:
1. 登录 https://hub.docker.com/
2. Account Settings → Security → New Access Token
3. Description: `k3s-flashsale-deploy`
4. 权限选择: Read, Write, Delete
5. 复制 Token（只显示一次，务必保存）

### 6.2 生成 kubeconfig 给 GitHub Actions

```bash
# === 方式1: 在服务器上执行 ===

# 复制 kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > /tmp/kubeconfig-remote.yaml

# 获取服务器公网 IP
SERVER_IP=$(curl -s ifconfig.me)

# 修改 server 地址
sudo sed -i "s|https://127.0.0.1:6443|https://$SERVER_IP:6443|g" /tmp/kubeconfig-remote.yaml

# 生成 base64（Linux）
cat /tmp/kubeconfig-remote.yaml | base64 -w 0 > /tmp/kubeconfig-base64.txt
cat /tmp/kubeconfig-base64.txt

# 生成 base64（macOS）
cat /tmp/kubeconfig-remote.yaml | base64 > /tmp/kubeconfig-base64.txt
cat /tmp/kubeconfig-base64.txt

# 复制输出的 base64 字符串
```

```powershell
# === 方式2: Windows PowerShell (如果在本地执行) ===

# 读取文件
$content = Get-Content ~/.kube/config-k3s -Raw

# 转 base64
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)

# 输出到文件
$base64 | Out-File -FilePath kubeconfig-base64.txt -Encoding ASCII

# 复制到剪贴板
$base64 | Set-Clipboard

Write-Host "Base64 已复制到剪贴板并保存到 kubeconfig-base64.txt"
```

### 6.3 配置 GitHub Secrets（修正版）

在 GitHub 仓库添加以下 Secrets:

**Settings → Secrets and variables → Actions → New repository secret**

```yaml
# 【重要】注意 Secret 名称必须与 CI/CD 配置匹配

KUBE_CONFIG_DEV:
  Value: <上面生成的 base64 字符串>
  说明: K8s 集群访问凭证

HARBOR_USERNAME:
  Value: <你的 Docker Hub 用户名>
  说明: 虽然叫 HARBOR，但实际是 Docker Hub 用户名

HARBOR_PASSWORD:
  Value: <Docker Hub Token>
  说明: 使用 Token 而非密码，更安全

# 可选（钉钉通知）
DINGTALK_TOKEN:
  Value: <钉钉机器人 Webhook Token>
  说明: 部署通知（可选）
```

**获取钉钉 Token（可选）**:
1. 钉钉群 → 群设置 → 智能群助手 → 添加机器人 → 自定义
2. 安全设置: 选择"加签"，记录 Secret
3. 复制 Webhook URL 中的 `access_token=` 后面的部分

### 6.4 验证 GitHub Actions 配置

```bash
# 检查 CI/CD 配置文件
cat .github/workflows/ci-cd.yml | grep -E "HARBOR_|KUBE_CONFIG"

# 预期输出应该包含:
# username: ${{ secrets.HARBOR_USERNAME }}
# password: ${{ secrets.HARBOR_PASSWORD }}
# echo "${{ secrets.KUBE_CONFIG_DEV }}" | base64 -d > $HOME/.kube/config

# 确认镜像前缀
cat .github/workflows/ci-cd.yml | grep IMAGE_PREFIX

# 预期输出:
# IMAGE_PREFIX: mzlone  # 确保与你的 Docker Hub 用户名一致
```

---

## 七、部署应用

### 7.1 使用 Helm 部署

```bash
# 确保在项目根目录
cd flash-sale-system

# 检查 Helm Chart 语法
helm lint deploy/helm

# 预期输出: ==> Linting deploy/helm
#          1 chart(s) linted, 0 chart(s) failed

# 安装应用（开发环境）
helm upgrade --install flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --create-namespace \
  --values ./deploy/helm/values-dev.yaml \
  --set image.registry=docker.io \
  --set image.prefix=你的DockerHub用户名 \
  --set image.tag=main-latest \
  --wait --timeout 10m

# 等待所有 Pod 就绪
kubectl wait --for=condition=ready pod \
  -l "app.kubernetes.io/instance=flashsale" \
  -n flashsale-dev \
  --timeout=600s
```

### 7.2 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -n flashsale-dev

# 预期输出（所有 Pod 都是 Running）:
# NAME                              READY   STATUS    RESTARTS   AGE
# usercenter-api-xxxxx              1/1     Running   0          2m
# usercenter-rpc-xxxxx              1/1     Running   0          2m
# travel-api-xxxxx                  1/1     Running   0          2m
# travel-rpc-xxxxx                  1/1     Running   0          2m
# order-api-xxxxx                   1/1     Running   0          2m
# order-rpc-xxxxx                   1/1     Running   0          2m
# order-mq-xxxxx                    1/1     Running   0          2m
# payment-api-xxxxx                 1/1     Running   0          2m
# payment-rpc-xxxxx                 1/1     Running   0          2m
# mqueue-job-xxxxx                  1/1     Running   0          2m
# mqueue-scheduler-xxxxx            1/1     Running   0          2m

# 查看服务
kubectl get svc -n flashsale-dev

# 查看 Ingress
kubectl get ingress -n flashsale-dev
kubectl describe ingress flashsale-ingress -n flashsale-dev

# 检查日志（如有问题）
kubectl logs -l app.kubernetes.io/name=usercenter-api -n flashsale-dev --tail=50
```

### 7.3 测试 API

**方式1: 端口转发测试**

```bash
# 转发 usercenter-api
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:1004 &

# 等待端口转发就绪
sleep 2

# 测试健康检查
curl http://localhost:8080/healthz
# 预期输出: OK

# 测试 API
curl http://localhost:8080/usercenter/v1/ping
# 预期输出: {"code":0,"msg":"pong"}

# 测试注册
curl -X POST http://localhost:8080/usercenter/v1/user/register \
  -H "Content-Type: application/json" \
  -d '{"mobile":"13800138000","password":"123456","nickname":"测试用户"}'

# 停止端口转发
pkill -f "port-forward.*usercenter"
```

**方式2: 通过 Ingress 测试**

```bash
# 获取 Ingress 地址
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')

echo "Ingress 访问地址: http://$INGRESS_IP:$INGRESS_PORT"

# 测试（使用 Host 头）
curl -H "Host: dev-api.flashsale.com" \
  http://$INGRESS_IP:$INGRESS_PORT/usercenter/v1/ping

# 或者通过域名（如已配置 DNS/hosts）
curl http://dev-api.flashsale.com/usercenter/v1/ping
```

**方式3: 访问 Swagger 文档**

```bash
# 端口转发
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:1004

# 浏览器访问:
# http://localhost:8080/swagger/index.html

# 测试各个服务的 Swagger:
# usercenter: http://localhost:8080/swagger/index.html
# order: kubectl port-forward -n flashsale-dev svc/order-api 8081:1001
#        http://localhost:8081/swagger/index.html
```

### 7.4 触发 CI/CD 自动部署

```bash
# 在本地项目目录

# 1. 提交代码
git add .
git commit -m "feat: enable k3s deployment"
git push origin main

# 2. 查看 GitHub Actions
# 浏览器打开: https://github.com/你的用户名/flash-sale-system/actions

# 3. 等待部署完成（约5-10分钟）
# - Build images (约5分钟)
# - Deploy to dev (约2分钟)

# 4. 在服务器查看部署
kubectl get pods -n flashsale-dev -w
```

---

## 八、部署监控（可选）

### 8.1 部署 Prometheus + Grafana

```bash
# 安装 Prometheus Operator
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=2Gi \
  --set grafana.adminPassword=admin123 \
  --set grafana.persistence.enabled=true \
  --set grafana.persistence.size=5Gi \
  --wait --timeout 10m

# 等待部署
kubectl get pods -n monitoring -w

# 访问 Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 浏览器打开: http://localhost:3000
# 用户名: admin
# 密码: admin123
```

### 8.2 配置应用监控（需要应用支持）

```bash
# 更新 Helm 部署，启用 ServiceMonitor
helm upgrade flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --reuse-values \
  --set serviceMonitor.enabled=true

# 验证 ServiceMonitor
kubectl get servicemonitor -n flashsale-dev

# 在 Prometheus 中查看 targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# 浏览器打开: http://localhost:9090/targets
# 搜索: flashsale
```

### 8.3 部署 Jaeger（链路追踪）

```bash
# 简化版 Jaeger（All-in-One）
kubectl create namespace observability

cat > /tmp/jaeger.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: observability
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:1.52
        ports:
        - containerPort: 5775
          protocol: UDP
        - containerPort: 6831
          protocol: UDP
        - containerPort: 6832
          protocol: UDP
        - containerPort: 5778
        - containerPort: 16686
        - containerPort: 14268
        env:
        - name: COLLECTOR_ZIPKIN_HOST_PORT
          value: ":9411"
        - name: SPAN_STORAGE_TYPE
          value: "memory"
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-collector
  namespace: observability
spec:
  selector:
    app: jaeger
  ports:
  - name: jaeger-collector-http
    port: 14268
    targetPort: 14268
  - name: jaeger-collector-grpc
    port: 14250
    targetPort: 14250
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-query
  namespace: observability
spec:
  selector:
    app: jaeger
  type: NodePort
  ports:
  - name: jaeger-ui
    port: 16686
    targetPort: 16686
    nodePort: 30686
---
apiVersion: v1
kind: Service
metadata:
  name: jaeger-agent
  namespace: observability
spec:
  selector:
    app: jaeger
  ports:
  - name: jaeger-agent-compact
    port: 6831
    protocol: UDP
    targetPort: 6831
  - name: jaeger-agent-binary
    port: 6832
    protocol: UDP
    targetPort: 6832
EOF

kubectl apply -f /tmp/jaeger.yaml

# 等待部署
kubectl wait --for=condition=ready pod -l app=jaeger -n observability --timeout=300s

# 访问 Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686

# 浏览器打开: http://localhost:16686
```

### 8.4 部署 Asynqmon（任务队列监控）

```bash
cat > /tmp/asynqmon.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: asynqmon
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: asynqmon
  template:
    metadata:
      labels:
        app: asynqmon
    spec:
      containers:
      - name: asynqmon
        image: hibiken/asynqmon:latest
        args:
        - "--redis-addr=redis-master.infra.svc.cluster.local:6379"
        - "--redis-password=G62m50oigInC30sf"
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: asynqmon
  namespace: monitoring
spec:
  selector:
    app: asynqmon
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30980
EOF

kubectl apply -f /tmp/asynqmon.yaml

# 访问 Asynqmon
kubectl port-forward -n monitoring svc/asynqmon 8980:8080

# 浏览器打开: http://localhost:8980
```

---

## 九、常见问题排查

### 问题1: Pod 状态 ImagePullBackOff

```bash
# 原因: 镜像拉取失败

# 1. 查看详细错误
kubectl describe pod <pod-name> -n flashsale-dev

# 2. 检查 Secret 是否正确
kubectl get secret docker-registry-secret -n flashsale-dev -o yaml

# 3. 重新创建 Secret
kubectl delete secret docker-registry-secret -n flashsale-dev
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=用户名 \
  --docker-password=Token \
  --namespace=flashsale-dev

# 4. 检查镜像是否存在
# 浏览器访问: https://hub.docker.com/r/你的用户名/usercenter-api/tags

# 5. 手动拉取测试
docker pull docker.io/你的用户名/usercenter-api:main-latest

# 6. 重启 Pod
kubectl rollout restart deployment/usercenter-api -n flashsale-dev
```

### 问题2: Pod 状态 CrashLoopBackOff

```bash
# 原因: 容器启动后崩溃

# 1. 查看日志
kubectl logs <pod-name> -n flashsale-dev --tail=100

# 2. 查看详细信息
kubectl describe pod <pod-name> -n flashsale-dev

# 3. 常见原因排查:

# 3.1 数据库连接失败
kubectl exec -it <pod-name> -n flashsale-dev -- env | grep -i mysql
# 验证: ping mysql.infra.svc.cluster.local

# 3.2 Redis 连接失败
kubectl exec -it <pod-name> -n flashsale-dev -- env | grep -i redis
# 验证: redis-cli -h redis-master.infra.svc.cluster.local -a G62m50oigInC30sf PING

# 3.3 Kafka 连接失败
kubectl get svc -n infra | grep kafka

# 3.4 配置文件错误
kubectl get configmap -n flashsale-dev flashsale-config -o yaml

# 4. 进入容器调试
kubectl exec -it <pod-name> -n flashsale-dev -- sh
# 查看配置: cat /app/etc/*.yaml
# 测试连接: ping mysql.infra.svc.cluster.local
```

### 问题3: 无法远程访问 K8s API

```bash
# 原因: 防火墙阻止或 kubeconfig 配置错误

# 1. 检查防火墙
sudo ufw status
sudo ufw allow 6443/tcp

# 2. 检查 K3s 服务
systemctl status k3s

# 3. 检查 kubeconfig 中的 server 地址
cat ~/.kube/config-k3s | grep server

# 4. 测试端口连通性（在本地执行）
telnet 服务器IP 6443
# 或
nc -zv 服务器IP 6443

# 5. 检查服务器监听
sudo netstat -tlnp | grep 6443

# 6. 重启 K3s
sudo systemctl restart k3s
```

### 问题4: 数据库连接失败

```bash
# 1. 检查 MySQL Pod
kubectl get pods -n infra -l app=mysql

# 2. 测试数据库连接
kubectl exec -it deploy/mysql -n infra -- \
  mysql -uroot -pPXDN93VRKUm8TeE7 -e "SHOW DATABASES;"

# 3. 检查网络连通性
kubectl run mysql-client --rm -it --image=mysql:8.0.28 -- \
  mysql -h mysql.infra.svc.cluster.local -uroot -pPXDN93VRKUm8TeE7 -e "SELECT 1;"

# 4. 检查 Service
kubectl get svc mysql -n infra
kubectl describe svc mysql -n infra

# 5. 检查 DNS 解析
kubectl run dnsutils --rm -it --image=busybox:1.28 -- \
  nslookup mysql.infra.svc.cluster.local

# 6. 检查配置
kubectl get configmap -n flashsale-dev flashsale-config -o yaml | grep -i mysql
```

### 问题5: 存储空间不足

```bash
# 1. 查看磁盘使用
df -h

# 2. 查看 PVC 使用情况
kubectl get pvc -A
kubectl describe pvc mysql-pvc -n infra

# 3. 清理未使用的镜像（在 K3s 节点上）
sudo k3s crictl images
sudo k3s crictl rmi --prune

# 4. 清理已完成的 Pod
kubectl delete pod --field-selector=status.phase==Succeeded -A
kubectl delete pod --field-selector=status.phase==Failed -A

# 5. 扩容 PVC（如果存储类支持）
kubectl patch pvc mysql-pvc -n infra -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# 6. 清理日志
sudo journalctl --vacuum-time=7d
```

### 问题6: Kafka 连接失败

```bash
# 1. 检查 Kafka Pod
kubectl get pods -n infra -l strimzi.io/cluster=flashsale-kafka

# 2. 查看 Kafka 状态
kubectl get kafka flashsale-kafka -n infra

# 3. 检查 Kafka Service
kubectl get svc -n infra | grep kafka

# 4. 测试 Kafka 连接
kubectl run kafka-test --rm -it --image=apache/kafka:3.6.1 -- \
  kafka-topics.sh --list \
  --bootstrap-server flashsale-kafka-kafka-bootstrap.infra.svc.cluster.local:9092

# 5. 查看 Kafka 日志
kubectl logs -n infra flashsale-kafka-kafka-0

# 6. 重启 Kafka
kubectl rollout restart statefulset/flashsale-kafka-kafka -n infra
```

### 问题7: Ingress 无法访问

```bash
# 1. 检查 Ingress Controller
kubectl get pods -n ingress-nginx

# 2. 查看 Ingress 配置
kubectl get ingress -n flashsale-dev
kubectl describe ingress flashsale-ingress -n flashsale-dev

# 3. 检查 Ingress Service
kubectl get svc -n ingress-nginx

# 4. 测试 Ingress Controller
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -v http://$INGRESS_IP

# 5. 检查日志
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=100

# 6. 验证后端服务
kubectl get endpoints -n flashsale-dev
```

---

## 十、资源优化建议

### 10.1 轻量配置（2核4G服务器）

如果服务器资源紧张，可以调整以下配置:

**方案1: 禁用部分服务**

```yaml
# deploy/helm/values-dev.yaml

services:
  # 保留核心服务
  usercenterApi:
    enabled: true
  usercenterRpc:
    enabled: true
  orderApi:
    enabled: true
  orderRpc:
    enabled: true
  paymentApi:
    enabled: true
  paymentRpc:
    enabled: true

  # 可选服务设为 false
  travelApi:
    enabled: false
  travelRpc:
    enabled: false
  orderMq:
    enabled: false
  mqueueJob:
    enabled: false
  mqueueScheduler:
    enabled: false
```

**方案2: 降低资源请求**

```yaml
resources:
  api:
    limits:
      cpu: 300m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
  rpc:
    limits:
      cpu: 300m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
```

**方案3: 简化基础设施**

```bash
# Redis 单实例（不要副本）
helm upgrade redis bitnami/redis \
  --namespace infra \
  --reuse-values \
  --set replica.replicaCount=0

# 不安装监控
# 跳过第八章的监控部署
```

### 10.2 生产配置（4核8G服务器）

```yaml
# deploy/helm/values-prod.yaml

# 增加副本数（高可用）
replicaCount: 2

# 合理资源配置
resources:
  api:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi
  rpc:
    limits:
      cpu: 1000m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

# 启用 HPA
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

# 启用监控
serviceMonitor:
  enabled: true
```

---

## 十一、备份和恢复

### 11.1 备份数据库

```bash
# 手动备份
DATE=$(date +%Y%m%d_%H%M%S)
kubectl exec -n infra deploy/mysql -- \
  mysqldump -uroot -pPXDN93VRKUm8TeE7 --all-databases \
  > backup_$DATE.sql

# 定期备份脚本
cat > /usr/local/bin/k8s-mysql-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/backup/mysql"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

kubectl exec -n infra deploy/mysql -- \
  mysqldump -uroot -pPXDN93VRKUm8TeE7 --all-databases \
  > $BACKUP_DIR/backup_$DATE.sql

# 压缩
gzip $BACKUP_DIR/backup_$DATE.sql

# 保留最近7天的备份
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +7 -delete

echo "备份完成: $BACKUP_DIR/backup_$DATE.sql.gz"
EOF

chmod +x /usr/local/bin/k8s-mysql-backup.sh

# 添加到 crontab（每天凌晨2点备份）
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/k8s-mysql-backup.sh") | crontab -
```

### 11.2 恢复数据库

```bash
# 导入数据库
kubectl exec -i -n infra deploy/mysql -- \
  mysql -uroot -pPXDN93VRKUm8TeE7 < backup.sql

# 从压缩文件恢复
gunzip -c backup_20250101_020000.sql.gz | \
  kubectl exec -i -n infra deploy/mysql -- \
  mysql -uroot -pPXDN93VRKUm8TeE7
```

### 11.3 备份 K3s 集群配置

```bash
# 备份脚本
cat > /usr/local/bin/k8s-config-backup.sh <<'EOF'
#!/bin/bash
BACKUP_DIR="/backup/k8s"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份所有 namespace 的资源
for ns in flashsale-dev flashsale-prod infra; do
  kubectl get all,configmap,secret,ingress,pvc -n $ns -o yaml \
    > $BACKUP_DIR/${ns}_$DATE.yaml
done

# 备份 helm releases
helm list -A -o yaml > $BACKUP_DIR/helm_releases_$DATE.yaml

# 压缩
tar czf $BACKUP_DIR/k8s_backup_$DATE.tar.gz $BACKUP_DIR/*_$DATE.yaml
rm -f $BACKUP_DIR/*_$DATE.yaml

# 保留最近30天
find $BACKUP_DIR -name "k8s_backup_*.tar.gz" -mtime +30 -delete

echo "备份完成: $BACKUP_DIR/k8s_backup_$DATE.tar.gz"
EOF

chmod +x /usr/local/bin/k8s-config-backup.sh

# 每天备份
(crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/k8s-config-backup.sh") | crontab -
```

---

## 十二、卸载和清理

### 12.1 卸载应用

```bash
# 删除应用
helm uninstall flashsale -n flashsale-dev

# 删除命名空间
kubectl delete namespace flashsale-dev
kubectl delete namespace flashsale-prod
```

### 12.2 卸载基础设施

```bash
# 删除 Kafka
kubectl delete kafka flashsale-kafka -n infra
kubectl delete namespace kafka

# 删除 Redis
helm uninstall redis -n infra

# 删除 MySQL
kubectl delete -f /tmp/mysql-k3s.yaml

# 删除监控
helm uninstall prometheus -n monitoring
kubectl delete namespace monitoring observability

# 删除基础设施命名空间
kubectl delete namespace infra
```

### 12.3 完全卸载 K3s

```bash
# 在服务器上执行
/usr/local/bin/k3s-uninstall.sh

# 清理残留文件
sudo rm -rf /var/lib/rancher
sudo rm -rf /etc/rancher
sudo rm -rf ~/.kube

# 清理数据目录（如果使用了本地存储）
sudo rm -rf /var/lib/rancher/k3s/storage
```

---

## 十三、总结与下一步

### 13.1 部署清单

完成以上步骤后，你的 K3s 集群已经就绪：

✅ **基础设施**
- [x] K3s 单节点集群运行
- [x] Nginx Ingress 配置完成
- [x] Helm 包管理工具安装

✅ **数据层**
- [x] MySQL 8.0 部署并初始化数据库
- [x] Redis 主从部署
- [x] Kafka 集群部署（单节点）
- [x] Kafka Topics 创建完成

✅ **应用层**
- [x] 11个微服务部署完成
- [x] ConfigMap 配置完整（含密码）
- [x] Ingress 路由配置
- [x] JWT Secret 生成

✅ **CI/CD**
- [x] GitHub Actions 配置
- [x] Docker Hub 镜像仓库
- [x] 自动化部署流程

✅ **监控（可选）**
- [x] Prometheus + Grafana
- [x] Jaeger 链路追踪
- [x] Asynqmon 任务监控

### 13.2 成本估算

**服务器成本**：
- 阿里云/腾讯云 4核8G: ¥150-250/月
- 域名: ¥50-100/年
- 总计: **约¥200/月**

**性能指标**：
- QPS: 5000+ (单实例)
- 并发用户: 500+
- 响应时间: P99 < 200ms

### 13.3 下一步计划

**短期优化**:
1. 配置 HTTPS 证书（Let's Encrypt）
2. 设置监控告警规则
3. 配置日志聚合（ELK）
4. 添加更多测试用例

**中期扩展**:
1. 添加更多服务节点（多节点集群）
2. 配置数据库主从复制
3. Redis 集群模式
4. Kafka 多副本

**长期规划**:
1. 迁移到云托管 K8s（EKS/GKE/AKS）
2. 服务网格（Istio/Linkerd）
3. GitOps（ArgoCD/Flux）
4. 多区域部署

### 13.4 参考资料

- [K3s 官方文档](https://docs.k3s.io/)
- [go-zero 文档](https://go-zero.dev/)
- [Helm 文档](https://helm.sh/docs/)
- [Kubernetes 官方文档](https://kubernetes.io/docs/)
- [Strimzi Kafka Operator](https://strimzi.io/)

### 13.5 获取帮助

遇到问题？

1. 查看本文档第九章"常见问题排查"
2. 查看项目 GitHub Issues
3. 加入技术交流群（见 README）
4. 提交 Issue: https://github.com/Lance-Mao/flash-sale-system/issues

---

## 附录 A: 快速命令参考

### 查看状态
```bash
# 集群状态
kubectl get nodes
kubectl cluster-info

# 所有资源
kubectl get all -A

# 特定命名空间
kubectl get pods -n flashsale-dev
kubectl get pods -n infra

# 资源使用
kubectl top nodes
kubectl top pods -A
```

### 日志查看
```bash
# 查看日志
kubectl logs <pod-name> -n flashsale-dev
kubectl logs -f <pod-name> -n flashsale-dev  # 实时查看
kubectl logs --tail=100 <pod-name> -n flashsale-dev  # 最近100行
kubectl logs <pod-name> -n flashsale-dev --previous  # 查看上一个容器的日志
```

### 调试命令
```bash
# 进入容器
kubectl exec -it <pod-name> -n flashsale-dev -- sh

# 端口转发
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:1004

# 查看详细信息
kubectl describe pod <pod-name> -n flashsale-dev
kubectl describe svc <service-name> -n flashsale-dev

# 查看事件
kubectl get events -n flashsale-dev --sort-by='.lastTimestamp'
```

### 重启服务
```bash
# 重启 Deployment
kubectl rollout restart deployment/usercenter-api -n flashsale-dev

# 查看重启状态
kubectl rollout status deployment/usercenter-api -n flashsale-dev

# 回滚
kubectl rollout undo deployment/usercenter-api -n flashsale-dev
```

### Helm 命令
```bash
# 查看已安装的 release
helm list -A

# 查看 release 详情
helm get values flashsale -n flashsale-dev

# 更新配置
helm upgrade flashsale ./deploy/helm \
  --namespace flashsale-dev \
  --reuse-values \
  --set image.tag=new-tag

# 卸载
helm uninstall flashsale -n flashsale-dev
```

---

**文档版本**: v2.0 (修复版)
**最后更新**: 2025-12-29
**维护者**: Flash Sale Team

有问题随时查看文档或提 Issue！
