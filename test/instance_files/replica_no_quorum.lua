#!/usr/bin/env tarantool
local SOCKET_DIR = require('fio').cwd()
local alias = os.getenv('TARANTOOL_ALIAS')
os.execute('rm ready_' .. alias)
box.cfg({
    work_dir = os.getenv('TARANTOOL_WORKDIR'),
    listen              = SOCKET_DIR .. '/no_quorum.sock',
    replication = SOCKET_DIR .. '/quorum_master.sock',
    memtx_memory        = 107374182,
    replication_connect_quorum = 0,
    replication_timeout = 0.1,
})

pwd = os.environ()["PWD"]
os.execute('touch ' .. pwd .. '/ready_' .. alias)
