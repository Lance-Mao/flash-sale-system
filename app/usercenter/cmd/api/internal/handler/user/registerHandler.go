package user

import (
	"net/http"

	"github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/logic/user"
	"github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/svc"
	"github.com/Lance-Mao/flash-sale-system/app/usercenter/cmd/api/internal/types"
	"github.com/Lance-Mao/flash-sale-system/pkg/result"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func RegisterHandler(ctx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.RegisterReq
		if err := httpx.Parse(r, &req); err != nil {
			result.ParamErrorResult(r, w, err)
			return
		}

		l := user.NewRegisterLogic(r.Context(), ctx)
		resp, err := l.Register(req)
		result.HttpResult(r, w, resp, err)
	}
}
