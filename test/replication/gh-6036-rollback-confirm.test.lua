--
-- gh-6036: .
--
test_run = require('test_run').new()

test_run:cmd('create server master with script="replication/gh-6036-master.lua"')
test_run:cmd('create server replica with script="replication/gh-6036-replica.lua"')

test_run:cmd('start server master')
test_run:cmd('start server replica')

--
-- Connect master to the replica and write a record. Since the quorum
-- value is bigger than number of nodes in a cluster it will be rolled
-- back later.
test_run:switch('master')
box.cfg({                                       \
    replication = {                             \
            "unix/:./master.sock",              \
            "unix/:./replica.sock",             \
    },                                          \
})
_ = box.schema.create_space('sync', {is_sync = true})
_ = box.space.sync:create_index('pk')

--
-- Wait the record to appear on the master.
f = require('fiber').create(function() box.space.sync:replace{1} end)
test_run:wait_cond(function() return box.space.sync:get({1}) ~= nil end, 100)
box.space.sync:select{}

--
-- Wait the record from master get written and then
-- drop the replication.
test_run:switch('replica')
test_run:wait_cond(function() return box.space.sync:get({1}) ~= nil end, 100)
box.space.sync:select{}
box.cfg{replication = {}}

--
-- Then we jump back to the master and drop the replication,
-- thus unconfirmed record get rolled back.
test_run:switch('master')
box.cfg({                                       \
    replication = {},                           \
    replication_synchro_timeout = 0.001,        \
    election_mode = 'manual',                   \
})
while f:status() ~= 'dead' do require('fiber').sleep(0.1) end
test_run:wait_cond(function() return box.space.sync:get({1}) == nil end, 100)

--
-- Force the replica to become a RAFT leader.
test_run:switch('replica')
box.cfg({                                       \
    replication_synchro_quorum = 1,             \
    election_mode = 'manual'                    \
})
box.ctl.promote()
box.space.sync:select{}

--
-- Connect master back to the replica.
test_run:switch('master')
box.cfg({                                       \
    replication = {                             \
            "unix/:./replica.sock",             \
    },                                          \
})
box.space.sync:select{}

----
---- Connect replica back to the master.
--test_run:switch('replica')
--box.cfg({                                       \
--    replication = {                             \
--            "unix/:./master.sock",              \
--            "unix/:./replica.sock",             \
--    },                                          \
--})
--box.space.sync:select{}
--
test_run:switch('default')
test_run:cmd('stop server master')
--test_run:cmd('delete server master')
test_run:cmd('stop server replica')
--test_run:cmd('delete server replica')
