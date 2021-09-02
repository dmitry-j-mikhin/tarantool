env = require('test_run')
net_box = require('net.box')
fiber = require('fiber')
test_run = env.new()
test_run:cmd("create server test with script=\
              'box/gh-5645-several-iproto-threads.lua'")

test_run:cmd("setopt delimiter ';'")
function iproto_call(server_addr, fibers_count)
    local fibers = {}
    for i = 1, fibers_count do
        fibers[i] = fiber.new(function()
            local conn = net_box.new(server_addr)
            for _ = 1, 100 do
                pcall(conn.call, conn, 'ping')
            end
            conn:close()
        end)
        fibers[i]:set_joinable(true)
    end
    for _, f in ipairs(fibers) do
        f:join()
    end
end;
function get_network_stat_using_call()
    local net_stat_table = test_run:cmd(
        string.format("eval test 'return box.stat.net()'")
    )[1]
    assert(net_stat_table ~= nil)
    local connections = net_stat_table.CONNECTIONS.total
    local requests = net_stat_table.REQUESTS.total
    local sent = net_stat_table.SENT.total
    local received = net_stat_table.RECEIVED.total
    return connections, requests, sent, received
end;
function get_network_stat_for_thread_using_call(thread_number)
    local net_stat_table = test_run:cmd(
        string.format("eval test 'return box.stat.net.thread()'")
    )[1]
    assert(net_stat_table ~= nil)
    local connections = net_stat_table[thread_number].CONNECTIONS.total
    local requests = net_stat_table[thread_number].REQUESTS.total
    local sent = net_stat_table[thread_number].SENT.total
    local received = net_stat_table[thread_number].RECEIVED.total
    return connections, requests, sent, received
end;
function get_network_stat_using_index()
    local connections = test_run:cmd(string.format(
        "eval test 'return box.stat.net.CONNECTIONS.total'")
    )[1]
    local requests = test_run:cmd(string.format(
        "eval test 'return box.stat.net.REQUESTS.total'")
    )[1]
    local sent = test_run:cmd(string.format(
        "eval test 'return box.stat.net.SENT.total'")
    )[1]
    local received = test_run:cmd(string.format(
        "eval test 'return box.stat.net.RECEIVED.total'")
    )[1]
    return connections, requests, sent, received
end;
function get_network_stat_for_thread_using_index(thread_number)
    local connections = test_run:cmd(string.format(
        "eval test 'return box.stat.net.thread[%d].CONNECTIONS.total'",
        thread_number
    ))[1]
    local requests = test_run:cmd(string.format(
        "eval test 'return box.stat.net.thread[%d].REQUESTS.total'",
        thread_number
    ))[1]
    local sent = test_run:cmd(string.format(
        "eval test 'return box.stat.net.thread[%d].SENT.total'",
        thread_number
    ))[1]
    local received = test_run:cmd(string.format(
        "eval test 'return box.stat.net.thread[%d].RECEIVED.total'",
        thread_number
    ))[1]
    return connections, requests, sent, received
end;
test_run:cmd("setopt delimiter ''");

-- Check that we can't start server with iproto threads count <= 0 or > 1000
-- We can't pass '-1' or another negative number as argument, so we pass string
opts = {}
opts.filename = 'gh-5645-several-iproto-threads.log'
test_run:cmd("start server test with args='negative' with crash_expected=True")
test_run:cmd("setopt delimiter ';'")
assert(test_run:grep_log(
    "test", "Incorrect value for option 'iproto_threads'", nil, opts) ~= nil
);
test_run:cmd("setopt delimiter ''");
test_run:cmd("start server test with args='0' with crash_expected=True")
test_run:cmd("setopt delimiter ';'")
assert(test_run:grep_log(
    "test", "Incorrect value for option 'iproto_threads'", nil, opts) ~= nil
);
test_run:cmd("setopt delimiter ''");
test_run:cmd("start server test with args='1001' with crash_expected=True")
test_run:cmd("setopt delimiter ';'")
assert(test_run:grep_log(
    "test", "Incorrect value for option 'iproto_threads'", nil, opts) ~= nil
);
test_run:cmd("setopt delimiter ''");

-- We check that statistics gathered per each thread in sum is equal to
-- statistics gathered from all threads.
thread_count = 2
fibers_count = 100
test_run:cmd(string.format("start server test with args=\"%s\"", thread_count))
test_run:switch("test")
function ping() return "pong" end
test_run:switch("default")

server_addr = test_run:cmd("eval test 'return box.cfg.listen'")[1]
iproto_call(server_addr, fibers_count)
-- Total statistics from all threads.
test_run:cmd("setopt delimiter ';'")
conn_t_call, req_t_call, sent_t_call, rec_t_call =
    get_network_stat_using_call();
conn_t_index, req_t_index, sent_t_index, rec_t_index =
    get_network_stat_using_index();
assert(conn_t_call == conn_t_index and req_t_call == req_t_index and
       sent_t_call == sent_t_index and rec_t_call == rec_t_index);
test_run:cmd("setopt delimiter ''");
-- Statistics per thread.
conn, req, sent, rec = 0, 0, 0, 0
assert(conn_t_call == fibers_count)

test_run:cmd("setopt delimiter ';'")
for thread_number = 1, thread_count do
    local conn_c_call, req_c_call, sent_c_call, rec_c_call =
        get_network_stat_for_thread_using_call(thread_number)
    local conn_c_index, req_c_index, sent_c_index, rec_c_index =
        get_network_stat_for_thread_using_index(thread_number)
    assert(conn_c_call == conn_c_index and req_c_call == req_c_index and
           sent_c_call == sent_c_index and rec_c_call == rec_c_index)
    conn = conn + conn_c_call
    req = req + req_c_call
    sent = sent + sent_c_call
    rec = rec + rec_c_call
end;
test_run:cmd("setopt delimiter ''");
assert(conn_t_call == conn)
assert(req_t_call == req)
assert(sent_t_call == sent)
assert(rec_t_call == rec)

test_run:cmd("stop server test")
test_run:cmd("cleanup server test")
test_run:cmd("delete server test")
