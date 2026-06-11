local config = require("src.data.config")
local gamestate = require("libraries.hump.gamestate")
local viewport = require("src.systems.viewport")
local MenuUi = require("src.render.menu")
local Audio = require("src.systems.audio")

local M = {}

local function build_menu_items(menu)
    local play = require("src.scenes.play")
    local items = {}

    if play.has_saved_run() then
        items[#items + 1] = {
            label = "Continue",
            action = function()
                gamestate.switch(play, { resume = play.saved_run })
            end,
        }
    end

    items[#items + 1] = {
        label = "Play",
        action = function()
            play.saved_run = nil
            play.carry_player = nil
            play.death_count = 0
            play.start()
        end,
    }

    items[#items + 1] = {
        label = "Credits",
        action = function()
            menu.show_credits = true
        end,
    }

    items[#items + 1] = {
        label = "Quit",
        action = function()
            love.event.quit()
        end,
    }

    return items
end

function M:init()
    self.default_font = love.graphics.newFont()
end

function M:enter()
    Audio.stop_music()
    self.show_credits = false
    self.menu_items = build_menu_items(self)
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

    if self.show_credits then
        if key == "escape" or key == "return" or key == "space" or key == "kpenter" then
            self.show_credits = false
            Audio.play("choose")
        end

        return
    end

    local items = self.menu_items or {}

    if key == "up" or key == "w" then
        self.selected_index = self.selected_index - 1

        if self.selected_index < 1 then
            self.selected_index = #items
        end

        Audio.play("choose")
        return
    end

    if key == "down" or key == "s" then
        self.selected_index = self.selected_index + 1

        if self.selected_index > #items then
            self.selected_index = 1
        end

        Audio.play("choose")
        return
    end

    if key == "return" or key == "space" or key == "kpenter" then
        local item = items[self.selected_index]

        if item then
            Audio.play("choose")
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

    if self.show_credits then
        MenuUi.draw_credits({
            fonts = self.fonts,
            lines = {
                "Created by HkpsS",
                "Thank you for playing!",
            },
        })
    else
        MenuUi.draw({
            title = "Bullet 2D",
            items = self.menu_items,
            selected_index = self.selected_index,
            fonts = self.fonts,
        })
    end

    love.graphics.setFont(self.default_font)
    love.graphics.setColor(1, 1, 1, 1)

    viewport.finish()
end

return M
