function love.conf(t)
    t.identity = "Bullet 2D"
    -- Minimum LÖVE version; bump when you rely on newer APIs.
    t.version = "11.5"

    t.appendidentity = true
    t.console = true

    t.window.title = "Bullet 2D"
    t.window.width = 1600
    t.window.height = 900
    t.window.minwidth = 1280
    t.window.minheight = 720
    t.window.resizable = false
    t.window.fullscreen = false
    t.window.vsync = 0

end
