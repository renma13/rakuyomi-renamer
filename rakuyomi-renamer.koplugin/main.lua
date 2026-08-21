local bit = require("bit")
local DataStorage = require("datastorage")
local ffiutil = require("ffi/util")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local _ = require("gettext")

local band, bor, bxor, bnot = bit.band, bit.bor, bit.bxor, bit.bnot
local rshift, lshift, rrotate = bit.rshift, bit.lshift, bit.ror

local EXPORT_FOLDER_NAME = "rakuyomi-renamed"

local RakuyomiRenamer = InputContainer:extend({
    name = "rakuyomi_renamer",
})

local K = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function add32(...)
    local sum = 0
    for i = 1, select("#", ...) do
        sum = band(sum + select(i, ...), 0xffffffff)
    end
    return sum
end

local function be32(s, i)
    local b1, b2, b3, b4 = s:byte(i, i + 3)
    return bor(lshift(b1, 24), lshift(b2, 16), lshift(b3, 8), b4)
end

local function sha256_bytes(message)
    local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
    local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    local bit_len = #message * 8

    message = message .. string.char(0x80)
    while (#message % 64) ~= 56 do
        message = message .. string.char(0)
    end

    local high = math.floor(bit_len / 0x100000000)
    local low = bit_len % 0x100000000
    message = message .. string.char(
        band(rshift(high, 24), 0xff), band(rshift(high, 16), 0xff), band(rshift(high, 8), 0xff), band(high, 0xff),
        band(rshift(low, 24), 0xff), band(rshift(low, 16), 0xff), band(rshift(low, 8), 0xff), band(low, 0xff)
    )

    for chunk = 1, #message, 64 do
        local w = {}
        for i = 0, 15 do
            w[i] = be32(message, chunk + i * 4)
        end
        for i = 16, 63 do
            local s0 = bxor(rrotate(w[i - 15], 7), rrotate(w[i - 15], 18), rshift(w[i - 15], 3))
            local s1 = bxor(rrotate(w[i - 2], 17), rrotate(w[i - 2], 19), rshift(w[i - 2], 10))
            w[i] = add32(w[i - 16], s0, w[i - 7], s1)
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
        for i = 0, 63 do
            local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
            local ch = bxor(band(e, f), band(bnot(e), g))
            local temp1 = add32(h, S1, ch, K[i + 1], w[i])
            local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
            local maj = bxor(band(a, b), band(a, c), band(b, c))
            local temp2 = add32(S0, maj)
            h, g, f, e, d, c, b, a = g, f, e, add32(d, temp1), c, b, a, add32(temp1, temp2)
        end

        h0, h1, h2, h3 = add32(h0, a), add32(h1, b), add32(h2, c), add32(h3, d)
        h4, h5, h6, h7 = add32(h4, e), add32(h5, f), add32(h6, g), add32(h7, h)
    end

    local out = {}
    for _, n in ipairs({ h0, h1, h2, h3, h4, h5, h6, h7 }) do
        out[#out + 1] = string.char(
            band(rshift(n, 24), 0xff), band(rshift(n, 16), 0xff), band(rshift(n, 8), 0xff), band(n, 0xff)
        )
    end
    return table.concat(out)
end

local function base64url_no_pad(bytes)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    local out = {}
    for i = 1, #bytes, 3 do
        local b1 = bytes:byte(i)
        local b2 = bytes:byte(i + 1)
        local b3 = bytes:byte(i + 2)
        local n = lshift(b1, 16) + lshift(b2 or 0, 8) + (b3 or 0)
        out[#out + 1] = alphabet:sub(band(rshift(n, 18), 0x3f) + 1, band(rshift(n, 18), 0x3f) + 1)
        out[#out + 1] = alphabet:sub(band(rshift(n, 12), 0x3f) + 1, band(rshift(n, 12), 0x3f) + 1)
        if b2 then
            out[#out + 1] = alphabet:sub(band(rshift(n, 6), 0x3f) + 1, band(rshift(n, 6), 0x3f) + 1)
        end
        if b3 then
            out[#out + 1] = alphabet:sub(band(n, 0x3f) + 1, band(n, 0x3f) + 1)
        end
    end
    return table.concat(out)
end

local function rakuyomi_hashed_filename(source_id, manga_id, chapter_id)
    return base64url_no_pad(sha256_bytes(source_id .. manga_id .. chapter_id)) .. ".cbz"
end

local function exists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

local function copy_file(source, target)
    local input = io.open(source, "rb")
    if not input then
        return nil, "could not open source"
    end

    local output = io.open(target, "wb")
    if not output then
        input:close()
        return nil, "could not open target"
    end

    while true do
        local chunk = input:read(1024 * 64)
        if not chunk then
            break
        end
        output:write(chunk)
    end

    input:close()
    output:close()
    return true, nil
end

local function sanitize_filename(value)
    value = tostring(value or ""):gsub("[\r\n\t]", " "):gsub("[/\\:*?\"<>|]", "-"):gsub("%s+", " ")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return "Unknown"
    end
    return value
end

local function number_text(value)
    if value == nil then
        return nil
    end
    local n = tonumber(value)
    if n == nil then
        return tostring(value)
    end
    if math.floor(n) == n then
        return tostring(math.floor(n))
    end
    return tostring(n)
end

local function chapter_filename(manga, chapter)
    local parts = { sanitize_filename(manga.title) }
    local volume = number_text(chapter.volume_num)
    local chapter_num = number_text(chapter.chapter_num)

    if volume then
        parts[#parts + 1] = "Vol. " .. volume
    end
    if chapter_num then
        parts[#parts + 1] = "Ch. " .. chapter_num
    end
    if chapter.title and chapter.title ~= "" and chapter.title ~= "Unknown title" then
        parts[#parts + 1] = sanitize_filename(chapter.title)
    end

    return table.concat(parts, " - ") .. ".cbz"
end

local function show_message(text)
    UIManager:show(InfoMessage:new({ text = text, timeout = 5 }))
end

function RakuyomiRenamer:init()
    if self.ui.name ~= "ReaderUI" then
        self.ui.menu:registerToMainMenu(self)
    end
end

function RakuyomiRenamer:addToMainMenu(menu_items)
    menu_items.rakuyomi_renamer = {
        text = _("Rakuyomi Renamer"),
        sorting_hint = "tools",
        callback = function()
            self:scanAndConfirm()
        end,
    }
end

function RakuyomiRenamer:getRakuyomiBackend()
    local plugin_dir = debug.getinfo(1, "S").source:gsub("^@", ""):gsub("/[^/]*$", "")
    local rakuyomi_dir = ffiutil.realpath(plugin_dir .. "/../rakuyomi.koplugin")
    if not rakuyomi_dir then
        return nil, _("Could not find rakuyomi.koplugin next to this plugin.")
    end

    package.path = rakuyomi_dir .. "/?.lua;" .. package.path
    local ok, Backend = pcall(require, "Backend")
    if not ok then
        return nil, _("Could not load Rakuyomi's backend helper: ") .. tostring(Backend)
    end

    if Backend.server == nil then
        local initialized, logs = Backend.initialize()
        if not initialized then
            return nil, _("Could not start Rakuyomi backend.") .. "\n\n" .. tostring(logs)
        end
    end

    return Backend, nil
end

function RakuyomiRenamer:getDownloadsPath(Backend)
    local response = Backend.getSettings()
    if response.type == "ERROR" then
        return nil, response.message
    end
    if response.body.storage_path then
        return response.body.storage_path
    end
    return DataStorage:getDataDir() .. "/rakuyomi/downloads", nil
end

function RakuyomiRenamer:getExportPath()
    local path = DataStorage:getDataDir() .. "/" .. EXPORT_FOLDER_NAME
    os.execute("mkdir -p " .. string.format("%q", path))
    return path
end

function RakuyomiRenamer:buildRenamePlan()
    local Backend, err = self:getRakuyomiBackend()
    if not Backend then
        return nil, err
    end

    local downloads_path
    downloads_path, err = self:getDownloadsPath(Backend)
    if not downloads_path then
        return nil, err
    end

    local library_response = Backend.getMangasInLibrary()
    if library_response.type == "ERROR" then
        return nil, library_response.message
    end

    local export_path = self:getExportPath()
    local plan = {}
    local skipped = 0

    for _, manga in ipairs(library_response.body) do
        local chapter_response = Backend.listCachedChapters(manga.source.id, manga.id)
        if chapter_response.type == "SUCCESS" then
            for _, chapter in ipairs(chapter_response.body) do
                if chapter.downloaded then
                    local current = downloads_path .. "/" .. rakuyomi_hashed_filename(manga.source.id, manga.id, chapter.id)
                    local target = export_path .. "/" .. chapter_filename(manga, chapter)
                    if current ~= target and exists(current) then
                        if exists(target) then
                            skipped = skipped + 1
                        else
                            plan[#plan + 1] = {
                                current = current,
                                target = target,
                            }
                        end
                    else
                        skipped = skipped + 1
                    end
                end
            end
        else
            logger.warn("Rakuyomi Renamer: could not list chapters for ", manga.title, ": ", chapter_response.message)
        end
    end

    return {
        items = plan,
        skipped = skipped,
        downloads_path = downloads_path,
        export_path = export_path,
    }, nil
end

function RakuyomiRenamer:scanAndConfirm()
    local plan, err = self:buildRenamePlan()
    if not plan then
        show_message(_("Rakuyomi Renamer failed: ") .. tostring(err))
        return
    end

    if #plan.items == 0 then
        show_message(_("No Rakuyomi downloads need exporting."))
        return
    end

    UIManager:show(ConfirmBox:new({
        text = _("Export ") .. #plan.items .. _(" friendly-named chapter file(s)?\n\nFrom:\n") ..
            plan.downloads_path .. _("\n\nTo:\n") .. plan.export_path,
        ok_text = _("Export"),
        ok_callback = function()
            self:runRenamePlan(plan)
        end,
    }))
end

function RakuyomiRenamer:runRenamePlan(plan)
    local exported = 0
    local failed = 0

    for _, item in ipairs(plan.items) do
        local ok, copy_err = copy_file(item.current, item.target)
        if ok then
            exported = exported + 1
        else
            failed = failed + 1
            logger.warn("Rakuyomi Renamer: could not copy ", item.current, " to ", item.target, ": ", copy_err)
        end
    end

    show_message(_("Exported ") .. exported .. _(" file(s). Failed: ") .. failed .. _(". Skipped: ") .. plan.skipped .. ".")
end

return RakuyomiRenamer
