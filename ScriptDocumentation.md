# Script Documentation - VoxelTools Spellbox Project

This document provides a brief overview of every script in the project to help prevent accidental overwrites or breaking changes during development.

## Core Game Systems

### Scripts/main.gd
**Purpose**: Main game bootstrap and manager coordinator
- Initializes VoxelWorldManager, terrain, and player
- Configures world resources (library, mesher, generator)
- Sets up game tick timers and random tick system
- Handles time-of-day lighting system
- Connects to WorldSaveSystem for save/load functionality
- Provides debug label updates and world regeneration hotkeys

### Scripts/character_controller.gd
**Purpose**: First-person player controller with voxel interaction
- Handles player movement (WASD), jumping, and camera rotation
- Uses VoxelBoxMover for collision detection with terrain
- Implements block destruction via raycast (left click)
- Creates item drops when blocks are destroyed
- Manages game-ready state to prevent movement before world loads
- Supports multiplayer position broadcasting via RPC

### Scripts/remote_character.gd
**Purpose**: Network synchronization for remote players
- Receives position updates from other players via RPC
- Minimal script for multiplayer character representation

### Scripts/random_ticks.gd
**Purpose**: Cellular automata system for terrain behavior
- Implements random tick system for grass spreading and dying
- Processes voxels in radius around players
- Handles grass-to-dirt conversion when covered
- Uses VoxelTool's blocky_random_tick for efficient processing

### Scripts/UPNPHelper.gd
**Purpose**: Network port forwarding helper for multiplayer
- Sets up UPNP port mappings for server hosting
- Handles automatic port forwarding discovery and cleanup
- Manages gateway configuration for multiplayer connectivity

---

## Block & Voxel Systems

### Scripts/Blocks/VoxelWorldManager.gd
**Purpose**: Central manager for all voxel world operations
- Manages VoxelTerrain and VoxelTool instances
- Handles dynamic voxel properties (temperature, friction, etc.)
- Integrates MaterialDatabase and SpellSystem
- Processes physics simulation (melting, freezing, state changes)
- Implements temperature propagation between neighboring blocks
- Manages voxel metadata storage for dynamic properties
- Handles world generation setup and seed management
- Creates item drops when voxels are destroyed
- Provides batch modification operations for efficiency

### Scripts/Blocks/StaticMaterialProperties.gd
**Purpose**: Defines static material properties per block type
- Stores material ID, name, and thermal properties
- Defines melting/freezing temperatures
- Contains default dynamic properties for each material
- Provides material configuration helpers (stone, wood, iron, etc.)
- Handles transmutation rules between materials

### Scripts/Blocks/DynamicVoxelProperties.gd
**Purpose**: Bit-packed dynamic properties stored per voxel
- Stores temperature, conductivity, toughness, elasticity
- Tracks moisture, loudness, heat capacity, charge level
- Uses 32-bit packed data for efficient storage
- Provides getters/setters for all property types
- Converts to/from voxel metadata format
- Includes temperature lookup table (0-3000K in 32 steps)

### Scripts/Blocks/MaterialDatabase.gd
**Purpose**: Registry of all block materials and their properties
- Initializes default materials (air, dirt, grass, sand, stone, wood, iron, glass, water, lava)
- Maps material IDs to StaticMaterialProperties
- Provides material lookup and registration functions
- Checks state changes (melting, freezing, conductivity breakdown)
- Used by VoxelWorldManager for material queries

### Scripts/Blocks/SpellSystem.gd
**Purpose**: Magical spell casting and property modification system
- Defines spell effects with various emitter shapes (sphere, cube, cone, line, plane)
- Manages active spells with duration tracking
- Provides predefined spell modifiers (reduce friction, temperature changes, etc.)
- Handles spell restoration when effects expire
- Supports combined spell effects (multiple modifiers)
- Includes spell history for undo functionality
- Processes spell modifications in batches for performance

### Scripts/Blocks/PlayerSpellcaster.gd
**Purpose**: Player interface for casting spells
- Manages spell inventory and selection
- Handles spell casting via raycast from camera
- Provides spell cooldown system
- Creates visual effects for spell casting
- Integrates with VoxelWorldManager for spell application

### blocks/rail/rail.gd
**Purpose**: Special block behavior for rail placement
- Handles automatic rail orientation based on neighbors
- Supports straight, turn, and slope rail variants
- Implements rail connection logic
- Auto-orients rails when placed near existing rails

