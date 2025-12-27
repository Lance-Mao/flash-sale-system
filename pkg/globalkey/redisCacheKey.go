package globalkey

/**
redis key except "model cache key"  in here,
but "model cache key" in model
*/

// CacheUserTokenKey /** 用户登陆的token
//
//nolint:gosec // G101: This is a Redis key template, not a hardcoded credential
const CacheUserTokenKey = "user_token:%d"
