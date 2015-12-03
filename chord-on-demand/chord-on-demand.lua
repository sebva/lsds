require "splay.base"
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
-- rpc.settings.default_timeout = 5

-- constants
root_node_id = 0
max_initial_delay = 10

-- variables

-- initializer

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

    -- this thread will be in charge of killing the node after max_time seconds
    events.thread(terminator)

end

events.thread(main)
events.run()
