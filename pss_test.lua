require"splay.base"

-- variables
view = {}

--constants
EXCH = 4
C = 8
H = 2
S = 2
SEL = 'tail'

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

function print_table(t)
    for k,v in pairs(t) do
        print('['..k..'] = '..v.age)
    end
end

view = {
    {id=1, age=math.random(0, 5)},
    {id=5, age=math.random(0, 5)},
    {id=3, age=math.random(0, 5)},
    {id=8, age=math.random(0, 5)},
    {id=6, age=math.random(0, 5)},
    {id=2, age=math.random(0, 5)},
    {id=4, age=math.random(0, 5)},
    {id=7, age=math.random(0, 5)},
}

print_table(view)
