hs.window.animationDuration = 0

table.filter = function(t, filterIter)
  local out = {}

  for k, v in pairs(t) do
    if filterIter(v, k, t) then table.insert(out,v) end
  end

  return out
end

function primaryScreenIsDell()
  local primary = hs.screen.primaryScreen()
  return string.find(string.lower(primary:name()), "dell")
end

-- Maximize all windows that are sitting at the left or top of their screen,
-- assuing that they just lost the maximization through screen changes
function maxWindows()
  local log = hs.logger.new('max','debug')
  local desktop = hs.window.desktop()
  local windows = table.filter(hs.window.allWindows(), function(o, k, i)
    return o:isStandard() and o:isMaximizable()
  end)
  local size = desktop:size()

  for _, win in ipairs(windows) do
    local screen = win:screen()
    local tl = win:topLeft();

    if screen and (tl.x == screen:frame().x or tl.y == screen:frame().y) then
      win:maximize(0)
    end
  end
end

-- Move chrome to LG montior
function applicationWatcher(appName, eventType, appObject)
  local log = hs.logger.new('app','debug')

  if primaryScreenIsDell() then
    if (eventType == hs.application.watcher.activated or eventType == hs.application.watcher.launched) then
      if(appName == "Google Chrome" or appName == "Chromium") then
        log:d("Move chrome")
        local windows = appObject:visibleWindows()
        for _, win in ipairs(windows) do
          win:moveToScreen('LG', true, true, 0)
          win:maximize(0)
        end
      end
    end
  end
end
appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

function dump(o, tbs, tb)
  tb = tb or 0
  tbs = tbs or '  '
  if type(o) == 'table' then
    local s = '{'
    if (next(o)) then s = s .. '\n' else return s .. '}' end
    tb = tb + 1
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"' .. k .. '"' end
      s = s .. tbs:rep(tb) .. '[' .. k .. '] = ' .. dump(v, tbs, tb)
      s = s .. ',\n'
    end
    tb = tb - 1
    return s .. tbs:rep(tb) .. '}'
  else
    return tostring(o)
  end
end

yeelightCommand = "/Users/jeremyw/.asdf/installs/rust/1.65.0/bin/yeelight"

-- Declare and initialize the global variable 'yeelightTask'
yeelightTask = nil

-- Declare and initialize the global list for pending yeelight tasks
yeelightPendingTasks = {}

-- Declare the global variable to hold the yeelight IP address
yeelightIP = nil

-- Declare the global variable to hold the yeelight availability status
yeelightAvailable = false

-- Declare the delay between discovery attempts (in seconds)
discoveryDelay = 60  -- Change this value as needed

-- Declare the global variable to hold the last discovery attempt time
lastDiscoveryAttempt = os.time() - discoveryDelay

function clearYeelightQueue()
  local log = hs.logger.new('yeelight','debug')
  log.d("Clearing yeelight queue...")

  if #yeelightPendingTasks < 1 then
    log.d("No tasks in queue.")
    return
  end

  if not yeelightAvailable or (yeelightTask and yeelightTask:isRunning()) then
    log.e("Yeelight is not available or a task is already running.")
    return
  end

  local nextTask = table.remove(yeelightPendingTasks, 1)
  log.d("Next task: " .. dump(nextTask.args))

  yeelightTask = hs.task.new(yeelightCommand, function (code, stdOut, stdErr)
    log:d(dump({code, stdOut, stdErr}))
    if nextTask.cb then
      nextTask.cb()
    end
    -- After a task is finished, try to clear the queue again
    clearYeelightQueue()
  end, hs.fnutils.concat({yeelightIP}, nextTask.args))
  yeelightTask:start()
end

function discoverYeelight()
  local log = hs.logger.new('yeelightDiscover','debug')
  log.d("Discovering yeelight device...")
  -- Start a task to discover the yeelight
  local discoverTask = hs.task.new(yeelightCommand, function(code, stdOut, stdErr)
    log:d(dump({code, stdOut, stdErr}))
    -- Extract the IP from the output
    local discoveredIP = stdOut:match("(%d+.%d+.%d+.%d+):")
    if discoveredIP then
      yeelightIP = discoveredIP
      yeelightAvailable = true
      -- Try to clear the queue after discovering
      clearYeelightQueue()
    else
      log:e("Could not discover yeelight device.")
      yeelightAvailable = false
    end
    lastDiscoveryAttempt = os.time()
  end, {"discover"})
  discoverTask:start()
end

function yeelight(args, cb)
  local log = hs.logger.new('yeelight','debug')
  log.d("yeelight available: " .. tostring(yeelightAvailable) .. ", task running: " .. tostring(yeelightTask and yeelightTask:isRunning()) .. ", pending tasks: " .. tostring(#yeelightPendingTasks))

  -- If the yeelight IP isn't available yet or a task is running, append the task to the yeelightPendingTasks list
  if not yeelightAvailable or not yeelightTask or (yeelightTask and yeelightTask:isRunning()) then
    log.d("Appending task to pending tasks list.")
    
    table.insert(yeelightPendingTasks, {args = args, cb = cb})

    if not yeelightAvailable and os.time() - lastDiscoveryAttempt >= discoveryDelay then
      log.d("Starting discovery task.")
      discoverYeelight()
    end
  else
    -- If no task is running, start a new one
    clearYeelightQueue()
  end
end

function configureYeelight()
  local primary = hs.screen.primaryScreen()

  if string.find(string.lower(primary:name()), "dell") then
    local hour = hs.timer.localTime()/3600
    local logger = hs.logger.new('yeelight','debug')
    logger.d("Hour: " .. hour)

    if(hour < 8) then
      yeelight({"off"})
    elseif(hour > 18) then
      yeelight({"on"}, function()
        yeelight({"set", "bright", "30"}, function()
          yeelight({"set", "rgb", "51894"})
        end)
      end)
    else
      yeelight({"on"}, function()
        yeelight({"set", "bright", "20"}, function()
          yeelight({"set", "rgb", "3211179"})
        end)
      end)
    end
  else
    yeelight({"off"})
  end
end

-- Move the dock to the left when unplugged
function screenWatcherFn()
  local log = hs.logger.new('screen','debug')
  local primary = hs.screen.primaryScreen()

  if primaryScreenIsDell() then
    log:d("Move dock to bottom")
    hs.osascript.applescript("tell application \"System Events\" to set the screen edge of the dock preferences to bottom")
  else
    log:d("Move dock to left")
    hs.osascript.applescript("tell application \"System Events\" to set the screen edge of the dock preferences to left")
  end

  configureYeelight()

  -- Maximize any window that was previously maximized
  maxWindows()
end
screenWatcher = hs.screen.watcher.new(screenWatcherFn)
screenWatcher:start()
screenWatcherFn()

hs.timer.doEvery(1800, configureYeelight)

hs.hotkey.bind("alt", "w", nil, function(); hs.window. frontmostWindow():maximize(0); end);
hs.hotkey.bind("alt", "c", nil, function(); hs.window. frontmostWindow():centerOnScreen(); end);