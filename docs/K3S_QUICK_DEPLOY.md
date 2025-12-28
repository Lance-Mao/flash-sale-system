# K3s 轻量部署指南（30分钟上线）

## 概述

K3s 是轻量级 Kubernetes，资源占用低、安装简单，非常适合中小型项目。

**特点**：
- 单文件二进制，安装包 < 100MB
- 内存占用 < 512MB（vs 标准K8s 4GB+）
- 一条命令完成安装
- 100% 兼容 K8s API

---

## 一、服务器准备

### 1.1 服务器要求

**最小配置（单节点）**：
```
CPU: 2核
内存: 2GB
硬盘: 20GB
系统: Ubuntu 20.04/22.04、CentOS 7/8、Debian
```

**推荐配置（生产环境）**：
```
CPU: 4核
内存: 8GB
硬盘: 50GB SSD
```

### 1.2 系统准备（必做）

```bash
# SSH 登录到服务器后执行

# 1. 更新系统
sudo apt update && sudo apt upgrade -y

# 2. 关闭防火墙（或开放必要端口）
sudo ufw disable

# 或者开放端口：
# sudo ufw allow 6443/tcp  # K8s API
# sudo ufw allow 80/tcp    # HTTP
# sudo ufw allow 443/tcp   # HTTPS

# 3. 配置主机名（可选，但推荐）
sudo hostnamectl set-hostname k3s-master
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
notepad $env:USERPROFILE\.kube\config-k3s

# macOS/Linux:
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

# 记录 EXTERNAL-IP（如果是云服务器）或 NodePort（如果是自建服务器）
```

### 3.2 安装 Helm

```bash
# 安装 Helm（包管理工具）
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# 验证
helm version
```

### 3.3 创建命名空间

```bash
# 创建应用命名空间
kubectl create namespace flashsale-dev
kubectl create namespace flashsale-prod
kubectl create namespace infra

# 验证
kubectl get namespaces
```

---

## 四、部署基础设施（15分钟）

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
  --set master.resources.requests.cpu=100m

# 等待部署（约2分钟）
kubectl get pods -n infra -l app.kubernetes.io/name=redis -w

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

# 等待部署（约3分钟）
kubectl get kafka -n infra -w

# 验证
kubectl get pods -n infra -l strimzi.io/cluster=flashsale-kafka
```

### 4.4 初始化数据库

```bash
# 方式1: 端口转发（推荐）
kubectl port-forward -n infra svc/mysql 3306:3306 &

# 在项目根目录执行
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_usercenter.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_order.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_payment.sql
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 < deploy/sql/flashsale_product.sql

# 验证
mysql -h 127.0.0.1 -P 3306 -uroot -pPXDN93VRKUm8TeE7 -e "SHOW DATABASES;"

# 停止端口转发
pkill -f "port-forward.*mysql"  # Linux/macOS
# Windows: 在任务管理器中结束 kubectl 进程
```

---

## 五、CI/CD 集成

### 5.1 配置镜像拉取凭证

```bash
# 创建 Docker Hub Secret
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=你的DockerHub用户名 \
  --docker-password=你的DockerHub密码或Token \
  --namespace=flashsale-dev

kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=你的DockerHub用户名 \
  --docker-password=你的DockerHub密码或Token \
  --namespace=flashsale-prod
```

**获取 Docker Hub Token**:
1. 登录 https://hub.docker.com/
2. Account Settings → Security → New Access Token
3. 权限选择: Read, Write, Delete
4. 复制 Token（只显示一次）

### 5.2 生成 kubeconfig 给 GitHub Actions

```bash
# === 在服务器上执行 ===

# 复制 kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml > /tmp/kubeconfig-remote.yaml

# 修改 server 地址
sudo sed -i "s|https://127.0.0.1:6443|https://$(curl -s ifconfig.me):6443|g" /tmp/kubeconfig-remote.yaml

# 生成 base64
cat /tmp/kubeconfig-remote.yaml | base64 -w 0

# 复制输出的 base64 字符串
```

```bash
# === Windows PowerShell (如果在本地执行) ===

# 读取文件
$content = Get-Content ~/.kube/config-k3s -Raw

# 转 base64
$bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
$base64 = [Convert]::ToBase64String($bytes)

# 复制到剪贴板
$base64 | Set-Clipboard

