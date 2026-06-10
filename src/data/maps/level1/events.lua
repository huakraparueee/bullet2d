return {
    init = {
        {
            type = "npc.add",
            id = "pop",
            tile_x = 5,
            tile_y = 5,
            kind = "human",
            facing = "se",
            mode = "stand",
        },
    },
    start = {},
    ranged_attack = {
        {
            type = "npc.shoot",
            id = "pop",
            tile_x = 8,
            tile_y = 8,
            kind = "arrow",
            delay = 0.12,
            on_hit = {
                { type = "terrain.update", mat = "sand", tile_x = 8, tile_y = 8 },
            },
        }
    },
    leave = {},
}
