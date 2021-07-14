#!/usr/bin/env tarantool
local alias = os.getenv('TARANTOOL_ALIAS')
os.execute('rm ready_' .. alias)
local workdir = os.getenv('TARANTOOL_WORKDIR')
local listen = os.getenv('TARANTOOL_LISTEN')

box.cfg({
    work_dir = workdir,
--     listen = 'localhost:3310'
    listen = listen
})

box.schema.user.grant('guest', 'read,write,execute,create', 'universe')

pwd = os.environ()["PWD"]
os.execute('touch ' .. pwd .. '/ready_' .. alias)
