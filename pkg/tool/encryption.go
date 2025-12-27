package tool

import (
	"crypto/md5" //nolint:gosec // G501: MD5 is weak but used for legacy compatibility
	"fmt"
	"io"
)

/** 加密方式 **/

// Md5ByString computes MD5 hash of a string
// WARNING: MD5 is cryptographically broken and should not be used for security purposes
// This function is kept for backward compatibility only
// TODO: Migrate to bcrypt or argon2 for password hashing
//
//nolint:gosec // G401: MD5 is weak but used for legacy compatibility
func Md5ByString(str string) string {
	m := md5.New()
	_, err := io.WriteString(m, str)
	if err != nil {
		panic(err)
	}
	arr := m.Sum(nil)
	return fmt.Sprintf("%x", arr)
}

// Md5ByBytes computes MD5 hash of bytes
// WARNING: MD5 is cryptographically broken and should not be used for security purposes
// This function is kept for backward compatibility only
//
//nolint:gosec // G401: MD5 is weak but used for legacy compatibility
func Md5ByBytes(b []byte) string {
	return fmt.Sprintf("%x", md5.Sum(b))
}
