--require"splay.base"
--rpc = require"splay.urpc"

--[[
-- addition to allow local run
if not job then
    -- can NOT be required in SPLAY deployments !
    local utils = require("splay.utils")
    if #arg < 2 then
        print("lua "..arg[0].." my_position nb_nodes")
        os.exit()
    else
        local pos, total = tonumber(arg[1]), tonumber(arg[2])
        job = utils.generate_job(pos, total, 20001)
    end
end

--]]
--rpc.server(job.me.port)

-- variables
view = {}
view_lock = events.lock()

--constants
node_id = job.position
EXCH = 4
C = 8
H = 2
S = 2
SEL = 'rand'
ACTIVE_INTERVAL = 5
VIEW_OUTPUT_INTERVAL = 20
MAX_TIME = 120

function get_n_peers(n)
    if n == 1 then
        return view[math.random(#view)]['peer']
    else
        local ret = {}
        local peers = misc.random_pick(view, n)
        for k, v in ipairs(peers) do
            local peer = v['peer']
            table.insert(ret, peer)
        end
        return ret
    end
end

function select_partner()
    if SEL == 'rand' then
        view_lock:lock();
        local shuffled_view = misc.shuffle(view)
        view_lock:unlock();
        local partner = shuffled_view[1]
        if partner.id == node_id then
            partner = shuffled_view[2]
        end
        return partner
    elseif SEL == 'tail' then
        local largest
        view_lock:lock();
        for k, v in ipairs(view) do
            if (largest == nil or v.age > largest.age) and v.id ~= node_id then
                largest = v
            end
        end
        view_lock:unlock();
        return largest
    end
end

function select_to_send()
    local to_send = {}
    table.insert(to_send, {age = 0, peer = job.me, id = node_id})
    view_lock:lock();
    view = misc.shuffle(view)
    local oldest_index
    for i = 0, H - 1 do
        for j = 1, #view - i do
            if oldest_index == nil or view[j].age > view[oldest_index].age then
                oldest_index = j
            end
        end
        local oldest_peer = table.remove(view, oldest_index)
        table.insert(view, oldest_peer)
    end
    for i = 1, EXCH -1 do
        table.insert(to_send, view[i])
    end
    view_lock:unlock();
    return to_send
end

function select_to_keep(received)
    view_lock:lock();
    for k, v in ipairs(received) do
        if v.id ~= node_id then
            table.insert(view, v)
        end
    end

    -- Remove duplicates
    local to_remove = {}
    for i = 1, #view do
        for j = i, #view do
            if j ~= i and view[i].id == view[j].id then
                if view[i].age > view[j].age then
                    table.insert(to_remove, i)
                else
                    table.insert(to_remove, j)
                end
            end
        end
    end
    -- Iterate in reverse, this way indices don't change
    table.sort(to_remove, desc_comp)
    for k, v in ipairs(to_remove) do
        table.remove(view, v)
    end

    -- Remove H oldest items
    local view_size = #view
    local oldest_index
    local oldest_age = 0
    for i = 1, math.min(H, view_size - C) do
        for k, v in ipairs(view) do
            if oldest_index == nil or v.age > oldest_age then
                oldest_index = k
            end
        end
        table.remove(view, oldest_index)
        oldest_index = nil
    end

    -- Remove S head items
    view_size = #view
    for i = 1, math.min(S, view_size - C) do
        table.remove(view, 1)
    end
    view = select_f_from_i(C, view)
    view_lock:unlock();
end

function desc_comp(a, b)
    return a > b
end

function age_asc(a, b)
    return a.age < b.age
end

function active_thread()
    local partner = select_partner()
    local buffer = select_to_send()
    local received = rpc.call(partner.peer, {'passive_thread', buffer})
    select_to_keep(received)
    view_lock:lock();
    for k,v in ipairs(view) do
        v.age = v.age + 1
    end
    view_lock:unlock();
end

function passive_thread(received)
    local buffer = select_to_send()
    select_to_keep(received)
    return buffer
end

function display_peers(peers)
    log:print('node '..node_id)
    view_lock:lock();
    for k, v in ipairs(view) do
        log:print(v.id .. ' ' .. v.peer.ip .. v.peer.port .. v.age)
    end
    view_lock:unlock();
end

function view_output()
    local log_line = 'VIEW_CONTENT '..node_id
    view_lock:lock();
    for k, v in ipairs(view) do
        log_line = log_line .. ' ' .. v.id
    end
    view_lock:unlock();
    log:print(log_line)
end

-- Reservoir sampling algorithm
function select_f_from_i(f, i)
    return misc.random_pick(i, f)
    --[[
    if f >= #i then
        return i
    end
    local r = {}
    for j = 1, f do
        r[j] = table.remove(i)
    end

    local elements_seen = f
    while #i > 0 do
        elements_seen = elements_seen + 1
        local j = math.random(elements_seen)
        if j <= f then
            r[j] = table.remove(i)
        else
            table.remove(i)
        end
    end

    return r
    ]]
end

function terminator()
    events.sleep(MAX_TIME)
    log:print("FINAL: node "..job.position)
    os.exit()
end

function pss_main()
    math.randomseed(job.position*os.time())
    -- wait for all nodes to start up (conservative)
    events.sleep(2)

    -- initialize the view
    local all_nodes_view = {}
    for k, v in ipairs(job.nodes()) do
        if k ~= node_id then
            table.insert(all_nodes_view, {age=0, peer=v, id=k})
        end
    end
    view = select_f_from_i(C, all_nodes_view)

    -- output and schedule view output
    view_output()
    events.periodic(view_output ,VIEW_OUTPUT_INTERVAL)

    -- desynchronize the nodes
    local desync_wait = (ACTIVE_INTERVAL * math.random())
    log:print("waiting for "..desync_wait.." to desynchronize")
    events.sleep(desync_wait)

    -- start gossiping!
    events.periodic(active_thread, ACTIVE_INTERVAL)
    --events.thread(terminator)
end
