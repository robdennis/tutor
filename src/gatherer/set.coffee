url         = require 'url'

cheerio     = require 'cheerio'
Q           = require 'q'
_           = require 'underscore'

gatherer    = require '../gatherer'
rarities    = require '../rarities'
supertypes  = require '../supertypes'


module.exports = (name, callback) ->
  common_params =
    advanced: 'true'
    set: """["#{name}"]"""
    special: 'true'

  gatherer.request gatherer.url(
    '/Pages/Search/Default.aspx'
    _.extend output: 'checklist', common_params
  ), (err, res) ->
    if err?
      callback err
      return

    $ = cheerio.load res.body
    cards$ = _.map $('.cardItem'), (el) ->
      get = (selector) -> $(el).find(selector).text()

      color_indicator: get('.color')
      name: get('.name')
      rarity: rarities[get('.rarity')]

    Q.all _.map _.range(Math.ceil cards$.length / 25), (page) ->
      deferred = Q.defer()
      gatherer.request gatherer.url(
        '/Pages/Search/Default.aspx'
        _.extend output: 'standard', page: "#{page}", common_params
      ), deferred.makeNodeResolver()
      deferred.promise
    .then (xs) ->
      for [res] in xs
        for card_name, versions of extract res.body, name
          for card, idx in versions
            card$ = (c$ for c$ in cards$ when c$.name is card_name)[idx]
            _.extend card$, card
            card$.expansion = name
            color = card$.color_indicator
            delete card$.color_indicator unless (
              color is 'White' and not /W/.test(card$.mana_cost) or
              color is 'Blue'  and not /U/.test(card$.mana_cost) or
              color is 'Black' and not /B/.test(card$.mana_cost) or
              color is 'Red'   and not /R/.test(card$.mana_cost) or
              color is 'Green' and not /G/.test(card$.mana_cost)
            )
      callback null, cards$
    .catch callback

  return

extract = (html, name) ->

  $ = cheerio.load html
  t = (el) -> gatherer._get_text $ el

  cards_mapping$ = {}

  _.chain $('.cardItem').find('.setVersions').find('img')
  .filter (el) -> $(el).attr('alt').indexOf("#{name} (") is 0
  .each (el) ->
    $el = $(el).closest('.cardItem')
    $card_title = $el.find('.cardTitle')
    [param] = /multiverseid=\d+/.exec $(el).parent().attr('href')

    card$ =
      name: t $card_title
      converted_mana_cost: 0
      supertypes: []
      types: []
      subtypes: []
      gatherer_url: "#{gatherer.origin}/Pages/Card/Details.aspx?#{param}"
      image_url: "#{gatherer.origin}/Handlers/Image.ashx?#{param}&type=card"

    mana_cost = t $el.find('.manaCost')
    card$.mana_cost = mana_cost unless mana_cost is ''
    card$.converted_mana_cost = to_converted_mana_cost mana_cost

    [..., types, subtypes] =
      /^([^\u2014]+?)(?:\s+\u2014\s+(.+))?$/m.exec t $el.find('.typeLine')
    for type in types.split(/\s+/)
      card$[if type in supertypes then 'supertypes' else 'types'].push type
    if subtypes
      card$.subtypes = subtypes.split(/\s+/)

    card$.text = _.map($el.find('.rulesText').find('p'), t).join('\n\n')

    match = ///
      (Vanguard\s*)?
      [(]
      ([^/]*(?:[{][^}]+[}])?) # power | hand modifier
      /
      ([^/]*(?:[{][^}]+[}])?) # toughness | life modifier
      [)]
    $///.exec $el.find('.typeLine').text()
    if match?
      _.extend card$, _.object(
        if match[1]?
          ['hand_modifier', 'life_modifier']
        else
          ['power', 'toughness']
        _.map match[2..3], gatherer._to_stat
      )

    match = /[(](\d+)[)]$/.exec $el.find('.typeLine').text()
    if match?
      card$.loyalty = +match[1]

    card$.versions =
      _.object _.map $el.find('.setVersions').find('img'), (el) ->
        _.rest /^(.*) [(](.*?)[)]$/.exec $(el).attr('alt')

    arr$ = cards_mapping$[card$.name] ?= []
    arr$.push card$
    arr$.sort (a, b) ->
      aa = +url.parse(a.gatherer_url, yes).query.multiverseid
      bb = +url.parse(b.gatherer_url, yes).query.multiverseid
      if aa < bb then -1 else if aa > bb then 1 else 0

  cards_mapping$

converted_mana_costs =
  '{X}': 0, '{4}': 4, '{10}': 10, '{16}': 16, '{2/W}': 2,
  '{Y}': 0, '{5}': 5, '{11}': 11, '{17}': 17, '{2/U}': 2,
  '{Z}': 0, '{6}': 6, '{12}': 12, '{18}': 18, '{2/B}': 2,
  '{0}': 0, '{7}': 7, '{13}': 13, '{19}': 19, '{2/R}': 2,
  '{2}': 2, '{8}': 8, '{14}': 14, '{20}': 20, '{2/G}': 2,
  '{3}': 3, '{9}': 9, '{15}': 15,

to_converted_mana_cost = (mana_cost) ->
  cmc = 0
  for symbol in mana_cost.split(/(?=[{])/)
    cmc += converted_mana_costs[symbol] ? 1
  cmc
