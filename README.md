# BCC - Stashes

> A comprehensive RedM script for managing player stashes with advanced functionality and modern database management.

## Features

### **Core Functionality**

- Allows players to place, pick up, and manage chests or containers (stashes) in-game
- Supports dynamic stash creation and reuse of picked-up chests
- Tracks stash state (`pickedup` or not) and updates the database accordingly
- Integrated job and grade restrictions for opening stashes

### **Advanced Configuration**

- **Two Types of Storage**:
  - **Props**: Placeable/pickupable chests that players can carry and place
  - **Spots**: Permanent storage locations with fixed positions
- **PickupEmptyOnly Restriction**: Configure chests to only be picked up when empty
- **Job-Based Access Control**: Restrict access by job type and minimum grade levels
- **Item Blacklisting**: Prevent specific items from being stored in containers

### **Modern Database Management**

- **Migration System**: Automatic database schema updates with version tracking
- **Database Abstraction**: Compatible with both MySQL and OxMySQL
- **Console Commands**: Administrative tools for database management
  - `bcc-stashes:seed` - Force re-seed items (console only)
  - `bcc-stashes:verify` - Verify all items exist in database (console only)

### **Enhanced User Experience**

- **Multilingual Support**: Complete translations for English, German, French, and Romanian
- **Smart Notifications**: Context-aware user feedback for all actions
- **Improved Error Handling**: Comprehensive validation and user-friendly error messages
- **Advanced Debugging**: Enhanced logging system with configurable debug levels

## Dependencies

- [vorp_core](https://github.com/VORPCORE/vorp-core-lua)
- [vorp_inventory](https://github.com/VORPCORE/vorp_inventory-lua)
- [vorp_character](https://github.com/VORPCORE/vorp_character-lua)
- [bcc-utils](https://github.com/BryceCanyonCounty/bcc-utils)

## Installation

1. **Download and Extract**:
   - Download this repository.
   - Extract and place the `bcc-stashes` folder into your server's `resources` directory.

2. **Automatic Database Setup**:
   - The script includes a modern database management system with migration support
   - Database tables and items are automatically created and seeded upon resource start
   - The system supports both MySQL and OxMySQL database connectors
   - Migration versioning ensures smooth updates between script versions

3. **Configuration**:
   - Configure your stash properties in `shared/configs/props.lua`
   - Set up permanent storage spots in `shared/configs/spots.lua`
   - Adjust main settings in `shared/configs/main.lua`

4. **Add to Server Configuration**:
   - Open your `server.cfg` file and add:

     ```cfg
     ensure bcc-stashes
     ```

   - Restart your server (or wait for your nightly restart)

5. **Administrative Commands** (Console Only):
   - `bcc-stashes:seed` - Force re-seed all items to database
   - `bcc-stashes:verify` - Verify all configured items exist in database

## Configuration

### **Props Configuration** (`shared/configs/props.lua`)

Configure placeable/pickupable chest items:

```lua
Props = {
    p_chest01x = {
        dbname = 'chest1',                       -- Item name in database
        hash = 'p_chest01x',                     -- Prop hash
        ContainerName = "Stash1",                -- Display name
        limit = 250,                             -- Storage slots
        JobOnly = false,                         -- Job restriction
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            unemployed = 0,                      -- Job name = minimum required grade
            police = 2,                          -- Job name = minimum required grade
            sheriff = 3,                         -- Job name = minimum required grade
        },
        Shared = true,                           -- Shared storage
        NotAllowedItems = true,                  -- Enable item blacklist
        Items = { 'canteen' },                   -- Blacklisted items
        PickupEmptyOnly = true,                  -- Only pickup when empty
    },
}
```

### **Spots Configuration** (`shared/configs/spots.lua`)

Configure permanent storage locations:

```lua
Spots = {
    teststorage1 = {
        coords = vec3(-325.26, 766.19, 121.65), -- Storage location
        heading = 180.0,                         -- Prop heading
        containerid = "Testing2",                -- Unique container ID
        ContainerName = "Stash",                 -- Display name
        limit = 250,                             -- Storage slots
        JobOnly = false,                         -- Job restriction
        JobRestrictions = {                      -- Job restrictions with individual grade requirements
            unemployed = 0,                      -- Job name = minimum required grade
            police = 2,                          -- Job name = minimum required grade
            sheriff = 3,                         -- Job name = minimum required grade
        },
        Shared = true,                           -- Shared storage
        NotAllowedItems = true,                  -- Enable item blacklist
        Items = { 'canteen' },                   -- Blacklisted items
        prophash = "p_chestmedhunt01x"           -- Prop hash
    },
}
```

### **Main Configuration** (`shared/configs/main.lua`)

```lua
Config = {
    devMode = {
        active = false,                          -- Enable debug mode
    },
    defaultlang = 'en_lang',                    -- Default language
    keys = {
        Pickup = "G",                            -- Pickup key
        Open = "B"                               -- Open key
    },
}
```

## Language Support

Complete translations available for:

- **English** (`en_lang.lua`) - Default
- **German** (`de_lang.lua`) - Deutsch
- **French** (`fr_lang.lua`) - Français  
- **Romanian** (`ro_lang.lua`) - Română

## New Features in v2.0.0

- **Database Migration System**: Automatic schema updates with version tracking
- **PickupEmptyOnly Restriction**: Prevent pickup of non-empty chests
- **Enhanced Error Handling**: Better validation and user feedback
- **Console Commands**: Administrative database management tools
- **Complete Translations**: All languages fully translated
- **Improved Code Structure**: Refactored to match BCC coding standards
- **Database Abstraction**: Support for multiple database connectors
- **Per-Job Grade Requirements**: Each job can now have its own minimum grade requirement

## GitHub Repository

- [bcc-stashes](https://github.com/BryceCanyonCounty/bcc-stashes)
