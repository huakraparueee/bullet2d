local config = require("src.data.config")
local gamestate = require("libraries.hump.gamestate")
local viewport = require("src.systems.viewport")
local MenuUi = require("src.render.menu")

local M = {}

local MENU_ITEMS = {
    {
        label = "Play",
        action = function()
            local play = require("src.scenes.play")
            play.carry_player = nil
            play.start()
        end,
    },
    {
        label = "Quit",
        action = function()
            love.event.quit()
        end,
    },
}

function M:init()
    self.default_font = love.graphics.newFont()
end

function M:enter()
    self.selected_index = 1
    self.fonts = MenuUi.create_fonts(
        config.DESIGN_WIDTH,
        config.DESIGN_HEIGHT
    )
end

function M:resize()
    self.fonts = MenuUi.create_fonts(
        config.DESIGN_WIDTH,
        config.DESIGN_HEIGHT
    )
end

function M:keypressed(key, _, isrepeat)
    if isrepeat then
        return
    end

    if key == "up" or key == "w" then
        self.selected_index = self.selected_index - 1

        if self.selected_index < 1 then
            self.selected_index = #MENU_ITEMS
        end

        return
    end

    if key == "down" or key == "s" then
        self.selected_index = self.selected_index + 1

        if self.selected_index > #MENU_ITEMS then
            self.selected_index = 1
        end

        return
    end

    if key == "return" or key == "space" or key == "kpenter" then
        local item = MENU_ITEMS[self.selected_index]

        if item then
            item.action()
        end
    end
end

function M:draw()
    love.graphics.clear(
        config.DEFAULT_BACKGROUND_R,
        config.DEFAULT_BACKGROUND_G,
        config.DEFAULT_BACKGROUND_B
    )

    viewport.begin()

    MenuUi.draw({
        title = "Bullet 2D",
        items = MENU_ITEMS,
        selected_index = self.selected_index,
        fonts = self.fonts,
    })

    love.graphics.setFont(self.default_font)
    love.graphics.setColor(1, 1, 1, 1)

    viewport.finish()
end

return M
