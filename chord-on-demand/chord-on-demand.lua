require "splay.base"
require "crypto"
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
rpc.settings.default_timeout = 30

-- constants
root_node_id = 1
max_initial_delay = 4
max_time = 240
tman_view_size = 5
tman_intercycle_wait = 2
tman_cycles = 5
number_of_queries = 1000
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
tman_view = {}
tman_lock = events.lock()

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

function all_nodes()
    if cluster then
        return job.nodes
    else
        return job.nodes()
    end
end

function id_dist_comparator(a, b)
    return dist(n.id, a.id) < dist(n.id, b.id)
end

function id_asc_comparator(a, b)
    return a.id < b.id
end

function dist(a, b)
    return math.min(math.abs(a - b), (2 ^ m) - math.abs(a - b))
end

function select_peer()
    -- Work on copy to lock briefly
    local temp = {}
    tman_lock:lock()
    for key, value in ipairs(tman_view) do
        table.insert(temp, value)
    end
    tman_lock:unlock()

    table.sort(temp, id_dist_comparator)
    for key, value in ipairs(temp) do
        if rpc.ping(value, 3) then
            return value
        end
    end
    log:print("All nodes in tman_view are dead")
    return nil
end

function select_view(buffer)
    -- Remove duplicates and n
    local buffer_nodup = {}
    local current_id = -1
    table.sort(buffer, id_asc_comparator)
    for key, value in ipairs(buffer) do
        if value.id > current_id then
            current_id = value.id
            if value.id ~= n.id then
                table.insert(buffer_nodup, value)
            end
        end
    end

    -- Trim end of array (less interesting elements)
    table.sort(buffer_nodup, id_dist_comparator)
    for i = #buffer_nodup, tman_view_size + 1, -1 do
        table.remove(buffer_nodup, i)
    end

    tman_lock:lock()
    tman_view = buffer_nodup
    tman_lock:unlock()
end

function get_initial_buffer()
    local buffer = {}
    tman_lock:lock()
    for key, value in ipairs(tman_view) do
        table.insert(buffer, value)
    end
    tman_lock:unlock()

    table.insert(buffer, n)
    local pss_sample = get_n_peers(5)
    for key, value in ipairs(pss_sample) do
        table.insert(buffer, value)
    end
    return buffer
end

function tman_active_thread()
    --log:print('active')
    local p = select_peer()
    local buffer = get_initial_buffer()

    local buffer_p = rpc.call(p, {'tman_passive_thread', buffer})
    buffer = {}

    tman_lock:lock()
    for key, value in ipairs(tman_view) do
        table.insert(buffer, value)
    end
    tman_lock:unlock()
    for key, value in ipairs(buffer_p) do
        table.insert(buffer, value)
    end

    select_view(buffer)
    --log:print('active end')
end

function tman_passive_thread(buffer_q)
    --log:print('passive')
    local buffer = get_initial_buffer()

    local buffer2 = {}
    tman_lock:lock()
    for key, value in ipairs(tman_view) do
        table.insert(buffer2, value)
    end
    tman_lock:unlock()

    for key, value in ipairs(buffer_q) do
        table.insert(buffer2, value)
    end
    select_view(buffer2)
    --log:print('passive end')
    return buffer
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
        local nn = finger[i].node
        if nn and in_range_oo(nn.id, n.id, id) and rpc.ping(nn) then
            return nn
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
    if nn then
        return nn, hops
    else
        return nil, -1
    end
end

function find_successor(id)
    local nn = find_predecessor(id)
    if nn then
        return rpc.call(nn, {'get_successor'})
    else
        return nil
    end
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
    local pred = get_predecessor()
    if not pred or in_range_oo(nn.id, pred.id, n.id) then
        set_predecessor(nn)
    end
end

function fix_fingers()
    local i = math.random(2, m)
    local finger_node = find_successor(finger[i].start)
    if finger_node then
        finger[i].node = finger_node
    end
    --log:print('node ' .. job.position .. ' fixed finger ' .. i)
end

function tman_output()
    local log_line = 'TMAN ' .. n.id
    tman_lock:lock();
    for k, v in ipairs(tman_view) do
        log_line = log_line .. ' ' .. v.id
    end
    tman_lock:unlock();
    log:print(log_line)
end

function tman_bootstrap_chord()
    log:print('Bootstrapping ' .. n.id)
    local nodes = {n}
    tman_lock:lock()
    for key, value in ipairs(tman_view) do
        table.insert(nodes, value)
    end
    tman_lock:unlock()

    table.sort(nodes, id_asc_comparator)

    -- Find our node in the array
    local i = 1
    while i <= #nodes and nodes[i].id ~= n.id do
        i = i + 1
    end

    -- We are at i, so successor is at i+1 and predecessor at i-1 (circular)
    local pred_key = i - 1
    if pred_key < 1 then pred_key = #nodes end
    local succ_key = i + 1
    if succ_key > #nodes then succ_key = 1 end

    set_predecessor(nodes[pred_key])
    set_successor(nodes[succ_key])
end

function do_query()
    for i = 1,number_of_queries do
        local key = math.random(0, 2 ^ m)
        local _, hops = find_predecessor(key)
        log:print('hops_for_query ' .. hops)
    end
end

function check_ring()
    log:print('check_ring ' .. n.id .. ' ' .. get_successor().id)
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

    if job.position == root_node_id then
        desync_wait = 0
    end
    log:print("waiting for " .. desync_wait .. " to desynchronize")
    events.sleep(desync_wait)
    events.sleep(max_initial_delay)

    -- this thread will be in charge of killing the node after max_time seconds
    events.thread(terminator)

    events.sleep(10)

    tman_lock:lock()
    tman_view = get_n_peers(tman_view_size)
    tman_lock:unlock()

    for i = 1, tman_cycles do
        events.sleep(tman_intercycle_wait)
        tman_active_thread()
        tman_output()
    end

    events.sleep(tman_intercycle_wait)
    tman_bootstrap_chord()
    events.sleep(tman_intercycle_wait)

    check_ring()

    events.sleep(tman_intercycle_wait)
    --events.thread(do_query)
end

require"pss"
events.thread(pss_main)

events.thread(main)
events.run()
