require('vis')
vis.events.subscribe(vis.events.INIT, function() vis:command('set theme tokyonight') end)
vis.events.subscribe(vis.events.WIN_OPEN, function() vis:command('set number') end)