# 输出到屏幕
Write-Host $base64
```

### 5.3 配置 GitHub Secrets

在 GitHub 仓库添加以下 Secrets:

**Settings → Secrets and variables → Actions → New repository secret**

```yaml
KUBE_CONFIG_DEV:
  Value: <上面生成的 base64 字符串>

DOCKERHUB_USERNAME:
  Value: <你的 Docker Hub 用户名>

DOCKERHUB_TOKEN:
  Value: <Docker Hub Token>

# 可选（钉钉通知）
DINGTALK_TOKEN:
  Value: <钉钉机器人 Token>
```

### 5.4 修改 Helm Values

编辑 `deploy/helm/values-dev.yaml`:

```yaml
# 修改镜像仓库（如果用 Docker Hub）
image:
  registry: docker.io
  prefix: 你的DockerHub用户名  # 例如: lancemao
  tag: latest

# 修改数据库连接
mysql:
  host: mysql.infra.svc.cluster.local  # K8s 内部 DNS
  port: 3306
  username: root
  password: PXDN93VRKUm8TeE7

redis:
  host: redis-master.infra.svc.cluster.local
  port: 6379
  password: G62m50oigInC30sf

kafka:
  brokers: flashsale-kafka-kafka-bootstrap.infra.svc.cluster.local:9092

# 修改 Ingress 域名（可选）
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.yourdomain.com  # 改为你的域名或服务器IP
      paths:
        - path: /
          pathType: Prefix
```

---

## 六、测试部署

### 6.1 触发 CI/CD

```bash
# 在本地项目目录

# 1. 提交代码
git add .
git commit -m "feat: enable k3s deployment"
git push origin main

# 2. 查看 GitHub Actions
# 浏览器打开: https://github.com/你的用户名/flash-sale-system/actions

# 3. 等待部署完成（约5-10分钟）
```

### 6.2 验证部署

```bash
# 查看 Pod 状态
kubectl get pods -n flashsale-dev

# 预期输出（所有 Pod 都是 Running）:
# NAME                              READY   STATUS    RESTARTS   AGE
# usercenter-api-xxx                1/1     Running   0          2m
# order-api-xxx                     1/1     Running   0          2m
# product-api-xxx                   1/1     Running   0          2m
# payment-api-xxx                   1/1     Running   0          2m

# 查看服务
kubectl get svc -n flashsale-dev

# 查看 Ingress
kubectl get ingress -n flashsale-dev
```

### 6.3 测试 API

```bash
# 方式1: 端口转发测试
kubectl port-forward -n flashsale-dev svc/usercenter-api 8080:8080

# 在浏览器访问:
# http://localhost:8080/swagger/index.html

# 或命令行测试:
curl http://localhost:8080/usercenter/v1/ping

# 方式2: 通过 Ingress 测试（如果已配置域名）
curl http://api.yourdomain.com/usercenter/v1/ping
```

---

## 七、监控和维护

### 7.1 查看日志

```bash
# 查看特定 Pod 日志
kubectl logs -f <pod-name> -n flashsale-dev

# 查看最近 100 行
kubectl logs --tail=100 <pod-name> -n flashsale-dev

# 查看所有容器日志
kubectl logs -f deployment/usercenter-api -n flashsale-dev
```

### 7.2 重启服务

```bash
# 重启 Deployment
kubectl rollout restart deployment/usercenter-api -n flashsale-dev

# 查看重启状态
kubectl rollout status deployment/usercenter-api -n flashsale-dev
```

### 7.3 安装监控（可选）

```bash
# 安装 Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.retention=7d \
  --set prometheus.prometheusSpec.resources.requests.memory=512Mi \
  --set grafana.adminPassword=admin123

# 访问 Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# 浏览器打开: http://localhost:3000
# 用户名: admin
# 密码: admin123
```

---

## 八、常见问题

### 问题1: Pod 状态 ImagePullBackOff

```bash
# 原因: 镜像拉取失败
# 解决方案:

# 1. 检查 Secret 是否正确
kubectl get secret docker-registry-secret -n flashsale-dev -o yaml

# 2. 重新创建 Secret
kubectl delete secret docker-registry-secret -n flashsale-dev
kubectl create secret docker-registry docker-registry-secret \
  --docker-server=docker.io \
  --docker-username=用户名 \
  --docker-password=Token \
  --namespace=flashsale-dev

