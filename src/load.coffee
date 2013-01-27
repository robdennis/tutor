if typeof window is 'undefined'
  module.exports = require(xxx = 'cheerio').load
else
  module.exports = (args...) ->
    $el = jQuery args...
    (selector) ->
      if typeof selector is 'string' then $el.find selector else $el
