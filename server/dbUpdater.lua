CreateThread(function()
    -- Create the stashes table if it doesn't exist
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `stashes` (
            `id` uuid NOT NULL,
            `charid` varchar(50) NOT NULL,
            `name` varchar(50) DEFAULT NULL,
            `propname` varchar(255) DEFAULT NULL,
            `x` double DEFAULT NULL,
            `y` double DEFAULT NULL,
            `z` double DEFAULT NULL,
            `h` double DEFAULT NULL,
            `pickedup` tinyint(1) NOT NULL DEFAULT 0,
            PRIMARY KEY (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
    ]])

    -- Add pickedup column to stashes if it doesn't exist
    MySQL.query.await("ALTER TABLE `stashes` ADD COLUMN IF NOT EXISTS `pickedup` tinyint(1) NOT NULL DEFAULT 0")

    -- Add charid column to stashes if it doesn't exist
    MySQL.query.await("ALTER TABLE `stashes` ADD COLUMN IF NOT EXISTS `charid` VARCHAR(50) NOT NULL")

    -- Debug message for successful table creation or update
    print("Database table \x1b[35m\x1b[1m*stashes*\x1b[0m created or updated \x1b[32msuccessfully\x1b[0m.")
end)
