# 服务器 Kubernetes 环境准备完整指南

## 目录
- [方案一：云 K8s 服务（最简单）](#方案一云-k8s-服务推荐)
- [方案二：K3s 轻量集群（性价比高）](#方案二k3s-轻量集群推荐)
- [方案三：Kubeadm 标准集群（生产级）](#方案三kubeadm-标准集群)
- [基础设施部署](#基础设施部署)
- [CI/CD 集成配置](#cicd-集成配置)

---

## 方案一：云 K8s 服务（推荐）

### 优势
✅ 5分钟创建集群，开箱即用
✅ 自动高可用、自动扩缩容
✅ 集成监控、日志、存储
✅ 专业运维支持

### 1.1 阿里云 ACK（推荐国内用户）

#### 创建集群
```bash
# 方式1: 控制台创建（推荐新手）
# https://cs.console.aliyun.com/

# 方式2: CLI创建
# 安装阿里云CLI
curl -o aliyun https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz
tar -xzf aliyun-cli-linux-latest-amd64.tgz
sudo mv aliyun /usr/local/bin/

# 配置凭证
aliyun configure

# 创建托管版K8s集群（推荐）
aliyun cs CreateCluster \
  --ClusterType ManagedKubernetes \
  --Name flash-sale-k8s \
  --RegionId cn-hangzhou \
  --VpcId vpc-xxxxx \
  --VSwitchIds '["vsw-xxxxx"]' \
  --WorkerInstanceTypes '["ecs.c6.large"]' \
  --NumOfNodes 3 \
  --WorkerSystemDiskCategory cloud_essd \
  --WorkerSystemDiskSize 120 \
  --KubernetesVersion 1.28.3-aliyun.1
```

#### 配置推荐
**最小配置（学习/测试）**:
- 节点: 2台 ECS (2核4G)
- 费用: ~¥200/月
- 适合: 开发测试环境

**推荐配置（小型生产）**:
- 节点: 3台 ECS (4核8G)
- 负载均衡: SLB
- 存储: NAS/OSS
- 费用: ~¥800/月
- 适合: 中小企业生产环境

#### 下载 kubeconfig
```bash
# 方式1: 控制台下载
# 集群列表 -> 集群详情 -> 连接信息 -> 下载 kubeconfig

# 方式2: CLI获取
aliyun cs DescribeClusterUserKubeconfig \
  --ClusterId c-xxxxxx > ~/.kube/config-ack

# 测试连接
export KUBECONFIG=~/.kube/config-ack
kubectl get nodes
```

### 1.2 腾讯云 TKE

```bash
# 控制台创建: https://console.cloud.tencent.com/tke2

# 或使用 CLI
tccli tke CreateCluster \
  --ClusterName flash-sale-k8s \
  --ClusterVersion 1.28.4 \
  --VpcId vpc-xxxxx \
  --RunInstancesForNode.InstanceCount 3 \
  --RunInstancesForNode.InstanceType SA2.MEDIUM4
```

### 1.3 AWS EKS

```bash
# 安装 eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# 创建集群
eksctl create cluster \
  --name flash-sale-k8s \
  --version 1.28 \
  --region us-east-1 \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed

# 自动配置 kubeconfig
aws eks update-kubeconfig --region us-east-1 --name flash-sale-k8s
```

### 1.4 配置存储类（云服务通用）

```yaml
# 阿里云 ESSD 高性能存储
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: alicloud-disk-essd
provisioner: diskplugin.csi.alibabacloud.com
parameters:
  type: cloud_essd
reclaimPolicy: Retain
allowVolumeExpansion: true
```

---

## 方案二：K3s 轻量集群（推荐）

### 优势
✅ 资源占用低（512M内存即可运行）
✅ 安装简单（一条命令）
✅ 功能完整（兼容K8s API）
✅ 适合边缘计算、IoT

### 2.1 服务器要求

**最小配置**:
- CPU: 2核
- 内存: 2GB
- 硬盘: 20GB
- 系统: Ubuntu 20.04/22.04 或 CentOS 7/8

**推荐配置（3节点集群）**:
```
主节点: 2核4G x1
工作节点: 4核8G x2
```

### 2.2 单节点快速安装

```bash
# === 在服务器上执行 ===

# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 安装 K3s（国内推荐使用镜像加速）
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  INSTALL_K3S_VERSION=v1.28.5+k3s1 \
  sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik

# 3. 等待安装完成（约1-2分钟）
sudo systemctl status k3s

# 4. 验证集群
kubectl get nodes
```

### 2.3 多节点高可用集群

#### 主节点（Master）
```bash
# 在第一台服务器执行
export K3S_TOKEN="your-secret-token-here"  # 自定义一个密钥
export MASTER_IP="192.168.1.10"  # 主节点IP

curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  K3S_TOKEN=$K3S_TOKEN \
  sh -s - server \
  --cluster-init \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --tls-san $MASTER_IP

# 查看节点加入令牌
sudo cat /var/lib/rancher/k3s/server/node-token
```

#### 工作节点（Worker）
```bash
# 在其他服务器执行
export K3S_URL="https://192.168.1.10:6443"  # 主节点IP
export K3S_TOKEN="K10xxx::server:xxxx"  # 从主节点获取的token

curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | \
  INSTALL_K3S_MIRROR=cn \
  K3S_URL=$K3S_URL \
  K3S_TOKEN=$K3S_TOKEN \
  sh -

# 验证加入成功
# 在主节点执行:
kubectl get nodes
```

### 2.4 配置远程访问

```bash
# === 在服务器上 ===
# 复制 kubeconfig 到本地
sudo cat /etc/rancher/k3s/k3s.yaml

# === 在本地电脑 ===
# 创建配置文件
mkdir -p ~/.kube
nano ~/.kube/config-k3s

# 粘贴上面复制的内容，并修改 server 地址:
# server: https://127.0.0.1:6443
# 改为:
# server: https://你的服务器公网IP:6443

# 测试连接
export KUBECONFIG=~/.kube/config-k3s
kubectl get nodes
```

### 2.5 配置本地存储（Local Path Provisioner）

K3s 自带 local-path 存储，但建议配置为默认：

```bash
kubectl patch storageclass local-path \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 验证
kubectl get storageclass
```

---

## 方案三：Kubeadm 标准集群

### 3.1 服务器要求

**最小拓扑（1主2从）**:
```
Master: 2核4G x1（运行控制平面）
Worker: 4核8G x2（运行应用负载）
```

**推荐拓扑（3主3从）**:
```
Master: 4核8G x3（高可用控制平面）
Worker: 8核16G x3（生产负载）
Load Balancer: HAProxy/Nginx（可选）
```

### 3.2 前置准备（所有节点）

```bash
# === 在所有节点执行 ===

# 1. 关闭防火墙和SELinux
sudo systemctl stop firewalld
sudo systemctl disable firewalld
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 2. 关闭 swap
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# 3. 配置内核参数
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# 4. 安装容器运行时（containerd）
sudo apt-get update
sudo apt-get install -y containerd

# 配置 containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 重启 containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

# 5. 安装 kubeadm、kubelet、kubectl
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl

# 添加K8s仓库（国内镜像）
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | sudo apt-key add -
cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF

sudo apt-get update
sudo apt-get install -y kubelet=1.28.5-00 kubeadm=1.28.5-00 kubectl=1.28.5-00
sudo apt-mark hold kubelet kubeadm kubectl
```

### 3.3 初始化主节点

```bash
# === 仅在第一个主节点执行 ===

# 1. 初始化集群
sudo kubeadm init \
  --kubernetes-version=v1.28.5 \
  --pod-network-cidr=10.244.0.0/16 \
  --service-cidr=10.96.0.0/12 \
  --image-repository=registry.aliyuncs.com/google_containers \
  --apiserver-advertise-address=192.168.1.10  # 主节点IP

# 2. 配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 3. 安装网络插件（Calico）
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 或者使用 Flannel（更轻量）
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# 4. 查看集群状态
kubectl get nodes
kubectl get pods -A

# 5. 获取工作节点加入命令
kubeadm token create --print-join-command
# 复制输出的命令，在工作节点执行
```

### 3.4 加入工作节点

```bash
# === 在每个工作节点执行 ===

# 使用主节点输出的命令
sudo kubeadm join 192.168.1.10:6443 \
  --token abcdef.0123456789abcdef \
  --discovery-token-ca-cert-hash sha256:xxxxx

# 验证（在主节点执行）
kubectl get nodes
```

### 3.5 配置 Ingress Controller

```bash
# 安装 Nginx Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/baremetal/deploy.yaml

# 等待部署完成
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

# 查看 NodePort
kubectl get svc -n ingress-nginx
```

---

## 基础设施部署

### 部署顺序
```
1. 命名空间 → 2. MySQL → 3. Redis → 4. Kafka → 5. 初始化数据
```

### 1. 创建命名空间
```bash
kubectl create namespace flashsale-dev
kubectl create namespace flashsale-prod
kubectl create namespace infra  # 基础设施
```

### 2. 部署 MySQL（使用 StatefulSet）

```bash
# 创建配置文件
cat > mysql-deploy.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: infra
data:
  my.cnf: |
    [mysqld]
    max_connections=500
    character-set-server=utf8mb4
    collation-server=utf8mb4_unicode_ci
    default-time-zone='+08:00'
---
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
kind: Service
metadata:
  name: mysql
  namespace: infra
spec:
  ports:
  - port: 3306
    targetPort: 3306
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: infra
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
          name: mysql
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
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
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

# 部署
kubectl apply -f mysql-deploy.yaml

# 验证
kubectl get pods -n infra -w
kubectl logs -f mysql-0 -n infra
```

### 3. 部署 Redis（使用 Helm）

```bash
# 安装 Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 添加 Bitnami 仓库
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 部署 Redis
helm install redis bitnami/redis \
  --namespace infra \
  --set auth.password=G62m50oigInC30sf \
  --set master.persistence.size=10Gi \
  --set replica.replicaCount=2 \
  --set replica.persistence.size=10Gi

# 获取连接信息
kubectl get secret --namespace infra redis -o jsonpath="{.data.redis-password}" | base64 -d
```

### 4. 部署 Kafka（使用 Strimzi）

```bash
# 创建命名空间
kubectl create namespace kafka

# 安装 Strimzi Operator
kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka

# 等待 Operator 就绪
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n kafka --timeout=300s

# 部署 Kafka 集群
cat > kafka-cluster.yaml <<'EOF'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: flashsale-kafka
  namespace: infra
spec:
  kafka:
    version: 3.6.1
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
    storage:
      type: persistent-claim
      size: 10Gi
      deleteClaim: false
    resources:
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 2000m
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
      deleteClaim: false
    resources:
      requests:
        memory: 1Gi
        cpu: 250m
      limits:
        memory: 2Gi
        cpu: 500m
  entityOperator:
    topicOperator: {}
    userOperator: {}
EOF

kubectl apply -f kafka-cluster.yaml

# 验证
kubectl get kafka -n infra
kubectl get pods -n infra -l strimzi.io/cluster=flashsale-kafka
```

### 5. 初始化数据库

```bash
# 端口转发到本地
kubectl port-forward -n infra svc/mysql 3306:3306 &

# 导入 SQL（从项目根目录执行）
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql

# 验证
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 -e "SHOW DATABASES;"
```

---

## CI/CD 集成配置

### 1. 配置镜像拉取凭证

```bash
# Docker Hub
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-token \
  --namespace=flashsale-dev

kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-token \
  --namespace=flashsale-prod
```

### 2. 生成 kubeconfig 用于 GitHub Actions

```bash
# 方式1: 直接使用（K3s）
sudo cat /etc/rancher/k3s/k3s.yaml

# 方式2: 使用（Kubeadm）
cat ~/.kube/config

# 修改 server 地址为公网IP或域名
# server: https://kubernetes.docker.internal:6443
# 改为:
# server: https://你的服务器公网IP:6443

# Base64 编码
cat kubeconfig.yaml | base64 -w 0
```

### 3. 配置 GitHub Secrets

在 GitHub 仓库添加以下 Secrets:

```yaml
KUBE_CONFIG_DEV: <上面生成的 base64>
KUBE_CONFIG_PROD: <生产环境 kubeconfig base64>
DOCKERHUB_USERNAME: <Docker Hub 用户名>
DOCKERHUB_TOKEN: <Docker Hub Token>
```

### 4. 安全配置（重要）

#### 限制 API Server 访问（推荐）

```bash
# 方式1: 使用防火墙限制IP（推荐）
# 只允许 GitHub Actions IP段访问 6443 端口
# GitHub Actions IP 范围: https://api.github.com/meta

# 方式2: 使用 VPN
# 服务器和 GitHub Actions Runner 都连接到同一 VPN

# 方式3: 使用 Cloudflare Tunnel（参考现有文档）
# docs/K8S_DEPLOYMENT_TUNNEL.md
```

#### 创建专用 ServiceAccount（推荐）

```bash
# 创建 ServiceAccount
kubectl create serviceaccount github-actions -n flashsale-dev

# 创建 ClusterRole
cat > github-actions-role.yaml <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-actions-deployer
rules:
- apiGroups: ["", "apps", "batch", "networking.k8s.io"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

kubectl apply -f github-actions-role.yaml

# 绑定角色
kubectl create clusterrolebinding github-actions-binding \
  --clusterrole=github-actions-deployer \
  --serviceaccount=flashsale-dev:github-actions

# 获取 Token
kubectl create token github-actions -n flashsale-dev --duration=87600h
# 将此 token 添加到 kubeconfig 的 token 字段
```

---

## 验证清单

### 集群验证
```bash
# 节点状态
kubectl get nodes -o wide

# 组件健康
kubectl get cs

# 命名空间
kubectl get ns

# 存储类
kubectl get sc
```

### 基础设施验证
```bash
# MySQL
kubectl exec -it mysql-0 -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7 -e "SELECT VERSION();"

# Redis
kubectl exec -it redis-master-0 -n infra -- redis-cli -a G62m50oigInC30sf PING

# Kafka
kubectl get kafka -n infra
kubectl get pods -n infra -l strimzi.io/cluster=flashsale-kafka
```

### 网络验证
```bash
# 测试 Pod 网络
kubectl run test --image=busybox --rm -it -- sh
# 在容器内执行: ping mysql.infra.svc.cluster.local

# 测试 Ingress
kubectl get ingress -A
curl http://你的域名或NodePort
```

---

## 故障排查

### 节点 NotReady
```bash
# 查看节点详情
kubectl describe node <node-name>

# 检查 kubelet 日志
journalctl -u kubelet -f

# 常见原因:
# - CNI 网络插件未安装
# - 容器运行时问题
# - 磁盘空间不足
```

### Pod 启动失败
```bash
# 查看 Pod 详情
kubectl describe pod <pod-name> -n <namespace>

# 查看日志
kubectl logs <pod-name> -n <namespace>

# 常见问题:
# - ImagePullBackOff: 镜像拉取失败（检查 Secret）
# - CrashLoopBackOff: 容器启动后崩溃（检查日志和配置）
# - Pending: 资源不足或调度问题
```

### 持久化存储问题
```bash
# 查看 PVC 状态
kubectl get pvc -A

# 查看 PV
kubectl get pv

# 查看 StorageClass
kubectl get sc

# 如果 PVC Pending，检查:
# - StorageClass 是否存在
# - 是否有可用的 PV
# - 节点是否有足够磁盘空间
```

---

## 监控和维护

### 安装 Prometheus + Grafana

```bash
# 添加 Helm 仓库
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 安装
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=15d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi

# 访问 Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 获取密码
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### 日志收集（可选）

```bash
# 安装 Loki Stack（轻量级日志方案）
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=50Gi
```

---

## 成本估算

### 方案对比

| 项目 | 云K8s | K3s单节点 | K3s集群 | Kubeadm集群 |
|------|-------|-----------|---------|-------------|
| **服务器** | 无需购买 | 1台 | 3台 | 6台 |
| **配置** | 2核4G x2 | 2核4G | 4核8G x3 | 4核8G x6 |
| **月费用** | ¥200-500 | ¥100-200 | ¥600-900 | ¥1200-1800 |
| **运维难度** | ⭐ | ⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ |
| **适用场景** | 快速上线 | 学习测试 | 小型生产 | 大型生产 |

### 推荐配置

**学习/验证**: 云K8s 或 K3s 单节点
**小型创业公司**: K3s 3节点集群
**中大型企业**: 云K8s 或 Kubeadm 多节点

---

## 下一步

完成 K8s 环境准备后:

1. ✅ 部署基础设施（MySQL/Redis/Kafka）
2. ✅ 配置 GitHub Secrets
3. ✅ 推送代码触发 CI/CD
4. ✅ 验证应用部署成功

参考文档:
- CI/CD 完整流程: `docs/ci-cd-enhancement/CI_CD_GUIDE.md`
- GitHub Secrets 配置: `docs/GITHUB_SECRETS_SETUP.md`
- Helm Chart 配置: `deploy/helm/`
