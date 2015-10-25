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

-- constants
rumor_mongering_period = 10
max_time = 40 -- we do not want to run forever ...
HTL = 3
f = 2

-- variables
infected = "no"
current_cycle = 0
buffered = false -- do I have buffered messages?
buffered_h = nil -- hops-to-live value for buffered messages


function rm_notify(h)
  log:print("node "..job.position.." ("..infected..") was notified with hops "..h.." (HTL="..HTL..")")

  if infected == "no" then
    -- log:print(os.date('%H:%M:%S') .. ' (' .. job.position .. ') i_am_infected')
    log:print('i_am_infected')
    infected = "yes"
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

    local all_nodes_but_i = job.nodes()
    table.remove(all_nodes_but_i, node_id)
    local selected_peers = select_f_from_i(f, all_nodes_but_i)
    for key, node in pairs(selected_peers) do
      rpc.call(node, {'rm_notify', buffered_h})
    end
    -- TODO: select f destination nodes and notify each of
    -- them via a rpc to notify(buffered_h)

    buffered = false
    buffered_h = nil
  end
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