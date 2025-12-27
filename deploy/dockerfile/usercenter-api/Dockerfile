# 多阶段构建 - 以 usercenter-api 为例
# Stage 1: 构建阶段
FROM golang:1.22-alpine AS builder

# 设置工作目录
WORKDIR /app

# 安装必要工具
RUN apk add --no-cache git make

# 复制依赖文件
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建二进制文件
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=$(git describe --tags --always) -X main.buildTime=$(date -u '+%Y-%m-%d_%H:%M:%S')" \
    -o /app/bin/usercenter-api \
    app/usercenter/cmd/api/usercenter.go

# Stage 2: 运行阶段
FROM alpine:3.19

# 安装必要的运行时依赖
RUN apk add --no-cache ca-certificates tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata

# 创建非 root 用户
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/bin/usercenter-api ./
COPY --from=builder /app/app/usercenter/cmd/api/etc ./etc

# 修改权限
RUN chown -R app:app /app

# 切换到非 root 用户
USER app

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:1004/healthz || exit 1

EXPOSE 1004 4008

CMD ["./usercenter-api", "-f", "etc/usercenter.yaml"]
