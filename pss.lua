require"splay.base"
rpc = require"splay.urpc"

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

rpc.server(job.me.port)

-- variables
view = {}

--constants
EXCH = 4
C = 8
H = 2
S = 2
SEL = 'rand'

function select_partner()
    if SEL == 'rand' then
        return misc.shuffle(view)[1]
    elseif SEL == 'tail' then
        local largest
        for k, v in pairs(view) do
            if largest == nil or v.age > largest.age then
                largest = v
            end
        end
        return largest
    end
end

function select_to_send()
    local to_send = {}
    table.insert(to_send, {age = 0, peer = job.me, id = node_id})
    view = misc.shuffle(view)
    local oldest_index
    for i = 1, H do
        for j = 1, #view - i + 1 do
            if oldest_index == nil or view[j].age > view[oldest_index].age then
                oldest_index = j
            end
        end
        local oldest_peer = table.remove(view, oldest_index)
        table.insert(oldest_peer)
    end
    for i = 1, EXCH -1 do
        table.insert(to_send, shuffled_view[i])
    end
    return to_send
end

function select_to_keep(received)
    for k, v in pairs(received) do
        table.insert(view, v)
    end

    -- Remove duplicates
    local to_remove = {}
    for i = 1, #view do
        for j = 1, #view do
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
    for k, v in pairs(to_remove) do
        table.remove(view, v)
    end

    -- Remove H oldest items
    local view_size = #view
    local oldest_index
    for i = 1, math.min(H, view_size - C) do
        for k, v in pairs(view) do
            if oldest_index == nil or v.age > view[oldest_index].age then
                oldest_index = k
            end
        end
        table.remove(view, oldest_index)
    end

    -- Remove S head items
    for i = 1, math.min(S, #view - C) do
        table.remove(view, 1)
    end
    view = select_f_from_i(C, view)
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
    local received = rpc.call(partner, {'passive_thread', buffer})
    select_to_keep(received)
    for k,v in pairs(view) do
        v.age = v.age + 1
    end
end

function passive_thread(received)
    local buffer = select_to_send()
    select_to_keep(received)
    return buffer
end

-- Reservoir sampling algorithm
function select_f_from_i(f, i)
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
end

function terminator()
    events.sleep(max_time)
    log:print("FINAL: node "..job.position.." "..infected)
    os.exit()
end

function main()
    math.randomseed(job.position*os.time())
    -- wait for all nodes to start up (conservative)
    events.sleep(2)
    -- desynchronize the nodes
    local desync_wait = (rumor_mongering_period * math.random())
    -- the first node is the source and is infected since the beginning
    if job.position == 1 then
        infected = "yes"
        buffered = true
        buffered_h = 0
        log:print("i_am_infected")
        desync_wait = 0
    end
    log:print("waiting for "..desync_wait.." to desynchronize")
    events.sleep(desync_wait)

    -- start gossiping!
    events.periodic(rm_activeThread,rumor_mongering_period)
    events.thread(terminator)
end

events.thread(main)
events.run()