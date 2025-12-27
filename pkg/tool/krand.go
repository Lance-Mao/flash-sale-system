package tool

import (
	"crypto/rand"
	"math/big"
)

const (
	KC_RAND_KIND_NUM   = 0 // 纯数字
	KC_RAND_KIND_LOWER = 1 // 小写字母
	KC_RAND_KIND_UPPER = 2 // 大写字母
	KC_RAND_KIND_ALL   = 3 // 数字、大小写字母
)

// Krand generates a random string of specified size and kind
// Use crypto/rand for secure random number generation
func Krand(size, kind int) string {
	ikind, kinds, result := kind, [][]int{{10, 48}, {26, 97}, {26, 65}}, make([]byte, size)
	isAll := kind > 2 || kind < 0

	for i := 0; i < size; i++ {
		if isAll { // random ikind
			n, err := rand.Int(rand.Reader, big.NewInt(3))
			if err != nil {
				// Fallback to 0 if random generation fails
				ikind = 0
			} else {
				ikind = int(n.Int64())
			}
		}
		scope, base := kinds[ikind][0], kinds[ikind][1]
		n, err := rand.Int(rand.Reader, big.NewInt(int64(scope)))
		if err != nil {
			// Fallback to base if random generation fails
			result[i] = uint8(base)
		} else {
			result[i] = uint8(base + int(n.Int64()))
		}
	}
	return string(result)
}
