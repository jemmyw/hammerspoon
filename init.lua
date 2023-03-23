hs.window.animationDuration = 0

table.filter = function(t, filterIter)
  local out = {}

  for k, v in pairs(t) do
    if filterIter(v, k, t) then table.insert(out,v) end
  end

  return out
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

function yeelight(args, cb)
  local wargs = hs.fnutils.concat({"192.168.68.128"}, args)
  local log = hs.logger.new('yeelight','debug')
  log.d(dump(wargs))
  local task = hs.task.new("/Users/jeremyw/.asdf/installs/rust/1.65.0/bin/yeelight", function (code, stdOut, stdErr)
    log:d(dump({code, stdOut, stdErr}))
    if cb then
      cb()
    end
  end, wargs)
  task:start()
  task:waitUntilExit()
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
        yeelight({"set", "bright", "50"}, function()
          yeelight({"set", "rgb", "3211179"})
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

  if string.find(string.lower(primary:name()), "dell") then
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