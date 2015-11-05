require "splay.base"
crypto = require "crypto"
rpc = require "splay.urpc"
-- to use TCP RPC, replace previous by the following line
-- rpc = require"splay.rpc"

function generate_id(nn)
    local concat = nn.ip .. ':' .. nn.port
    return tonumber(string.sub(crypto.evp.new('sha1'):digest(concat), 1, m / 4), 16)
end

-- addition to allow local run
if not job then
    -- can NOT be required in SPLAY deployments !
    local utils = require("splay.utils")
    if #arg < 2 then
        print("lua " .. arg[0] .. " my_position nb_nodes")
        os.exit()
    else
        local pos, total = tonumber(arg[1]), tonumber(arg[2])
        job = utils.generate_job(pos, total, 20001)
    end
end

rpc.server(job.me.port)


-- constants
max_time = 150 -- we do not want to run forever ...
max_initial_delay = 10
m = 32 -- size of ID in bits

-- variables
n = job.me
n.id = generate_id(n)
successor = nil
predecessor = nil

--functions

function get_predecessor()
    return predecessor
end

function get_successor()
    return successor
end

function set_predecessor(pred)
    predecessor = pred
end

function set_successor(succ)
    successor = succ
end

function find_predecessor(id)
    local nn = n
    local nn_successor = successor
    local i = 1
    log:print('Begin while')
    while (id <= nn.id or id > nn_successor.id) and nn.id < nn_successor.id do
        i = i + 1
        log:print(id .. ' ' .. nn.id .. ' ' .. nn_successor.id)
        nn = nn_successor
        nn_successor = rpc.call(nn, {'get_successor'})
    end
    log:print('End while')
    return nn
end

function find_successor(id)
    local nn = find_predecessor(id)
    local nn_successor = rpc.call(nn, {'get_successor'})
    return nn_successor
end

function init_neighbors(nn)
    log:print('Node ' .. n.id .. ': init_neighbors using ' .. nn.id)
    local param = (n.id + 1) % (2 ^ m)
    successor = rpc.call(nn, {'find_successor', param})
    predecessor = rpc.call(successor, {'get_predecessor'})
    rpc.call(successor, {'set_predecessor', n})
    rpc.call(predecessor, {'set_successor', n})
    log:print('Node ' .. n.id .. ': init_neighbors end')
end

function join(nn)
    if nn then
        init_neighbors(nn)
    else
        log:print('Node ' .. n.id .. ': successor = n, predecessor = n')
        successor = n
        predecessor = n
    end
end


thing = false
function test()
    if thing == false then
        thing = true
        log:print('Test, node ' .. job.position .. ' has ' .. successor.id .. ' as successor')
        rpc.call(successor, {'test'})
    end
end

--
--
--
--
--

-- helping functions
function terminator()
    events.sleep(max_time)
    log:print("FINAL: node " .. job.position)
    os.exit()
end

function main()
    -- init random number generator
    math.randomseed(job.position * os.time())
    -- wait for all nodes to start up (conservative)
    events.sleep(2)
    -- desynchronize the nodes
    local desync_wait = (max_initial_delay * math.random())
    --

    if job.position == 1 then
        desync_wait = 0
    end
    log:print("waiting for " .. desync_wait .. " to desynchronize")
    events.sleep(desync_wait)

    if job.position == 1 then
        join(nil)
        events.sleep(max_initial_delay * 3)
        rpc.call(successor, {'test'})
    else
        local initial_partner = job.nodes()[1]
        initial_partner.id = generate_id(initial_partner)
        join(initial_partner)
    end

    -- this thread will be in charge of killing the node after max_time seconds
    events.thread(terminator)
end

events.thread(main)
events.run()
