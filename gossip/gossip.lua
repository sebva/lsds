require"splay.base"
rpc = require"splay.urpc"
-- to use TCP RPC, replace previous by the following line
-- rpc = require"splay.rpc"


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

-- algorithms
do_rumor_mongering = true
do_anti_entropy = true

-- constants
use_pss = true
pss_init_duration = 60 -- amount of time the PSS is left alone in the beggining
anti_entropy_period = 5 -- gossip every 20 seconds
rumor_mongering_period = 10
max_time = 150 -- we do not want to run forever ...
HTL = 3
f = 2

-- variables
infected = "no"
current_cycle = 0
buffered = false -- do I have buffered messages?
buffered_h = nil -- hops-to-live value for buffered messages
lock = events.lock() -- prevent both algorithms from self-destruction

--functions

function anti_entropy()
  local remote_infected = rpc.call(ae_select_partner(), { "anti_entropy_receive", infected })
  gossip_select_to_keep(remote_infected)
end

function anti_entropy_receive(received)
  gossip_select_to_keep(received)
  return infected
end

function rm_notify(h)
  log:print("node "..job.position.." ("..infected..") was notified with hops "..h.." (HTL="..HTL..")")

  if infected == "no" then
    -- log:print(os.date('%H:%M:%S') .. ' (' .. job.position .. ') i_am_infected')
    gossip_select_to_keep('yes')
  else
    log:print('duplicate_received')
  end

  if (h < HTL) or (buffered and ((h + 1) < buffered_h)) then
    buffered = true
    buffered_h = h + 1
  end
end

function rm_activeThread()
  current_cycle = current_cycle + 1

  -- do I have to send something to someone?
  if buffered then
    log:print(job.position.." proceeds to forwarding to "..f.." peers")

    local selected_peers = rm_select_partner()
    for key, node in pairs(selected_peers) do
      rpc.call(node, {'rm_notify', buffered_h})
    end

    buffered = false
    buffered_h = nil
  end
end

function rm_select_partner()
  if use_pss then
    return get_n_peers(f)
  else
    local all_nodes_but_i = job.nodes()
    table.remove(all_nodes_but_i, job.position)
    return misc.random_pick(all_nodes_but_i, f)
  end
end

function ae_select_partner()
  if use_pss then
    return get_n_peers(1)
  else
    local id = job.position
    while id == job.position do
      id = math.random(#job.nodes())
    end
    return job.nodes()[id]
  end
end

function gossip_select_to_keep(received)
  if infected == 'no' and received == 'yes' then
    infected = 'yes'
    log:print('i_am_infected')
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
  log:print("FINAL: node "..job.position.." "..infected) 
  os.exit()
end

function main()
  if use_pss then
    events.sleep(pss_init_duration)
  end

  -- init random number generator
  math.randomseed(job.position*os.time())
  -- wait for all nodes to start up (conservative)
  events.sleep(2)
  -- desynchronize the nodes
  local desync_wait = (anti_entropy_period * math.random())
  -- the first node is the source and is infected since the beginning
  if job.position == 1 then
    infected = "yes"
    buffered = true
    buffered_h = 0
    log:print(job.position.." i_am_infected")
    desync_wait = 0
  end

  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)

  if do_anti_entropy then
    events.periodic(anti_entropy, anti_entropy_period)
  end
  if do_rumor_mongering then
    events.periodic(rm_activeThread, rumor_mongering_period)
  end
  
  -- this thread will be in charge of killing the node after max_time seconds
  events.thread(terminator)
end

if use_pss then
  require"pss"
  events.thread(pss_main)
end

events.thread(main)  
events.run()

