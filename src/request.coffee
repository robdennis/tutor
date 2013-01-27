if typeof window is 'undefined'
  module.exports = require 'request'
else
  module.exports = (options, callback) ->
    options = url: options if typeof options is 'string'
    q = encodeURIComponent "select * from html where url=\"#{options.url}\""
    options.url = "http://query.yahooapis.com/v1/public/yql?q=#{q}&format=xml'&callback=?"
    options.dataType = 'json'
    options.success = (data, xxx, yyy, zzz) -> # TODO: what are these args?
      if data.results[0] # TODO: better check?
        callback null, {statusCode: 200}, data.results[0] # TODO: err, res, body
      else
        console.error 'something went wrong!' # TODO: better error message
    jQuery.ajax options
