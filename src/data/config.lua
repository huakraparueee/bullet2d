local M = {}

M.DESIGN_WIDTH = 1600
M.DESIGN_HEIGHT = 900

M.DEFAULT_BACKGROUND_R = 0.1
M.DEFAULT_BACKGROUND_G = 0.1
M.DEFAULT_BACKGROUND_B = 0.1

M.TILE_SIZE = 96
M.GRID_POINT_PER_TILE = 7
M.DEBUG_DRAW_MAP = false
M.GRID_ORIGIN_X = 0
M.GRID_ORIGIN_Y = 0
M.MAP_OFFSET_Y = 240

M.ISO_X_RATIO = 0.5
M.ISO_Y_RATIO = 0.25
M.ISO_EH_RATIO = 0.5

M.TERRAIN_MATS = {
    grass = {
        path = "sprites/terrain/grass-7a.png",
        autotile = true,
        proximity = 3,
        variants = {
            s      = "sprites/terrain/grass-1.png",  
            e_s    = "sprites/terrain/grass-2.png",  
            w_e_s  = "sprites/terrain/grass-3.png",  
            w_s    = "sprites/terrain/grass-4.png",  
            n_s    = "sprites/terrain/grass-5.png",  
            n_e_s  = "sprites/terrain/grass-6.png",  
            full   = {
                { path = "sprites/terrain/grass-7a.png", weight = 1 },
                { path = "sprites/terrain/grass-7b.png", weight = 5 },
                { path = "sprites/terrain/grass-7c.png", weight = 3 },
                { path = "sprites/terrain/grass-7d.png", weight = 2 },
                { path = "sprites/terrain/grass-7e.png", weight = 1 },
            }, 
            n_w_s  = "sprites/terrain/grass-8.png", 
            n      = "sprites/terrain/grass-9.png", 
            n_e    = "sprites/terrain/grass-10.png",
            w_n_e  = "sprites/terrain/grass-11.png", 
            n_w    = "sprites/terrain/grass-12.png", 
            solo   = "sprites/terrain/grass-13.png", 
            e      = "sprites/terrain/grass-14.png", 
            w_e    = "sprites/terrain/grass-15.png", 
            w      = "sprites/terrain/grass-16.png", 
        },
    },
    ground = {
        proximity = 5,
        path = {
            { path = "sprites/terrain/ground-1a.png", weight = 5 },
            { path = "sprites/terrain/ground-1b.png", weight = 1 },
            { path = "sprites/terrain/ground-1c.png", weight = 2 },
        },
    },
    water = {
        path = "sprites/terrain/water.png",
        w = 32,
        h = 32,
        modes = {
            default = { cols = "1-4", interval = 2.5, loop = true },
        },
        alpha = 0.5,
        walkable = false
    },
    deepwater = {
        path = "sprites/terrain/deepwater.png",
    },
    sand = {
        color = { 0.9, 0.8, 0.6 },
    },
    stone = {
        color = { 0.7, 0.7, 0.7 },
    },
    ice = {
        color = { 0.9, 0.9, 0.9 },
    },
}

M.STRUCTURES = {
    tree = {
        path = "sprites/tree.png",
        w = 256,
        h = 384,
        tiles_w = 1,
        tiles_d = 1,
        tiles_h = 4,
        hit = { w = 140, h = 200 },
    },
    campfire = {
        path = "sprites/campfire.png",
        w = 32,
        h = 64,
        tiles_w = 1,
        tiles_d = 1,
        tiles_h = 3,
        modes = {
            default = { cols = "1-4", interval = 0.8, loop = true },
        },
    },
}

M.NPCS = {
    slime = {
        path = "sprites/slime.png",
        w = 64,
        h = 64,
        tiles_w = 1,
        tiles_d = 1,
        tiles_h = 1,
        hit = { w = 40, h = 48 },
        draw_offset_y = 0,
        sprite_faces = "left",
        walkspeed = 1,
        facing = "sw",
        modes = {
            stand = { cols = "1", interval = 1, pause = true },
            walk = {
                interval = 0.25,
                loop = true,
                dirs = {
                    e  = { cols = "2-5", flip = "h" },
                    se = { cols = "2-5", flip = "h" },
                    s  = { cols = "2-5" },
                    sw = { cols = "2-5" },
                    w  = { cols = "2-5" },
                    nw = { cols = "6-9" },
                    n  = { cols = "6-9" },
                    ne = { cols = "6-9" },
                },
            },
        }
    },
    slime_magic = {
        path = "sprites/slime-magic.png",
        w = 64,
        h = 64,
        tiles_w = 1,
        tiles_d = 1,
        tiles_h = 1,
        hit = { w = 40, h = 48 },
        draw_offset_y = 0,
        sprite_faces = "left",
        walkspeed = 1,
        facing = "sw",
        modes = {
            stand = { cols = "1", interval = 1, pause = true },
            walk = {
                interval = 0.25,
                loop = true,
                dirs = {
                    e  = { cols = "2-5", flip = "h" },
                    se = { cols = "2-5", flip = "h" },
                    s  = { cols = "2-5" },
                    sw = { cols = "2-5" },
                    w  = { cols = "2-5" },
                    nw = { cols = "6-9" },
                    n  = { cols = "6-9" },
                    ne = { cols = "6-9" },
                },
            },
        }
    },
    human = {
        path = "sprites/orc.png",
        w = 64,
        h = 128,
        tiles_w = 1,
        tiles_d = 1,
        tiles_h = 2,
        hit = { w = 36, h = 72 },
        draw_offset_y = 0,
        sprite_faces = "right",
        walkspeed = 4,
        facing = "s",
        modes = {
            stand = { cols = "1-2", interval = 0.8, loop = true },
            walk = { cols = "1-2", interval = 0.3, loop = true },
            shoot = { cols = "1-2", interval = 0.1, loop = true },
        }
    },
}

M.PROJECTILES = {
    bolt = {
        move = "line",
        duration = 0.55,
        radius = 6,
        color = { 1, 0.9, 0.25 },
    },
    arrow = {
        path = "sprites/arrow.png",
        w = 16,
        h = 8,
        move = "arc",
        duration = 0.5,
        arc_height = 56,
        draw_offset_y = -40,
    },
}

M.SOUNDS = {
    fire = {
        path = "sounds/fire.mp3",
        volume = 0.32,
        min_interval = 0.09,
        max_instances = 4,
    },
    choose = {
        path = "sounds/choose.mp3",
        volume = 0.7,
    },
    gameover = {
        path = "sounds/gameover.mp3",
        volume = 0.9,
    },
    background = {
        path = "sounds/background.mp3",
        volume = 0.35,
        stream = true,
        music = true,
    },
}

return M
