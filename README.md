# Simple Bullet Hell Demo (Isolet2d Example)

A lightweight, wave-based **Bullet Hell (Shoot 'Em Up)** demo built to showcase core arcade mechanics, progression, and scaling enemy difficulty.

> 💡 **Purpose:** This project serves as a practical implementation example and reference guide for utilizing the **Isolet2d** framework/library.

---

## 🎮 Gameplay Overview

The core loop is straightforward and action-focused:

1. **Spawn & Survive:** Enter a stage where enemies are already spawned on the map.
2. **Eliminate All Threats:** Defeat every enemy in the stage to clear it and progress to the next level.
3. **Level Up & Upgrade:** Earn experience to level up and instantly upgrade your character's stats to face tougher challenges.

---

## 👾 Enemy Scaling System

Every stage features a unique configuration of enemies. While the visual environment remains consistent, enemy difficulty scales dynamically across five core attributes:

| Attribute          | Description                                             |
| :----------------- | :------------------------------------------------------ |
| **Movement Speed** | How fast the enemies chase or move around the screen.   |
| **Attack Damage**  | The amount of health deducted from the player upon hit. |
| **Fire Rate**      | The frequency of enemy projectile attacks.              |
| **Health Pools**   | Total damage required to eliminate an enemy.            |
| **Spawn Count**    | The total number of enemies present in the stage.       |

---

## 🆙 Player Progression & Upgrades

As you defeat enemies and level up, you can customize your playstyle by upgrading one of four core statistics:

- **Movement Speed:** Increase your agility to dodge complex bullet patterns effectively.
- **Attack Damage:** Deal more damage per shot to clear high-health enemies faster.
- **Fire Rate:** Increase your weapon's attack speed to flood the screen with projectiles.
- **Maximum Health:** Boost your survivability to withstand more mistakes.

---

## 🛠️ Isolet2d Implementation Features

This demo highlights how to handle fundamental 2D game loops and systems using Isolet2d:

- **Pre-Spawned Layouts:** Efficient handling of object instantiation and positioning on the grid at stage start.
- **State Management:** Clear stage transitions triggered strictly when `Current Enemy Count == 0`.
- **Dynamic Modifiers:** Scaling enemy and player stat matrices sequentially using Isolet2d's core architecture.
