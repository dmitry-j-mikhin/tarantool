--
-- Using space:before_replace to resolve replication conflicts.
--
test_run = require('test_run').new()
engine = test_run:get_cfg('engine')

SERVERS = { 'before_replace1', 'before_replace2', 'before_replace3' }

-- Deploy a cluster.
test_run:create_cluster(SERVERS, "replication", {args="0.1"})
test_run:wait_fullmesh(SERVERS)

-- Setup space:before_replace trigger on all replicas.
-- The trigger favors tuples with a greater value.
test_run:cmd("setopt delimiter ';'")
test_run:cmd("switch before_replace1");
_ = box.space.test:before_replace(function(old, new)
    if old ~= nil and new ~= nil then
        return new[2] > old[2] and new or old
    end
end);
test_run:cmd("switch before_replace2");
_ = box.space.test:before_replace(function(old, new)
    if old ~= nil and new ~= nil then
        return new[2] > old[2] and new or old
    end
end);
test_run:cmd("switch before_replace3");
--
-- gh-2677 - test that an applier can not push() messages. Applier
-- session is available in Lua, so the test is here instead of
-- box/push.test.lua.
--
push_ok = nil
push_err = nil
_ = box.space.test:before_replace(function(old, new)
    if box.session.type() == 'applier' and not push_err then
        push_ok, push_err = box.session.push(100)
    end
    if old ~= nil and new ~= nil then
        return new[2] > old[2] and new or old
    end
end);
test_run:cmd("setopt delimiter ''");

-- Stall replication and generate incompatible data
-- on the replicas.
test_run:cmd("switch before_replace1")
box.error.injection.set('ERRINJ_RELAY_TIMEOUT', 0.01)
for i = 1, 10 do box.space.test:replace{i, i % 3 == 1 and i * 10 or i} end
test_run:cmd("switch before_replace2")
box.error.injection.set('ERRINJ_RELAY_TIMEOUT', 0.01)
for i = 1, 10 do box.space.test:replace{i, i % 3 == 2 and i * 10 or i} end
test_run:cmd("switch before_replace3")
box.error.injection.set('ERRINJ_RELAY_TIMEOUT', 0.01)
for i = 1, 10 do box.space.test:replace{i, i % 3 == 0 and i * 10 or i} end

-- Synchronize.
test_run:cmd("switch default")
vclock = test_run:get_cluster_vclock(SERVERS)
vclock2 = test_run:wait_cluster_vclock(SERVERS, vclock)

-- Check that all replicas converged to the same data
-- and the state persists after restart.
test_run:cmd("switch before_replace1")
box.space.test:select()
test_run:cmd('restart server before_replace1 with args="0.1 0.5"')
box.space.test:select()
test_run:cmd("switch before_replace2")
box.space.test:select()
test_run:cmd('restart server before_replace2 with args="0.1 0.5"')
box.space.test:select()
test_run:cmd("switch before_replace3")
box.space.test:select()
push_err
test_run:cmd('restart server before_replace3 with args="0.1 0.5"')
box.space.test:select()

-- Cleanup.
test_run:cmd("switch default")
test_run:drop_cluster(SERVERS)
test_run:cleanup_cluster()

--
-- gh-3722: Check that when space:before_replace trigger modifies
-- the result of a replicated operation, it writes it to the WAL
-- with the original replica id and lsn.
--
_ = box.schema.space.create('test', {engine = engine})
_ = box.space.test:create_index('primary')

box.schema.user.grant('guest', 'replication')

test_run:cmd("create server before_replace_gh3722 with rpl_master=default, script='replication/replica.lua'")
test_run:cmd("start server before_replace_gh3722")

test_run:cmd("switch before_replace_gh3722")
_ = box.space.test:before_replace(function(old, new) return new:update{{'+', 2, 1}} end)

test_run:cmd("switch default")
box.space.test:replace{1, 1}

_ = test_run:wait_vclock('before_replace_gh3722', test_run:get_vclock('default'))

-- Check that replace{1, 2} coming from the master was suppressed
-- by the before_replace trigger on the replica.
test_run:cmd("switch before_replace_gh3722")
box.space.test:select() -- [1, 2]

-- Check that master's component of replica's vclock was bumped
-- so that the replica doesn't apply replace{1, 2} after restart
-- while syncing with the master.
test_run:cmd("restart server before_replace_gh3722")
box.space.test:select() -- [1, 2]

test_run:cmd("switch default")
test_run:cmd("stop server before_replace_gh3722")
test_run:cmd("cleanup server before_replace_gh3722")
test_run:cmd("delete server before_replace_gh3722")
test_run:cleanup_cluster()

box.schema.user.revoke('guest', 'replication')
box.space.test:drop()
