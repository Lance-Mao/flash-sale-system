# K3s 集群部署总结

   ## 部署完成时间
   ```
   日期: $(date)
   ```

   ## 集群信息
   - **K3s 版本**: v1.33.6+k3s1
   - **节点**: k3s-master (4核 8GB)
   - **服务器**: 海外服务器 (Ubuntu 24.04)

   ## 已部署组件

   ### ✅ 基础组件
   - [x] K3s 集群
   - [x] Nginx Ingress Controller
   - [x] Helm v3.19.4
   - [x] Strimzi Kafka Operator

   ### ✅ 基础设施 (infra namespace)
   - [x] MySQL 8.0.28 (10GB 存储)
   - [x] Redis (主从模式, 5GB 存储)
   - [x] Kafka 4.0.1 KRaft 模式 (5GB 存储)
   - [x] Kafka Topics: payment-update, order-update, pay-callback, close-order

   ### ✅ 数据库
   - [x] flashsale_usercenter
   - [x] flashsale_order
   - [x] flashsale_payment
   - [x] flashsale_product

   ### ✅ 命名空间
   - flashsale-dev (开发环境)
   - flashsale-prod (生产环境)
   - infra (基础设施)
   - kafka (Kafka 集群)
   - ingress-nginx (Ingress 控制器)

   ## 连接信息

   ### MySQL
   ```yaml
   host: mysql.infra.svc.cluster.local
   port: 3306
   username: root
   password: PXDN93VRKUm8TeE7
   ```

   ### Redis
   ```yaml
   host: redis-master.infra.svc.cluster.local
   port: 6379
   password: G62m50oigInC30sf
   ```

   ### Kafka
   ```yaml
   brokers: flashsale-kafka-kafka-bootstrap.kafka.svc.cluster.local:9092
   topics:
     - payment-update (3 partitions)
     - order-update (3 partitions)
     - pay-callback (3 partitions)
     - close-order (3 partitions)
   ```

   ## 常用命令

   ### 查看集群状态
   ```bash
   kubectl get nodes
   kubectl get pods -A
   kubectl top nodes
   ```

   ### 查看基础设施
   ```bash
   kubectl get pods -n infra
   kubectl get pods -n kafka
   kubectl get kafkatopics -n kafka
   ```

   ### 连接数据库
   ```bash
   # MySQL
   kubectl exec -it deploy/mysql -n infra -- mysql -uroot -pPXDN93VRKUm8TeE7

   # Redis
   kubectl exec -it redis-master-0 -n infra -- redis-cli -a G62m50oigInC30sf
   ```

   ### 端口转发
   ```bash
   # MySQL
   kubectl port-forward -n infra svc/mysql 3306:3306

   # Redis
   kubectl port-forward -n infra svc/redis-master 6379:6379
   ```

   ## 下一步

   1. **准备项目代码**
      ```bash
      cd /root
      git clone <your-repo-url> flash-sale-system
      ```

   2. **配置应用**
      - 编辑 deploy/helm/values-dev.yaml
      - 生成 JWT Secret: `openssl rand -base64 32`

   3. **部署应用**
      ```bash
      cd flash-sale-system
      helm upgrade --install flashsale ./deploy/helm \
        --namespace flashsale-dev \
        --values ./deploy/helm/values-dev.yaml
      ```

   4. **验证部署**
      ```bash
      kubectl get pods -n flashsale-dev
      kubectl logs -f <pod-name> -n flashsale-dev
      ```

   ## 故障排查

   ### 查看日志
   ```bash
   kubectl logs <pod-name> -n <namespace>
   kubectl logs -f <pod-name> -n <namespace>  # 实时日志
   kubectl describe pod <pod-name> -n <namespace>
   ```

   ### 查看事件
   ```bash
   kubectl get events -n <namespace> --sort-by='.lastTimestamp'
   ```

   ### 重启服务
   ```bash
   kubectl rollout restart deployment/<deployment-name> -n <namespace>
   ```

   ## 资源使用

   当前资源使用：
   - CPU: ~13% (523m/4核)
   - 内存: ~36% (2.9GB/8GB)
   - 磁盘: 1% (2.6GB/290GB)

   剩余资源充足，可以部署完整的微服务应用。

   ## 备份建议

   1. **定期备份数据库**
      ```bash
      kubectl exec -n infra deploy/mysql -- \
        mysqldump -uroot -pPXDN93VRKUm8TeE7 --all-databases > backup.sql
      ```

   2. **备份集群配置**
      ```bash
      sudo cat /etc/rancher/k3s/k3s.yaml > k3s-config-backup.yaml
      ```

   ## 文档位置
   - 部署文档: /root/project/k3s_deploy.md
   - 本文件: /root/k3s-deployment-summary.md