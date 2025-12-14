# How to See New World Generation (Grass, Dirt, Sand)

## Problem
If you're seeing only dirt blocks and the same terrain every time, you're loading a **saved world** that has old terrain stored in a database file. The generator is set up correctly, but saved worlds load from the database instead of generating new terrain.

## Solutions

### Option 1: Create a New World (Easiest)
1. In the game menu, create a **new world** with a new name
2. This will generate fresh terrain using the new generator
3. You should see grass, dirt, and sand blocks

### Option 2: Delete the Saved World Database
1. Find your world's database file:
   - Location: `user://worlds/[world_id]/voxels.sqlite`
   - Or check the console output when loading - it shows the database path
2. Delete the `voxels.sqlite` file
3. Reload the world - it will regenerate with the new generator

### Option 3: Force Regeneration (In-Game)
1. While in-game, press **Ctrl+R** (or Cmd+R on Mac)
2. This will clear the database and force regeneration
3. You should see new terrain with grass, dirt, and sand

### Option 4: Use the Console
If you have access to the Godot console, you can call:
```gdscript
WorldSaveSystem.regenerate_current_world()
```

## Debug Output
When you load a world, check the console for:
- "WARNING: Loading existing world database..." = You're loading old terrain
- "No existing database found - will generate fresh terrain" = New generation will happen
- "SimpleWorldGenerator: Generated chunk..." = Generator is working
- Block counts showing "Grass: X, Dirt: Y, Sand: Z" = Generator is creating the right blocks

## Verify Generator is Working
1. Create a **completely new world** with a unique name
2. Check the console for "Set up SimpleWorldGenerator" message
3. Look for "Generated chunk" messages with block counts
4. You should see grass on surface, dirt underground, sand in deserts