---

## World Generation

### Scripts/WorldGeneration/SimpleWorldGenerator.gd
**Purpose**: Basic 4-block world generator
- Generates terrain using only air, dirt, grass, and sand
- Uses FastNoiseLite for height maps and biome determination
- Creates desert and grass biomes
- Implements cave generation via noise
- Simple and fast for testing/development

### Scripts/WorldGeneration/BiomeWorldGenerator.gd
**Purpose**: Comprehensive world generator with all block types
- Generates multiple biomes (mountain, forest, plains, swamp)
- Places trees, decorations, and structures
- Uses multiple noise generators for different features
- Supports all block types from voxel library
- More complex but feature-rich generation

### Scripts/WorldGeneration/StructureGenerator.gd
**Purpose**: Places pre-built structures in the world
- Generates cabins, mine entrances, bridges, and rail tracks
- Uses block IDs matching voxel library
- Places structures at surface level
- Static helper functions for structure placement

---

## Inventory System

### Scripts/Inventory/Inventory.gd
**Purpose**: Core inventory data structure
- Manages array of ItemStack slots
- Handles item addition/removal with stacking logic
- Provides slot swapping and clearing functions
- Emits signals for inventory changes

### Scripts/Inventory/InventoryManager.gd
**Purpose**: Coordinates entire inventory system
- Initializes item database with all available items
- Creates and manages Inventory, HotbarUI, and InventoryUI
- Handles item lookup by ID
- Manages hotbar selection
- Toggles inventory UI visibility

### Scripts/Inventory/Item.gd
**Purpose**: Base item data structure
- Stores item ID, name, description, icon
- Defines item types (material, tool, weapon, consumable, block)
- Handles stack size limits
- Provides item comparison for stacking

### Scripts/Inventory/ItemStack.gd
**Purpose**: Represents a stack of items in inventory
- Tracks item and quantity
- Handles adding/removing items from stack
- Supports stack splitting
- Manages stack size limits

### Scripts/Inventory/ItemDrop.gd
**Purpose**: Physical item representation in world
- RigidBody3D that can be picked up
- Magnetic attraction to player when nearby
- Auto-pickup when very close to player
- Creates visual representation based on item type
- Integrates with InventoryManager for pickup

### Scripts/Inventory/InventoryUI.gd
**Purpose**: Main inventory window UI
- 6x4 grid (24 slots) inventory display
- Handles slot clicking and drag-and-drop (partial implementation)
- Shows/hides inventory panel
- Manages mouse capture release when open

### Scripts/Inventory/InventorySlotUI.gd
**Purpose**: Individual inventory slot UI component
- Displays item icon and quantity
- Shows selection highlight
- Handles mouse input for slot interaction
- Used by both hotbar and main inventory

### Scripts/Inventory/HotbarUI.gd
**Purpose**: Hotbar UI with 6 quick-access slots
- Displays first 6 inventory slots
- Handles number key selection (1-6)
- Supports mouse wheel scrolling
- Shows selected slot highlight
- Positioned at bottom center of screen

---

## Saving System

### Scripts/Saving/SaveService.gd
**Purpose**: Character save/load service (autoload singleton)
- Manages character data persistence
- Handles character creation, deletion, renaming
- Stores character icons
- Provides character directory management

### Scripts/Saving/WorldSaveSystem.gd
**Purpose**: World save/load system (autoload singleton)
- Manages world creation and deletion
- Handles voxel data via VoxelStreamSQLite
- Saves/loads dynamic voxel properties per chunk
- Stores active spells and world statistics
- Implements auto-save functionality (5-minute intervals)
- Provides world regeneration capabilities
- Signals game ready state to character controller

### Scripts/Saving/WorldData.gd
**Purpose**: World metadata resource
- Stores world name, type, seed, creation date
- Tracks playtime and last played timestamp
- Contains player position and inventory data
- Stores world statistics (blocks placed/destroyed, etc.)
- Holds world settings (difficulty, enabled features)

### Scripts/Saving/CharacterData.gd
**Purpose**: Character metadata resource
- Stores character name, level, archetype
- Tracks stats, inventory, playtime
- Manages creation and last played timestamps
- Provides formatted display strings

---

## Menu System

