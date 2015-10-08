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

-- constants
anti_entropy_period = 5 -- gossip every 20 seconds
max_time = 120 -- we do not want to run forever ...

-- variables
infected = "no"
current_cycle = 0

--functions

function anti_entropy()
  while true do
    rpc.call(select_partner(), { "anti_entropy_receive", job.position, infected, true })
    events.sleep(anti_entropy_period)
  end
end

function anti_entropy_receive(sender_id, received, do_answer)
  local was_infected = infected
  infected = select_to_keep(received)
  if was_infected == 'no' and infected == 'yes' then
    -- log:print(os.date('%H:%M:%S') .. ' (' .. job.position .. ') i_am_infected')
    log:print('i_am_infected')
  end
  if do_answer then
    rpc.call(job.nodes()[sender_id], { "anti_entropy_receive", job.position, infected, false })
  end
end

function select_partner()
  local id = math.random(#job.nodes())
  return job.nodes()[id]
end

function select_to_send()
  return 'yes'
end

function select_to_keep(received)
  if infected == 'yes' or received == 'yes' then
    return 'yes'
  else
    return 'no'
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
  -- init random number generator
  math.randomseed(job.position*os.time())
  -- wait for all nodes to start up (conservative)
  events.sleep(2)
  -- desynchronize the nodes
  local desync_wait = (anti_entropy_period * math.random())
  -- the first node is the source and is infected since the beginning
  if job.position == 1 then
    infected = "yes"
    log:print(job.position.." i_am_infected")
    desync_wait = 0
  end
  log:print("waiting for "..desync_wait.." to desynchronize")
  events.sleep(desync_wait)  
  
  events.thread(anti_entropy)
  
  -- this thread will be in charge of killing the node after max_time seconds
  events.thread(terminator)
end  

events.thread(main)  
events.run()

