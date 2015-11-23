require "splay.base"
crypto = require "crypto"
rpc = require "splay.urpc"
-- to use TCP RPC, replace previous by the following line
-- rpc = require"splay.rpc"

cluster = true
-- addition to allow local run
if not job then
    cluster = false
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
rpc.settings.default_timeout = 3

-- constants
max_time = 1200 -- we do not want to run forever ...
max_initial_delay = 6
fix_finger_period = 5
check_stale_period = 10
test_ring_period = 40
stabilize_period = 3
queries_aggregation_size = 2000
number_of_queries = 32000
do_query_period = 5
root_node_id = 2
m = 28 -- size of ID in bits. max 30, as Lua's math.random goes up to 2^31 -1 only

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

function first_node()
    if cluster then
        local partner = job.nodes[root_node_id]
        -- Fallback mechanism if node 1 does not exist anymore
        if not partner then
            log:print("Root node is nil, trying other nodes")
            for k, v in ipairs(job.nodes) do
                if v then
                    partner = v
                    break
                end
            end
        end
        if partner then
            return partner
        else
            log:print("All nodes in job.nodes are nil!")
            return n
        end
    else
        return job.nodes()[root_node_id]
    end
end

function get_predecessor()
    return predecessor
end

function get_successor()
    return finger[1].node
end

function set_predecessor(pred)
    if pred then
        predecessor = pred
    else
        log:print("Attempting to set predecessor to nil, ignoring")
    end
end

function set_successor(succ)
    if succ then
        finger[1].node = succ
    else
        log:print("Attempting to set successor to nil, ignoring")
    end
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
        if finger[i].node and in_range_oo(finger[i].node.id, n.id, id) and rpc.ping(finger[i].node, 1) then
            return finger[i].node
        end
    end
end

function find_predecessor(id)
    local nn = n
    local nn_successor = get_successor()
    local hops = 0

    --log:print('Begin while')
    while nn and nn_successor and not_in_range_oc(id, nn.id, nn_successor.id) do
        --log:print(id .. ' ' .. nn.id .. ' ' .. nn_successor.id)
        nn = rpc.call(nn, {'closest_preceding_finger', id})
        nn_successor = rpc.call(nn, {'get_successor'})
        hops = hops + 1
    end
    --log:print('End while')
    if nn and nn_successor then
        return nn, hops
    else
        return nil, -1
    end
end

function find_successor(id)
    local nn = find_predecessor(id)
    local nn_successor = rpc.call(nn, {'get_successor'})
    return nn_successor
end

function join(nn)
    if nn then
        predecessor = nil
        local succ
        while not succ do
            succ = rpc.call(nn, {'find_successor', n.id})
            if not succ then
                events.sleep(2)
            end
        end
        set_successor(succ)
    else
        set_successor(n)
        set_predecessor(n)
    end
end

function stabilize()
    local succ = get_successor()
    if succ then
        local x = rpc.call(succ, {'get_predecessor'})
        if x and in_range_oo(x.id, n.id, succ.id) then
            succ = x
            set_successor(x)
        end
        rpc.call(succ, {'notify', n})
    end
end

function notify(nn)
    if get_predecessor() == nil or in_range_oo(nn.id, predecessor.id, n.id) then
        set_predecessor(nn)
    end
end

function fix_fingers()
    local i = math.random(2, m)
    finger[i].node = find_successor(finger[i].start)
    --log:print('node ' .. job.position .. ' fixed finger ' .. i)
end

counter = 1
function test_ring(current_counter)
    if current_counter > counter then
        counter = current_counter
        log:print('Test, node ' .. n.id .. ' has ' .. get_successor().id .. ' as successor')
        rpc.call(get_successor(), {'test_ring', current_counter})
    end
end

function test_ring_node1()
    test_ring(counter + 1)
end

query_total_successes = 0
function do_query()
    math.randomseed(job.position * os.time())
    for i = 1,number_of_queries do
        local key = math.random(0, 2 ^ m)
        local _, hops = find_predecessor(key)
        if hops ~= -1 then
            query_total_successes = query_total_successes + 1
        end

        if i % queries_aggregation_size == 0 then
            log:print('query_successes ' .. query_total_successes)
            query_total_successes = 0
        end
    end
end

function check_stale()
    local nb_stale = 0
    local nb_non_nil = 0
    for k, v in ipairs(finger) do
        if v.node then
            nb_non_nil = nb_non_nil + 1
            if not rpc.ping(v.node) then
                nb_stale = nb_stale + 1
            end
        end
    end
    log:print("nb_stale " .. nb_stale .. ' ' .. nb_non_nil)
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
    -- desynchronize the nodes
    local desync_wait = (max_initial_delay * math.random()) + 2
    --

    if job.position == root_node_id then
        desync_wait = 0
    end
    log:print("waiting for " .. desync_wait .. " to desynchronize")
    events.sleep(desync_wait)

    if job.position == root_node_id then
        join(nil)
    else
        local initial_partner = first_node()
        initial_partner.id = generate_id(initial_partner)
        join(initial_partner)
    end

    events.periodic(stabilize_period, stabilize)
    events.periodic(fix_finger_period, fix_fingers)
    --events.periodic(check_stale_period, check_stale)

    events.periodic(do_query_period, do_query)

    -- this thread will be in charge of killing the node after max_time seconds
    events.thread(terminator)

    if job.position == root_node_id then
        events.periodic(test_ring_period, test_ring_node1)
    end

end

events.thread(main)
events.run()
