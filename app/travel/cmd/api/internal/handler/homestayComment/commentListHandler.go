package homestayComment

import (
	"net/http"

	"flashsale/app/travel/cmd/api/internal/logic/homestayComment"
	"flashsale/app/travel/cmd/api/internal/svc"
	"flashsale/app/travel/cmd/api/internal/types"
	"flashsale/pkg/result"

	"github.com/zeromicro/go-zero/rest/httpx"
)

func CommentListHandler(ctx *svc.ServiceContext) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var req types.CommentListReq
		if err := httpx.Parse(r, &req); err != nil {
			result.ParamErrorResult(r, w, err)
			return
		}

		l := homestayComment.NewCommentListLogic(r.Context(), ctx)
		resp, err := l.CommentList(req)
		result.HttpResult(r, w, resp, err)
	}
}
