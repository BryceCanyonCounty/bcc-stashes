---@type BCCStashesDebugLib
local DBG = BCCStashesDebug

local SEED_VERSION = 1

-- Generate items from Props config
local function generateItemsFromProps()
    local items = {}
    for propHash, propConfig in pairs(Props) do
        if propConfig.dbname then
            table.insert(items, {
                propConfig.dbname,
                propConfig.ContainerName or propConfig.dbname,
                5,
                1,
                'item_standard',
                1,
                'Storage Chest'
            })
        end
    end
    return items
end

local UPSERT_SQL = [[
INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `limit` = VALUES(`limit`), `can_remove` = VALUES(`can_remove`), `type` = VALUES(`type`), `usable` = VALUES(`usable`), `desc` = VALUES(`desc`);
]]

local CREATE_MIGRATIONS_SQL = [[
CREATE TABLE IF NOT EXISTS `resource_migrations` (
  `resource` VARCHAR(128) NOT NULL PRIMARY KEY,
  `version` INT NOT NULL
);
]]

local CREATE_STASHES_SQL = [[
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
]]

local function hasAwaitMySQL()
    return (MySQL ~= nil and MySQL.query ~= nil and MySQL.query.await ~= nil) or false
end

local function waitForDB(maxAttempts, delay)
    maxAttempts = maxAttempts or 8
    delay = delay or 500
    for i = 1, maxAttempts do
        if hasAwaitMySQL() then
            local ok = pcall(function() return MySQL.query.await('SELECT 1') end)
            if ok then return true end
        else
            if exports and (exports.mysql or exports.oxmysql) then
                return true
            end
        end
        Wait(delay)
        delay = delay * 2
    end
    return false
end

local function dbExecuteAwait(sql, params)
    if hasAwaitMySQL() then
        return MySQL.update.await(sql, params)
    end
    local done, result = false, nil
    local db = exports and (exports.mysql or exports.oxmysql) or nil
    if not db then error('No DB available') end
    db:execute(sql, params or {}, function(res)
        result = res
        done = true
    end)
    local tick = 0
    while not done and tick < 100 do
        Wait(50)
        tick = tick + 1
    end
    return result
end

local function dbQueryAwait(sql, params)
    if hasAwaitMySQL() then
        return MySQL.query.await(sql, params)
    end
    local done, result = false, nil
    local db = exports and (exports.mysql or exports.oxmysql) or nil
    if not db then error('No DB available') end
    db:execute(sql, params or {}, function(res)
        result = res
        done = true
    end)
    local tick = 0
    while not done and tick < 100 do
        Wait(50)
        tick = tick + 1
    end
    return result
end

local function ensureStashesSchema()
    local success, err = pcall(function()
        if hasAwaitMySQL() then
            MySQL.update.await(CREATE_STASHES_SQL)
        else
            dbExecuteAwait(CREATE_STASHES_SQL)
        end
    end)

    if not success then
        DBG.Error('Failed to create stashes table: ' .. tostring(err))
        return
    end

    -- Check and add missing columns
    local function addColumnIfMissing(columnName, columnDef)
        local checkResult = dbQueryAwait("SHOW COLUMNS FROM `stashes` LIKE ?", { columnName })
        if not checkResult or #checkResult == 0 then
            local alterSql = string.format("ALTER TABLE `stashes` ADD COLUMN %s", columnDef)
            local ok, alterErr = pcall(dbExecuteAwait, alterSql)
            if ok then
                DBG.Info(string.format("Added '%s' column to stashes table", columnName))
            else
                DBG.Error(string.format("Failed to add '%s' column: %s", columnName, tostring(alterErr)))
            end
        end
    end

    addColumnIfMissing('pickedup', '`pickedup` TINYINT(1) NOT NULL DEFAULT 0')
    addColumnIfMissing('charid', '`charid` VARCHAR(50) NOT NULL')
end

local function getMigrationVersion()
    if not waitForDB() then return 0 end

    if hasAwaitMySQL() then
        MySQL.update.await(CREATE_MIGRATIONS_SQL)
        local rows = MySQL.query.await('SELECT version FROM resource_migrations WHERE resource = ?', { GetCurrentResourceName() })
        if rows and rows[1] and rows[1].version then
            return tonumber(rows[1].version) or 0
        end
        return 0
    else
        dbExecuteAwait(CREATE_MIGRATIONS_SQL)
        local rows = dbQueryAwait('SELECT version FROM resource_migrations WHERE resource = ?', { GetCurrentResourceName() })
        if rows and rows[1] and rows[1].version then
            return tonumber(rows[1].version) or 0
        end
        return 0
    end
end

local function setMigrationVersion(v)
    if hasAwaitMySQL() then
        MySQL.update.await('INSERT INTO resource_migrations(resource, version) VALUES(?, ?) ON DUPLICATE KEY UPDATE version = VALUES(version);', { GetCurrentResourceName(), v })
    else
        dbExecuteAwait('INSERT INTO resource_migrations(resource, version) VALUES(?, ?) ON DUPLICATE KEY UPDATE version = VALUES(version);', { GetCurrentResourceName(), v })
    end
end

local function seedItems(force)
    if not waitForDB() then
        DBG.Warning('Database not available after retries; skipping seeding.')
        return
    end

    local currentVersion = 0
    local ok, err = pcall(function() currentVersion = getMigrationVersion() end)
    if not ok then
        DBG.Warning(string.format('Failed to get migration version: %s', tostring(err)))
        currentVersion = 0
    end

    if currentVersion >= SEED_VERSION and not force then
        DBG.Info(string.format('Items already seeded (version %s), skipping.', tostring(currentVersion)))
        return
    end

    DBG.Info('Seeding stash items...')
    local items = generateItemsFromProps()

    for _, item in ipairs(items) do
        local ok2, res = pcall(function()
            return dbExecuteAwait(UPSERT_SQL, { item[1], item[2], item[3], item[4], item[5], item[6], item[7] })
        end)
        if not ok2 then
            DBG.Error(string.format('Failed to upsert item %s: %s', tostring(item[1]), tostring(res)))
        else
            DBG.Info(string.format('Upserted item: %s', tostring(item[1])))
        end
    end

    pcall(function() setMigrationVersion(SEED_VERSION) end)
    DBG.Info(string.format('Seeding complete; set seed version to %s', tostring(SEED_VERSION)))
end

RegisterCommand('bcc-stashes:seed', function(source, args, raw)
    if source ~= 0 then
        DBG.Warning('bcc-stashes:seed can only be run from server console')
        return
    end
    seedItems(true)
end, true)

RegisterCommand('bcc-stashes:verify', function(source, args, raw)
    if source ~= 0 then
        DBG.Warning('bcc-stashes:verify can only be run from server console')
        return
    end
    if not waitForDB() then
        DBG.Warning('Database not available; cannot verify items.')
        return
    end

    local items = generateItemsFromProps()
    local missing = {}

    for _, item in ipairs(items) do
        local rows = dbQueryAwait('SELECT item FROM items WHERE item = ?', { item[1] })
        if not rows or #rows == 0 then
            table.insert(missing, item[1])
        end
    end

    if #missing == 0 then
        DBG.Info('All stash items present in the items table.')
    else
        DBG.Warning(string.format('Missing stash items: %s', table.concat(missing, ', ')))
    end
end, true)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(1000)
        local ok, err = pcall(ensureStashesSchema)
        if not ok then
            DBG.Warning(string.format('Failed to ensure stashes schema: %s', tostring(err)))
        end
        seedItems(false)
    end)
end)
