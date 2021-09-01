net = require('net.box')
fiber = require('fiber')
test_run = require('test_run').new()

box.schema.user.grant('guest', 'execute', 'universe')
old_readahead = box.cfg.readahead
old_net_msg_max = box.cfg.net_msg_max

--
-- Check that tarantool process all requests when connection is closing,
-- net_msg_max limit is reached and readahead limit is not reached:
--
box.cfg ({ net_msg_max = 2, readahead = 4 * old_readahead })
counter = 0
expected_counter = old_net_msg_max * 5
conn = net.connect(box.cfg.listen)
for i = 1, expected_counter do \
    conn:eval('counter = counter + 1', {}, {is_async = true}) \
end
conn:close()
test_run:wait_cond(function() return box.stat.net().CONNECTIONS.current == 0 end)
test_run:wait_cond(function() return box.stat.net().REQUESTS.current == 0 end)
assert(counter == expected_counter) -- (because all requests have been executed)

--
-- Check that tarantool process all requests when connection is closing
-- readahead limit is reached and net_msg_max limit is not reached:
--
box.cfg ({ net_msg_max = 4 * old_net_msg_max, readahead = 128 })
counter = 0
expected_counter = old_net_msg_max
conn = net.connect(box.cfg.listen)
for i = 1, expected_counter do \
    conn:eval('counter = counter + 1', {}, {is_async = true}) \
end
conn:close()
test_run:wait_cond(function() return box.stat.net().CONNECTIONS.current == 0 end)
test_run:wait_cond(function() return box.stat.net().REQUESTS.current == 0 end)
assert(counter == expected_counter) -- (because all requests have been executed)

--
-- Check that tarantool process all requests when connection is closing
-- and readahead and net_msg_max limit is reached:
--
box.cfg ({ net_msg_max = 2, readahead = 128 })
counter = 0
expected_counter = old_net_msg_max * 5
conn = net.connect(box.cfg.listen)
for i = 1, expected_counter do \
    conn:eval('counter = counter + 1', {}, {is_async = true}) \
end
conn:close()
test_run:wait_cond(function() return box.stat.net().CONNECTIONS.current == 0 end)
test_run:wait_cond(function() return box.stat.net().REQUESTS.current == 0 end)
assert(counter == expected_counter) -- (because all requests have been executed)

box.cfg ({ net_msg_max = old_net_msg_max, readahead = old_readahead })
box.schema.user.revoke('guest', 'execute', 'universe')
