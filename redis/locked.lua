-- redis.replicate_commands();

local unique_digest = KEYS[1]
local wait_key      = KEYS[2]
local work_key      = KEYS[3]
local exists_key    = KEYS[4]
local grabbed_key   = KEYS[5]
local available_key = KEYS[6]
local version_key   = KEYS[7]
local unique_set    = KEYS[8]

local job_id    = ARGV[1]

redis.log(redis.LOG_DEBUG, "locked.lua - Is unique_digest: " .. unique_digest .. " locked by job_id: " .. job_id .. "?")

if redis.call('GET', unique_digest) == job_id then
  redis.log(redis.LOG_DEBUG, "locked.lua - locked with unique_digest")
  return 1
end

if redis.call('GET', exists_key) == job_id then
  redis.log(redis.LOG_DEBUG, "locked.lua - locked with exists_key")
  return 2
end

if redis.call('HGET', grabbed_key, job_id) then
  redis.log(redis.LOG_DEBUG, "locked.lua - locked with grabbed_key")
  return 3
end

return -1