### Scripts/Menu/main_menu.gd
**Purpose**: Main menu navigation and game flow
- Manages menu container visibility (home, character select, world select, multiplayer, settings)
- Handles singleplayer and multiplayer game startup
- Coordinates character and world selection flow
- Creates and manages game world container
- Positions hotbar and inventory UI on screen
- Handles return to menu from game

### Scripts/Menu/CharacterSelect.gd
**Purpose**: Character selection screen
- Lists all available characters
- Handles character creation, renaming, deletion
- Sorts characters by last played
- Emits character selection signals

### Scripts/Menu/CharacterListItem.gd
**Purpose**: Individual character list item UI
- Displays character name, level, archetype, last played
- Handles selection highlighting
- Supports double-click and play button
- Shows character icon (placeholder)

### Scripts/Menu/WorldSelect.gd
**Purpose**: World selection screen
- Lists all available worlds
- Handles world creation with dialog (name, type, seed)
- Supports world deletion
- Emits world selection signals

### Scripts/Menu/WorldListItem.gd
**Purpose**: Individual world list item UI
- Displays world name, type, last played, playtime
- Handles selection highlighting
- Supports double-click and play button

---

## Tools & Utilities

### Scripts/Tools/VoxelAtlasSetup.gd
**Purpose**: Editor tool for creating voxel library with texture atlas
- Creates VoxelBlockyLibrary resource
- Sets up texture atlas material
- Configures block models with atlas coordinates
- Generates basic block types (stone, wood, iron, glass, water, lava, grass)
- Must be run from Script Editor

### Scripts/Tools/GenerateTextureAtlas.gd
**Purpose**: Editor tool for generating texture atlas image
- Creates 256x256 texture atlas (16x16 tiles)
- Generates procedural textures for each block type
- Saves atlas as PNG file
- Creates reference documentation for atlas layout
- Must be run from Script Editor

### fix_texture_bleeding.gd
**Purpose**: Editor tool for diagnosing texture bleeding issues
- Checks material filter settings
- Provides recommendations for fixing texture bleeding
- Validates texture import settings
- Must be run from Script Editor

### fix_atlas_bleeding.gd
**Purpose**: Editor tool for fixing texture atlas bleeding
- Attempts to adjust UV coordinates in voxel library
- Provides diagnostic information
- Note: Limited functionality due to mesh access constraints

### make_fix_zip.py
**Purpose**: Python utility for fixing resource path references
- Scans all .gd, .tscn, .tres files
- Rewrites stale script/resource references to current locations
- Creates ZIP with corrected files
- Handles hardcoded resource path moves
- Useful for project migration/cleanup

---

## Key System Interactions

1. **World Initialization Flow**:
   - main.gd → VoxelWorldManager → MaterialDatabase + SpellSystem
   - WorldSaveSystem loads world data and signals game ready
   - Character controller enables movement after game ready

2. **Block Destruction Flow**:
   - character_controller.gd raycasts and destroys block
   - VoxelWorldManager emits voxel_destroyed signal
   - ItemDrop created with material mapping
   - InventoryManager handles pickup

3. **Spell Casting Flow**:
   - PlayerSpellcaster raycasts target position
   - SpellSystem creates spell effect
   - VoxelWorldManager applies property modifications
   - Properties stored in voxel metadata

4. **Save/Load Flow**:
   - WorldSaveSystem saves voxel data via VoxelStreamSQLite
   - Dynamic properties saved per chunk in separate files
   - World metadata saved as WorldData resource
   - Character data saved via SaveService

---

## Important Notes

- **Dynamic Properties**: Stored per-voxel in metadata, bit-packed for efficiency
- **Static Properties**: Stored per-material-ID in MaterialDatabase
- **Spell System**: Modifies dynamic properties temporarily, restores on expiration
- **Inventory**: First 6 slots are hotbar, remaining 18 are main inventory
- **World Generation**: SimpleWorldGenerator uses 4 blocks, BiomeWorldGenerator uses all blocks
- **Multiplayer**: Basic RPC position sync implemented, full networking not complete

---

## Files Not Documented

- Scene files (.tscn) - These are Godot scene definitions, not scripts
- Resource files (.tres) - These are Godot resource definitions, not scripts
- Import files (.import) - Godot asset import metadata
- Python files other than make_fix_zip.py - None found
