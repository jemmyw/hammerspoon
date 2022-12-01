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
    if(appName == "Google Chrome") then
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

  -- Maximize any window that was previously maximized
  maxWindows()
end
screenWatcher = hs.screen.watcher.new(screenWatcherFn)
screenWatcher:start()
screenWatcherFn()

hs.hotkey.bind("alt", "w", nil, function(); hs.window. frontmostWindow():maximize(0); end);
hs.hotkey.bind("alt", "c", nil, function(); hs.window. frontmostWindow():centerOnScreen(); end);