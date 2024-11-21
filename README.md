# BCC - Stashes

> A comprehensive RedM script for managing player stashes with advanced functionality.

## Features
- Allows players to place, pick up, and manage chests or containers (stashes) in-game.
- Supports dynamic stash creation and reuse of picked-up chests.
- Tracks stash state (`pickedup` or not) and updates the database accordingly.
- Includes a global `StashTable` for efficient server-side management of stashes.
- Integrated job and grade restrictions for opening stashes.
- Fully compatible with VORP Inventory and includes blacklisting specific items.
- Debugging enabled through a `DevMode` for easier troubleshooting.

## Installation

1. **Download and Extract**:
   - Download this repository.
   - Extract and place the `bcc-stashes` folder into your server's `resources` directory.

2. **Automatic Database Setup**:
   - The script includes a `dbUpdater.lua` file for automatic database creation and updates.
   - The script will handle creating the necessary database tables automatically upon starting the resource.

3. **Add to Server Configuration**:
   - Open your `server.cfg` file and add:
     ```cfg
     ensure bcc-stashes
     ```
   - Restart your server (or wait for your nightly restart).

## Requirements
- [vorp_core](https://github.com/VORPCORE/vorp-core-lua)
- [vorp_inventory](https://github.com/VORPCORE/vorp_inventory-lua)
- [vorp_character](https://github.com/VORPCORE/vorp_character-lua)
- [bcc-utils](https://github.com/BryceCanyonCounty/bcc-utils)
- [bcc-crypt](https://github.com/BryceCanyonCounty/bcc-crypt)

## Support

- For issues, questions, or feature requests, please contact us or open an issue on the GitHub repository.
- Need more help? Join the bcc discord here: https://discord.gg/VrZEEpBgZJ
