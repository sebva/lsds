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
max_time = 120 -- we do not want to run forever ...
HTL = 3
f = 2

-- variables
infected = "no"
current_cycle = 0
buffered = false -- do I have buffered messages?
buffered_h = nil -- hops-to-live value for buffered messages


function rm_notify(h)
  log:print("node "..job.position.." ("..infected..") was notified with hops "..h.." (HTL="..HTL..")")

  -- TODO: infect if necessary

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

    -- TODO: select f destination nodes and notify each of
    -- them via a rpc to notify(buffered_h)

    buffered = false
    buffered_h = nil
  end
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
    log:print(job.position.." i_am_infected")
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