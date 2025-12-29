// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package health

import (
	"context"

	"github.com/Lance-Mao/flash-sale-system/app/travel/cmd/api/internal/svc"
	"github.com/Lance-Mao/flash-sale-system/app/travel/cmd/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type HealthCheckLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

// health check
func NewHealthCheckLogic(ctx context.Context, svcCtx *svc.ServiceContext) *HealthCheckLogic {
	return &HealthCheckLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *HealthCheckLogic) HealthCheck() (resp *types.HealthCheckResp, err error) {
	// Simple health check - just return OK
	// Can be extended to check database, redis, etc.
	return &types.HealthCheckResp{
		Status: "ok",
	}, nil
}
