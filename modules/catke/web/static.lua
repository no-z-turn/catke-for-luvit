--[[
静态文件处理
===========

## demo

```
#!lua
app = require('catke/web/static')(app, path)
```

]]
local fs = require 'fs'
local pathJoin = require('path').join
local urlParse = require('url').parse
local getType = require('mime').getType
local osDate = require('os').date
local iStream = require('core').iStream

local floor = require('math').floor
local table = require 'table'

-- For encoding numbers using bases up to 64
local digits = {
    "0", "1", "2", "3", "4", "5", "6", "7",
    "8", "9", "A", "B", "C", "D", "E", "F",
    "G", "H", "I", "J", "K", "L", "M", "N",
    "O", "P", "Q", "R", "S", "T", "U", "V",
    "W", "X", "Y", "Z", "a", "b", "c", "d",
    "e", "f", "g", "h", "i", "j", "k", "l",
    "m", "n", "o", "p", "q", "r", "s", "t",
    "u", "v", "w", "x", "y", "z", "_", "$"
}
local function numToBase(num, base)
    local parts = {}
    repeat
        table.insert(parts, digits[(num % base) + 1])
        num = floor(num / base)
    until num == 0
    return table.concat(parts)
end

local function calcEtag(stat)
    return (not stat.is_file and 'W/' or '') ..
            '"' .. numToBase(stat.ino or 0, 64) ..
            '-' .. numToBase(stat.size, 64) ..
            '-' .. numToBase(stat.mtime, 64) .. '"'
end

-- 对外发布
return function (app, root)

    return function (req, res)
        -- Ignore non-GET/HEAD requests
        if not (req.method == "HEAD" or req.method == "GET") then
            return app(req, res)
        end

        local serve = function(path, callback)

            fs.open(path, "r", function (err, fd)
                if err then
                    return app(req, res)
                end

                fs.fstat(fd, function (err, stat)
                    if err then
                        fs.close(fd)
                        return app(req, res)
                    end

                    local etag = calcEtag(stat)
                    local code = 200
                    local headers = {
                        ['Last-Modified'] = osDate("!%a, %d %b %Y %H:%M:%S GMT", stat.mtime),
                        ['ETag'] = etag
                    }
                 
                    if etag == req.headers['if-none-match'] then
                        code = 304
                    end

                    
                    if stat.is_directory then
                        -- Can't serve directories as files
                        fs.close(fd)
                        return res(302, {
                            ["Location"] = req.url.path .. "/"
                        })
                    end

                    headers["Content-Type"] = getType(path)
                    headers["Content-Length"] = stat.size

                    res:writeHead(code, headers)

                    fs.createReadStream(path):pipe(res)
                    fs.close(fd)
                    
                end)
            end)
            
        end

        local path = pathJoin(root, req.url.path)

        if path:sub(#path) == '/' then
            return app(req, res)
        else 
            fs.exists(path, function(err)
                
                if err then
                    return app(req, res)
                end

                return serve(path)
            end)
        end
    end
end

