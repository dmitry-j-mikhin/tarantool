local INSTANCE_ID = string.match(arg[0], "gh%-6036%-(.+)%.lua")

local function unix_socket(name)
    return "unix/:./" .. name .. '.sock';
end

require('console').listen(os.getenv('ADMIN'))

if INSTANCE_ID == "master" then
    box.cfg({
        listen = unix_socket("master"),
        replication_connect_quorum = 0,
        election_mode = 'candidate',
        replication_synchro_quorum = 3,
        replication_synchro_timeout = 1000,
    })
elseif INSTANCE_ID == "replica" then
    box.cfg({
        listen = unix_socket("replica"),
        replication = {
            unix_socket("master"),
            unix_socket("replica")
        },
        read_only = true,
        election_mode = 'voter',
        replication_synchro_quorum = 2,
        replication_synchro_timeout = 1000,
    })
end

box.once("bootstrap", function()
    box.schema.user.grant('guest', 'super')
end)
