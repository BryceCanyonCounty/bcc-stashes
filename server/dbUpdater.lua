CreateThread(function()
    -- Create the stashes table if it doesn't exist
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `stashes` (
            `id` UUID NOT NULL,
            `charid` VARCHAR(50) NOT NULL,
            `name` VARCHAR(50) DEFAULT NULL,
            `propname` VARCHAR(255) DEFAULT NULL,
            `x` DOUBLE DEFAULT NULL,
            `y` DOUBLE DEFAULT NULL,
            `z` DOUBLE DEFAULT NULL,
            `h` DOUBLE DEFAULT NULL,
            `pickedup` TINYINT(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Check if the pickedup column exists and add if it doesn't
    local pickedupResult = MySQL.query.await("SHOW COLUMNS FROM `stashes` LIKE 'pickedup'")
    if #pickedupResult == 0 then
        MySQL.query.await("ALTER TABLE `stashes` ADD COLUMN `pickedup` TINYINT(1) NOT NULL DEFAULT 0")
    end

    -- Check if the charid column exists and add if it doesn't
    local charidResult = MySQL.query.await("SHOW COLUMNS FROM `stashes` LIKE 'charid'")
    if #charidResult == 0 then
        MySQL.query.await("ALTER TABLE `stashes` ADD COLUMN `charid` VARCHAR(50) NOT NULL")
    end

    -- Insert or update items in the items table
    MySQL.query.await([[
        INSERT INTO `items`(`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
        VALUES ('chest1', 'Chest 1', 5, 1, 'item_standard', 1, 'Storage Chest')
        ON DUPLICATE KEY UPDATE `item`='chest1', `label`='Chest 1', `limit`=5, `can_remove`=1, `type`='item_standard', `usable`=1, `desc`='Storage Chest';
    ]])

    MySQL.query.await([[
        INSERT INTO `items`(`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
        VALUES ('chest2', 'Chest 2', 5, 1, 'item_standard', 1, 'Storage Chest')
        ON DUPLICATE KEY UPDATE `item`='chest2', `label`='Chest 2', `limit`=5, `can_remove`=1, `type`='item_standard', `usable`=1, `desc`='Storage Chest';
    ]])

    -- Debug message for successful table creation or update
    print("Database table \x1b[35m\x1b[1m*stashes*\x1b[0m created or updated \x1b[32msuccessfully\x1b[0m.")
    print("Items inserted or updated \x1b[32msuccessfully\x1b[0m.")
end)
