local web      = require("catke/web")
local config   = require("./config")

local app = web.route('/', require('./app/handlers/index'))

-- 加载静态目录中间件
web.use(require('catke/web/static')(config['sataic_path']))
web.use(require('./app/middlewares/postgres')) -- 连接 postgres

web.createServer(app, config):listen(config['port'])

print("Server listening at http://localhost:" .. config['port'] .. "/")
