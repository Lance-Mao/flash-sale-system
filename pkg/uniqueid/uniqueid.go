package uniqueid

import (
	"math"

	"github.com/sony/sonyflake"
	"github.com/zeromicro/go-zero/core/logx"
)

var flake *sonyflake.Sonyflake

func init() {
	flake = sonyflake.NewSonyflake(sonyflake.Settings{})
}

func GenId() int64 {

	id, err := flake.NextID()
	if err != nil {
		logx.Severef("flake NextID failed with %s \n", err)
		panic(err)
	}

	// Check for overflow before converting to int64
	if id > math.MaxInt64 {
		logx.Severef("generated ID %d exceeds int64 max value", id)
		panic("ID overflow")
	}

	return int64(id) //nolint:gosec // G115: Checked for overflow above
}
