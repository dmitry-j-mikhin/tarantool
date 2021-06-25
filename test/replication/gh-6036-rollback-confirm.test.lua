--
-- gh-6036: .
--
test_run = require('test_run').new()

test_run:cmd('create server master with script="replication/gh-6036-master.lua"')
test_run:cmd('create server replica with script="replication/gh-6036-replica.lua"')

test_run:cmd('start server master')
test_run:cmd('start server replica')

-- step 1 & 2
test_run:switch('master')
box.cfg({                                       \
    replication = {                             \
            "unix/:./master.sock",              \
            "unix/:./replica.sock",             \
    },                                          \
})
_ = box.schema.create_space('sync', {is_sync = true})
_ = box.space.sync:create_index('pk')
box.info()

-- step 3
f = require('fiber').create(function() box.space.sync:replace{1} end)
box.space.sync:select{}

test_run:switch('replica')
-- step 4
box.cfg{replication = {}}
box.info()

test_run:switch('master')
-- step 5
box.cfg({                                       \
    replication = {},                           \
    replication_synchro_timeout = 0.001,        \
    election_mode = 'manual',                   \
})
box.info()
while f:status() ~= 'dead' do fiber.sleep(0.1) end
box.space.sync:select{}

test_run:switch('replica')
--step 6
box.cfg({                                       \
    replication_synchro_quorum = 1,             \
    election_mode = 'manual'                    \
})
box.ctl.promote()
box.space.sync:select{}
box.info()

test_run:switch('master')
box.cfg({                                       \
    replication = {                             \
            "unix/:./master.sock",              \
            "unix/:./replica.sock",             \
    },                                          \
})
box.info()

test_run:switch('default')
test_run:cmd('stop server master')
--test_run:cmd('delete server master')
test_run:cmd('stop server replica')
--test_run:cmd('delete server replica')
