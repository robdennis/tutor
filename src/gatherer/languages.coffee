cheerio     = require 'cheerio'
_           = require 'underscore'

gatherer    = require '../gatherer'
languages   = require '../languages'
pagination  = require '../pagination'


module.exports = (details, callback) ->
  $$ = (fn) -> (err, res, body) -> if err then callback err else fn body

  fetch 1, details, $$ (html) ->
    {max} = pagination cheerio.load(html) \
      '#ctl00_ctl00_ctl00_MainContent_SubContent_SubContent_languageList_pagingControls'
    if max is 1
      callback null, merge extract html
      return
    results = [extract html]
    for page in [2..max]
      fetch page, details, $$ (html) ->
        results.push extract html
        callback null, merge [].concat results... if results.length is max
  return

fetch = (page, details, callback) ->
  url = gatherer.card.url 'Languages.aspx', details, {page}
  gatherer.request url, callback

extract = (html) ->
  $ = cheerio.load html
  _.map $('tr.cardItem'), (el) ->
    [trans_card_name, language] = $(el).children()
    $name = $(trans_card_name)
    code = languages[$(language).text().trim()]
    name = $name.text().trim()
    id = +$name.find('a').attr('href').match(/multiverseid=(\d+)/)[1]
    [code, name, id]

merge = (results) ->
  o = {}
  for [code, name, id] in results
    o[code] ?= name: name, ids: []
    o[code].ids.push id
  for code of o
    o[code].ids.sort()
  o
