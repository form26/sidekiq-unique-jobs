-- redis.replicate_commands();
local unique_digest  = keys[1]

local exists_key        = unique_digest .. ':EXISTS'
local grabbed_key       = unique_digest .. ':GRABBED'
local available_key     = unique_digest .. ':AVAILABLE'
local version_key       = unique_digest .. ':VERSION'
local run_exists_key    = unique_digest .. ':RUN:EXISTS'
local run_grabbed_key   = unique_digest .. ':RUN:GRABBED'
local run_available_key = unique_digest .. ':RUN:AVAILABLE'
local run_version_key   = unique_digest .. ':RUN:VERSION'

redis.call('SREM', unique_key, unique_digest)
redis.call('DEL', exists_key)
redis.call('DEL', grabbed_key)
redis.call('DEL', available_key)
redis.call('DEL', version_key)
redis.call('DEL', run_exists_key)
redis.call('DEL', run_grabbed_key)
redis.call('DEL', run_available_key)
redis.call('DEL', run_version_key)
