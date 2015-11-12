require "splay.base"
crypto = require "crypto"
rpc = require "splay.urpc"
-- to use TCP RPC, replace previous by the following line
-- rpc = require"splay.rpc"

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
max_initial_delay = 20
m = 28 -- size of ID in bits. max 30, as Lua's math.random goes up to 2^31 -1 only
number_of_queries = 500

function generate_id(nn)
    local concat = nn.ip .. ':' .. nn.port
    return tonumber(string.sub(crypto.evp.new('sha1'):digest(concat), 1, m / 4), 16)
end

-- variables
n = job.me
n.id = generate_id(n)
finger = {}
predecessor = nil

-- initializer
for k = 1, m do
    finger[k] = { node = nil, start = (n.id + 2 ^(k-1)) % 2^m }
end

--functions

function get_predecessor()
    return predecessor
end

function get_successor()
    return finger[1].node
end

function set_predecessor(pred)
    predecessor = pred
end

function set_successor(succ)
    finger[1].node = succ
end

function not_in_range_oc(value, start, finish)
    return (start < finish and (value <= start or value > finish)) or
    (start >= finish and not ((value > start and value > finish) or (value < start and value < finish)))
end

function in_range_co(value, start, finish)
    return (start < finish and (value >= start and value < finish)) or
    (start >= finish and ((value >= start and value > finish) or (value < start and value < finish)))
end

function in_range_oo(value, start, finish)
    return (start < finish and (value > start and value < finish)) or
            (start >= finish and ((value > start and value > finish) or (value < start and value < finish)))
end

function closest_preceding_finger(id)
    for i = m, 1, -1 do
        if in_range_oo(finger[i].node.id, n.id, id) then
            return finger[i].node
        end
    end
end

function find_predecessor(id)
    local nn = n
    local nn_successor = get_successor()
    local hops = 0
    --log:print('Begin while')
    while not_in_range_oc(id, nn.id, nn_successor.id) do
        --log:print(id .. ' ' .. nn.id .. ' ' .. nn_successor.id)
        nn = rpc.call(nn, {'closest_preceding_finger', id})
        nn_successor = rpc.call(nn, {'get_successor'})
        hops = hops + 1
    end
    --log:print('End while')
    return nn, hops
end

function find_successor(id)
    local nn = find_predecessor(id)
    local nn_successor = rpc.call(nn, {'get_successor'})
    return nn_successor
end

function init_finger_table(nn)
    log:print('Node ' .. n.id .. ': init_finger_table using ' .. nn.id)
    finger[1].node = rpc.call(nn, {'find_successor', finger[1].start})
    predecessor = rpc.call(get_successor(), {'get_predecessor'})

    for i = 1, m-1 do
        if in_range_co(finger[i + 1].start, n.id, finger[i].node.id) then
            finger[i + 1].node = finger[i].node
        else
            finger[i + 1].node = rpc.call(nn, {'find_successor', finger[i + 1].start})
        end
    end

    log:print('Node ' .. n.id .. ': init_finger_table end')
end

function update_finger_table(s, i)
    if finger[i].start ~= finger[i].node.id and in_range_co(s.id, finger[i].start, finger[i].node.id) then
        finger[i].node = s
        local p = get_predecessor()
        rpc.call(p, {'update_finger_table', s, i})
    end
end

function update_others()
    rpc.call(get_successor(), {'set_predecessor', n})
    for i = 1, m do
        local p = find_predecessor((n.id + 1 - 2 ^(i-1)) % 2^m)
        rpc.call(p, {'update_finger_table', n, i})
    end
end

function join(nn)
    if nn then
        init_finger_table(nn)
        predecessor = rpc.call(get_successor(), {'get_predecessor'})
        update_others()
    else
        for i = 1, m do
            finger[i].node = n
        end
        predecessor = n
    end
end


thing = false
function test()
    if thing == false then
        thing = true
        log:print('Test, node ' .. job.position .. ' has ' .. get_successor().id .. ' as successor')
        rpc.call(get_successor(), {'test'})
    end
end

function do_query()
    math.randomseed(job.position * os.time())
    for i = 1,number_of_queries do
        local key = math.random(0, 2 ^ m)
        local _, hops = find_predecessor(key)
        log:print('hops_for_query ' .. hops)
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
    else
        local initial_partner = job.nodes()[1]
        initial_partner.id = generate_id(initial_partner)
        join(initial_partner)
    end

    events.sleep(max_initial_delay * 3)
    do_query()

    -- this thread will be in charge of killing the node after max_time seconds
    events.thread(terminator)
end

events.thread(main)
events.run()
