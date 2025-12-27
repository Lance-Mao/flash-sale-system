package svc

import (
	"github.com/hibiken/asynq"
	"github.com/Lance-Mao/flash-sale-system/app/order/cmd/rpc/internal/config"
	"github.com/Lance-Mao/flash-sale-system/app/order/model"
	"github.com/Lance-Mao/flash-sale-system/app/travel/cmd/rpc/travel"

	"github.com/zeromicro/go-zero/core/stores/sqlx"
	"github.com/zeromicro/go-zero/zrpc"
)

type ServiceContext struct {
	Config config.Config
	AsynqClient *asynq.Client

	TravelRpc travel.Travel

	HomestayOrderModel model.HomestayOrderModel
}

func NewServiceContext(c config.Config) *ServiceContext {
	return &ServiceContext{
		Config: c,
		AsynqClient:newAsynqClient(c),

		TravelRpc: travel.NewTravel(zrpc.MustNewClient(c.TravelRpcConf)),

		HomestayOrderModel: model.NewHomestayOrderModel(sqlx.NewMysql(c.DB.DataSource), c.Cache),
	}
}