# 3. 检查镜像是否存在
docker pull docker.io/你的用户名/usercenter-api:latest
```

### 问题2: Pod 状态 CrashLoopBackOff

```bash
# 原因: 容器启动后崩溃
# 解决方案:

# 1. 查看日志
kubectl logs <pod-name> -n flashsale-dev

# 2. 查看详细信息
kubectl describe pod <pod-name> -n flashsale-dev

# 3. 常见原因:
# - 数据库连接失败（检查配置）
# - 端口占用
# - 配置文件错误
```

### 问题3: 无法远程访问 K8s API

```bash
# 原因: 防火墙阻止或 kubeconfig 配置错误
# 解决方案:

# 1. 检查防火墙
sudo ufw status
sudo ufw allow 6443/tcp

# 2. 检查 kubeconfig 中的 server 地址
cat ~/.kube/config-k3s | grep server

# 3. 测试端口连通性（在本地执行）
telnet 服务器IP 6443
# 或
nc -zv 服务器IP 6443
```

### 问题4: 存储空间不足

```bash
# 查看磁盘使用
df -h

# 清理未使用的镜像
kubectl delete pod -n kube-system -l job-name=helm-install-traefik

# 清理 Docker 镜像（在服务器上）
docker system prune -a -f

# 调整 PVC 大小（如果支持）
kubectl patch pvc mysql-pvc -n infra -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

### 问题5: 服务之间无法通信

```bash
# 测试网络连通性
kubectl run test --image=busybox --rm -it -- sh

# 在容器内测试:
ping mysql.infra.svc.cluster.local
nslookup mysql.infra.svc.cluster.local

# 如果无法解析，检查 CoreDNS:
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

## 九、资源优化建议

### 9.1 轻量配置（2核4G服务器）

如果服务器资源紧张，可以调整以下配置:

```yaml
# deploy/helm/values-dev.yaml

# 减少副本数
replicaCount: 1

# 降低资源请求
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"

# 基础设施也相应调整:
# - MySQL: 512Mi 内存
# - Redis: 256Mi 内存
# - Kafka: 1Gi 内存（或用外部 Kafka）
```

### 9.2 生产配置（4核8G服务器）

```yaml
# 增加副本数（高可用）
replicaCount: 2

# 合理资源配置
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

---

## 十、备份和恢复

### 10.1 备份数据库

```bash
# 导出数据库
kubectl exec -n infra deploy/mysql -- \
  mysqldump -uroot -pPXDN93VRKUm8TeE7 --all-databases > backup.sql

# 定期备份脚本（可选）
cat > /usr/local/bin/k8s-mysql-backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
kubectl exec -n infra deploy/mysql -- \
  mysqldump -uroot -pPXDN93VRKUm8TeE7 --all-databases \
  > /backup/mysql_$DATE.sql
# 保留最近7天的备份
find /backup -name "mysql_*.sql" -mtime +7 -delete
EOF

chmod +x /usr/local/bin/k8s-mysql-backup.sh

# 添加到 crontab（每天凌晨2点备份）
crontab -e
# 添加: 0 2 * * * /usr/local/bin/k8s-mysql-backup.sh
```

### 10.2 恢复数据库

```bash
# 导入数据库
kubectl exec -i -n infra deploy/mysql -- \
  mysql -uroot -pPXDN93VRKUm8TeE7 < backup.sql
```

---

## 十一、卸载和清理

### 11.1 卸载应用

```bash
# 删除应用
helm uninstall flashsale -n flashsale-dev

# 删除基础设施
kubectl delete namespace infra
kubectl delete namespace kafka
kubectl delete namespace monitoring
```

### 11.2 完全卸载 K3s

```bash
# 在服务器上执行
/usr/local/bin/k3s-uninstall.sh

# 清理残留文件
sudo rm -rf /var/lib/rancher
sudo rm -rf /etc/rancher
```

---

## 总结

完成以上步骤后，你的 K3s 集群已经就绪：

✅ K3s 单节点集群运行
✅ MySQL、Redis、Kafka 部署完成
✅ Nginx Ingress 配置完成
✅ CI/CD 集成配置完成
✅ 监控告警（可选）

**成本**：
- 服务器: ¥100-200/月（2核4G）
- 总计: ¥100-200/月

**下一步**:
1. 配置域名解析（可选）
2. 配置 HTTPS 证书（推荐）
3. 添加更多服务节点（扩容）
4. 集成日志收集（ELK/Loki）

有问题随时查看文档或提 Issue！
