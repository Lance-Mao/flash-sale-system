// Code scaffolded by goctl. Safe to edit.
// goctl 1.9.2

package health

import (
	"net/http"

	"github.com/Lance-Mao/flash-sale-system/app/order/cmd/api/internal/logic/health"
	"github.com/Lance-Mao/flash-sale-system/app/order/cmd/api/internal/svc"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// health check
func HealthCheckHandler(svcCtx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		l := health.NewHealthCheckLogic(r.Context(), svcCtx)
		resp, err := l.HealthCheck()
		if err != nil {
			httpx.ErrorCtx(r.Context(), w, err)
		} else {
			httpx.OkJsonCtx(r.Context(), w, resp)
		}
	}
}
