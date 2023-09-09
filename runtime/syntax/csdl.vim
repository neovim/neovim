" Vim syntax file
" Language: Curated Stream Definition Language (CSDL)
" Maintainer: Jacek Artymiak
" Latest Revision: 25 February 2013

if exists("b:current_syntax")
  finish
endif

setlocal iskeyword=.,@,48-57,_,192-255
syn case ignore 

syn match csdlKeyword "tag "
syn match csdlKeyword "stream "
syn match csdlKeyword "return "

syn keyword csdlOperator contains
syn match csdlOperator "cs contains"
syn keyword csdlOperator substr
syn match csdlOperator "cs substr"
syn keyword csdlOperator contains_any
syn match csdlOperator "cs contains_any"
syn keyword csdlOperator any
syn match csdlOperator "cs any"
syn keyword csdlOperator contains_near
syn match csdlOperator "cs contains_near"
syn keyword csdlOperator exists
syn keyword csdlOperator in
syn keyword csdlOperator url_in
syn match csdlOperator "=="
syn match csdlOperator "!="
syn match csdlOperator "cs =="
syn match csdlOperator "cs !="
syn match csdlOperator ">"
syn match csdlOperator ">="
syn match csdlOperator "<"
syn match csdlOperator "<="
syn keyword csdlOperator regex_partial
syn keyword csdlOperator regex_exact
syn keyword csdlOperator geo_box
syn keyword csdlOperator geo_radius
syn keyword csdlOperator geo_polygon

syn keyword csdlLogicalOperator and
syn keyword csdlLogicalOperator or
syn keyword csdlLogicalOperator not

syn match csdlTarget 'reddit\.title'
syn match csdlTarget 'reddit\.content'
syn match csdlTarget 'reddit\.contenttype'
syn match csdlTarget 'reddit\.link'
syn match csdlTarget 'reddit\.author\.name'
syn match csdlTarget 'reddit\.author\.link'
syn match csdlTarget 'reddit\.type'
syn match csdlTarget 'reddit\.thread'
syn match csdlTarget 'interaction\.type'
syn match csdlTarget 'interaction\.title'
syn match csdlTarget 'interaction\.content'
syn match csdlTarget 'interaction\.source'
syn match csdlTarget 'interaction\.geo'
syn match csdlTarget 'interaction\.link'
syn match csdlTarget 'interaction\.author\.username'
syn match csdlTarget 'interaction\.author\.name'
syn match csdlTarget 'interaction\.author\.id'
syn match csdlTarget 'interaction\.author\.avatar'
syn match csdlTarget 'interaction\.author\.link'
syn match csdlTarget 'interaction\.sample'
syn match csdlTarget 'links\.title'
syn match csdlTarget 'links\.url'
syn keyword csdlTarget links.normalized_url
syn match csdlTarget 'links\.hops'
syn match csdlTarget 'links\.code'
syn match csdlTarget 'links\.domain'
syn keyword csdlTarget links.retweet_count
syn match csdlTarget 'links\.age'
syn keyword csdlTarget links.meta.content_type
syn match csdlTarget 'links\.meta\.charset'
syn match csdlTarget 'links\.meta\.lang'
syn match csdlTarget 'links\.meta\.keywords'
syn match csdlTarget 'links\.meta\.description'
syn match csdlTarget 'links\.meta\.newskeywords'
syn match csdlTarget 'links\.meta\.standout'
syn match csdlTarget 'links\.meta\.opengraph\.type'
syn match csdlTarget 'links\.meta\.opengraph\.title'
syn match csdlTarget 'links\.meta\.opengraph\.image'
syn match csdlTarget 'links\.meta\.opengraph\.url'
syn match csdlTarget 'links\.meta\.opengraph\.description'
syn keyword csdlTarget links.meta.opengraph.site_name
syn match csdlTarget 'links\.meta\.opengraph\.email'
syn keyword csdlTarget links.meta.opengraph.phone_number
syn keyword csdlTarget links.meta.opengraph.fax_number
syn match csdlTarget 'links\.meta\.opengraph\.geo'
syn keyword csdlTarget links.meta.opengraph.street_address
syn match csdlTarget 'links\.meta\.opengraph\.locality'
syn match csdlTarget 'links\.meta\.opengraph\.region'
syn keyword csdlTarget links.meta.opengraph.postal_code
syn match csdlTarget 'links\.meta\.opengraph\.activity'
syn match csdlTarget 'links\.meta\.opengraph\.sport'
syn match csdlTarget 'links\.meta\.opengraph\.bar'
syn match csdlTarget 'links\.meta\.opengraph\.company'
syn match csdlTarget 'links\.meta\.opengraph\.cafe'
syn match csdlTarget 'links\.meta\.opengraph\.hotel'
syn match csdlTarget 'links\.meta\.opengraph\.restaurant'
syn match csdlTarget 'links\.meta\.opengraph\.cause'
syn keyword csdlTarget links.meta.opengraph.sports_league
syn keyword csdlTarget links.meta.opengraph.sports_team
syn match csdlTarget 'links\.meta\.opengraph\.band'
syn match csdlTarget 'links\.meta\.opengraph\.government'
syn keyword csdlTarget links.meta.opengraph.non_profit
syn match csdlTarget 'links\.meta\.opengraph\.school'
syn match csdlTarget 'links\.meta\.opengraph\.university'
syn match csdlTarget 'links\.meta\.opengraph\.actor'
syn match csdlTarget 'links\.meta\.opengraph\.athlete'
syn match csdlTarget 'links\.meta\.opengraph\.author'
syn match csdlTarget 'links\.meta\.opengraph\.director'
syn match csdlTarget 'links\.meta\.opengraph\.musician'
syn match csdlTarget 'links\.meta\.opengraph\.politician'
syn keyword csdlTarget links.meta.opengraph.public_figure
syn match csdlTarget 'links\.meta\.opengraph\.city'
syn match csdlTarget 'links\.meta\.opengraph\.country'
syn match csdlTarget 'links\.meta\.opengraph\.landmark'
syn keyword csdlTarget links.meta.opengraph.state_province
syn match csdlTarget 'links\.meta\.opengraph\.album'
syn match csdlTarget 'links\.meta\.opengraph\.book'
syn match csdlTarget 'links\.meta\.opengraph\.drink'
syn match csdlTarget 'links\.meta\.opengraph\.food'
syn match csdlTarget 'links\.meta\.opengraph\.game'
syn match csdlTarget 'links\.meta\.opengraph\.movie'
syn match csdlTarget 'links\.meta\.opengraph\.product'
syn match csdlTarget 'links\.meta\.opengraph\.song'
syn keyword csdlTarget links.meta.opengraph.tv_show
syn match csdlTarget 'links\.meta\.opengraph\.blog'
syn match csdlTarget 'links\.meta\.opengraph\.website'
syn match csdlTarget 'links\.meta\.opengraph\.article'
syn match csdlTarget 'links\.meta\.twitter\.card'
syn match csdlTarget 'links\.meta\.twitter\.site'
syn keyword csdlTarget links.meta.twitter.site_id
syn match csdlTarget 'links\.meta\.twitter\.creator'
syn keyword csdlTarget links.meta.twitter.creator_id
syn match csdlTarget 'links\.meta\.twitter\.url'
syn match csdlTarget 'links\.meta\.twitter\.description'
syn match csdlTarget 'links\.meta\.twitter\.title'
syn match csdlTarget 'links\.meta\.twitter\.image'
syn keyword csdlTarget links.meta.twitter.image_width
syn keyword csdlTarget links.meta.twitter.image_height
syn match csdlTarget 'links\.meta\.twitter\.player'
syn keyword csdlTarget links.meta.twitter.player_width
syn keyword csdlTarget links.meta.twitter.player_height
syn keyword csdlTarget links.meta.twitter.player_stream
syn keyword csdlTarget links.meta.twitter.player_stream_content_type
syn match csdlTarget 'myspace\.link'
syn match csdlTarget 'myspace\.content'
syn match csdlTarget 'myspace\.contenttype'
syn match csdlTarget 'myspace\.category'
syn match csdlTarget 'myspace\.author\.username'
syn match csdlTarget 'myspace\.author\.name'
syn match csdlTarget 'myspace\.author\.id'
syn match csdlTarget 'myspace\.author\.link'
syn match csdlTarget 'myspace\.author\.avatar'
syn match csdlTarget 'myspace\.geo'
syn match csdlTarget 'myspace\.verb'
syn match csdlTarget 'newscred\.type'
syn match csdlTarget 'newscred\.article\.domain'
syn match csdlTarget 'newscred\.video\.domain'
syn match csdlTarget 'newscred\.article\.topics'
syn match csdlTarget 'newscred\.video\.topics'
syn match csdlTarget 'newscred\.article\.category'
syn match csdlTarget 'newscred\.video\.category'
syn match csdlTarget 'newscred\.article\.title'
syn match csdlTarget 'newscred\.video\.title'
syn match csdlTarget 'newscred\.article\.content'
syn match csdlTarget 'newscred\.article\.fulltext'
syn match csdlTarget 'newscred\.article\.authors'
syn match csdlTarget 'newscred\.image\.caption'
syn match csdlTarget 'newscred\.video\.caption'
syn match csdlTarget 'newscred\.image\.attribution\.text'
syn match csdlTarget 'newscred\.image\.attribution\.link'
syn match csdlTarget 'newscred\.source\.name'
syn match csdlTarget 'newscred\.source\.link'
syn match csdlTarget 'newscred\.source\.domain'
syn keyword csdlTarget newscred.source.media_type
syn keyword csdlTarget newscred.source.company_type
syn match csdlTarget 'newscred\.source\.country'
syn match csdlTarget 'newscred\.source\.circulation'
syn match csdlTarget 'newscred\.source\.founded'
syn match csdlTarget 'imdb\.title'
syn match csdlTarget 'imdb\.content'
syn match csdlTarget 'imdb\.contenttype'
syn match csdlTarget 'imdb\.link'
syn match csdlTarget 'imdb\.author\.name'
syn match csdlTarget 'imdb\.author\.link'
syn match csdlTarget 'imdb\.type'
syn match csdlTarget 'imdb\.thread'
syn match csdlTarget 'amazon\.title'
syn match csdlTarget 'amazon\.content'
syn match csdlTarget 'amazon\.contenttype'
syn match csdlTarget 'amazon\.link'
syn match csdlTarget 'amazon\.author\.name'
syn match csdlTarget 'amazon\.author\.link'
syn match csdlTarget 'amazon\.type'
syn match csdlTarget 'amazon\.thread'
syn match csdlTarget 'salience\.content\.sentiment'
syn match csdlTarget 'salience\.content\.topics'
syn match csdlTarget 'salience\.title\.sentiment'
syn match csdlTarget 'salience\.title\.topics'
syn match csdlTarget 'salience\.content\.entities\.name'
syn match csdlTarget 'salience\.content\.entities\.type'
syn match csdlTarget 'salience\.title\.entities\.name'
syn match csdlTarget 'salience\.title\.entities\.type'
syn match csdlTarget 'klout\.score'
syn match csdlTarget 'klout\.network'
syn match csdlTarget 'klout\.amplification'
syn keyword csdlTarget klout.true_reach
syn match csdlTarget 'klout\.topics'
syn match csdlTarget 'wikipedia\.author\.talk'
syn match csdlTarget 'wikipedia\.author\.contributions'
syn match csdlTarget 'wikipedia\.author\.username'
syn match csdlTarget 'wikipedia\.body'
syn match csdlTarget 'wikipedia\.title'
syn match csdlTarget 'wikipedia\.images'
syn match csdlTarget 'wikipedia\.categories'
syn match csdlTarget 'wikipedia\.externallinks'
syn match csdlTarget 'wikipedia\.ns'
syn match csdlTarget 'wikipedia\.namespace'
syn match csdlTarget 'wikipedia\.pageid'
syn match csdlTarget 'wikipedia\.parentid'
syn match csdlTarget 'wikipedia\.oldlen'
syn match csdlTarget 'wikipedia\.newlen'
syn match csdlTarget 'wikipedia\.changetype'
syn match csdlTarget 'wikipedia\.diff\.from'
syn match csdlTarget 'wikipedia\.diff\.to'
syn match csdlTarget 'wikipedia\.diff\.changes\.added'
syn match csdlTarget 'wikipedia\.diff\.changes\.removed'
syn keyword csdlTarget demographic.twitter_activity
syn match csdlTarget 'demographic\.location\.country'
syn keyword csdlTarget demographic.location.us_state
syn match csdlTarget 'demographic\.location\.city'
syn match csdlTarget 'demographic\.type'
syn match csdlTarget 'demographic\.sex'
syn match csdlTarget 'demographic\.status\.relationship'
syn match csdlTarget 'demographic\.status\.work'
syn keyword csdlTarget demographic.likes_and_interests
syn keyword csdlTarget demographic.first_language
syn match csdlTarget 'demographic\.professions'
syn match csdlTarget 'demographic\.services'
syn keyword csdlTarget demographic.large_accounts_followed
syn keyword csdlTarget demographic.age_range.start
syn keyword csdlTarget demographic.age_range.end
syn match csdlTarget 'demographic\.income\.start'
syn match csdlTarget 'demographic\.income\.end'
syn keyword csdlTarget demographic.main_street.dressed_by
syn keyword csdlTarget demographic.main_street.shop_at
syn keyword csdlTarget demographic.main_street.eat_and_drink_at
syn match csdlTarget 'demographic\.accounts\.categories'
syn match csdlTarget 'tumblr\.activity'
syn match csdlTarget 'tumblr\.source\.blogid'
syn match csdlTarget 'tumblr\.dest\.blogid'
syn match csdlTarget 'tumblr\.dest\.postid'
syn match csdlTarget 'tumblr\.root\.blogid'
syn match csdlTarget 'tumblr\.root\.postid'
syn match csdlTarget 'tumblr\.blogid'
syn keyword csdlTarget tumblr.blog_name
syn match csdlTarget 'tumblr\.type'
syn match csdlTarget 'tumblr\.title'
syn match csdlTarget 'tumblr\.body'
syn match csdlTarget 'tumblr\.text'
syn match csdlTarget 'tumblr\.tags'
syn keyword csdlTarget tumblr.track_name
syn match csdlTarget 'tumblr\.album'
syn match csdlTarget 'tumblr\.link'
syn match csdlTarget 'tumblr\.meta\.url'
syn match csdlTarget 'tumblr\.meta\.type'
syn match csdlTarget 'tumblr\.meta\.description'
syn keyword csdlTarget tumblr.meta.likes_local
syn keyword csdlTarget tumblr.meta.likes_global
syn keyword csdlTarget tumblr.meta.reblogged_global
syn match csdlTarget 'demographic\.gender'
syn match csdlTarget 'flickr\.title'
syn match csdlTarget 'flickr\.content'
syn match csdlTarget 'flickr\.contenttype'
syn match csdlTarget 'flickr\.link'
syn match csdlTarget 'flickr\.author\.name'
syn match csdlTarget 'flickr\.author\.link'
syn match csdlTarget 'flickr\.author\.username'
syn match csdlTarget 'flickr\.type'
syn match csdlTarget 'flickr\.thread'
syn match csdlTarget 'twitter\.text'
syn match csdlTarget 'twitter\.source'
syn match csdlTarget 'twitter\.mentions'
syn keyword csdlTarget twitter.mention_ids
syn match csdlTarget 'twitter\.links'
syn match csdlTarget 'twitter\.domains'
syn keyword csdlTarget twitter.in_reply_to_screen_name
syn keyword csdlTarget twitter.in_reply_to_user_id
syn keyword csdlTarget twitter.in_reply_to_status_id
syn keyword csdlTarget twitter.filter_level
syn match csdlTarget 'twitter\.lang'
syn match csdlTarget 'twitter\.geo'
syn match csdlTarget 'twitter\.user\.description'
syn match csdlTarget 'twitter\.user\.location'
syn keyword csdlTarget twitter.user.statuses_count
syn keyword csdlTarget twitter.user.followers_count
syn keyword csdlTarget twitter.user.follower_ratio
syn keyword csdlTarget twitter.user.profile_age
syn keyword csdlTarget twitter.user.friends_count
syn keyword csdlTarget twitter.user.screen_name
syn match csdlTarget 'twitter\.user\.lang'
syn keyword csdlTarget twitter.user.time_zone
syn match csdlTarget 'twitter\.user\.name'
syn match csdlTarget 'twitter\.user\.id'
syn keyword csdlTarget twitter.user.listed_count
syn match csdlTarget 'twitter\.user\.url'
syn match csdlTarget 'twitter\.user\.verified'
syn keyword csdlTarget twitter.place.place_type
syn match csdlTarget 'twitter\.place\.country'
syn keyword csdlTarget twitter.place.country_code
syn keyword csdlTarget twitter.place.full_name
syn match csdlTarget 'twitter\.place\.name'
syn match csdlTarget 'twitter\.place\.url'
syn match csdlTarget 'twitter\.place\.attributes\.locality'
syn match csdlTarget 'twitter\.place\.attributes\.region'
syn keyword csdlTarget twitter.place.attributes.street_address
syn match csdlTarget 'twitter\.status'
syn match csdlTarget 'twitter\.retweet\.text'
syn match csdlTarget 'twitter\.retweet\.elapsed'
syn match csdlTarget 'twitter\.retweet\.source'
syn keyword csdlTarget twitter.retweet.filter_level
syn match csdlTarget 'twitter\.retweet\.lang'
syn match csdlTarget 'twitter\.retweet\.user\.description'
syn match csdlTarget 'twitter\.retweet\.user\.location'
syn keyword csdlTarget twitter.retweet.user.statuses_count
syn keyword csdlTarget twitter.retweet.user.followers_count
syn keyword csdlTarget twitter.retweet.user.follower_ratio
syn keyword csdlTarget twitter.retweet.user.profile_age
syn keyword csdlTarget twitter.retweet.user.friends_count
syn keyword csdlTarget twitter.retweet.user.screen_name
syn match csdlTarget 'twitter\.retweet\.user\.lang'
syn keyword csdlTarget twitter.retweet.user.time_zone
syn match csdlTarget 'twitter\.retweet\.user\.name'
syn match csdlTarget 'twitter\.retweet\.user\.id'
syn keyword csdlTarget twitter.retweet.user.listed_count
syn match csdlTarget 'twitter\.retweet\.user\.url'
syn match csdlTarget 'twitter\.retweet\.user\.verified'
syn match csdlTarget 'twitter\.retweeted\.id'
syn match csdlTarget 'twitter\.retweeted\.source'
syn keyword csdlTarget twitter.retweeted.in_reply_to_screen_name
syn keyword csdlTarget twitter.retweeted.in_reply_to_user_id_str
syn keyword csdlTarget twitter.retweeted.in_reply_to_status_id
syn match csdlTarget 'twitter\.retweet\.count'
syn match csdlTarget 'twitter\.retweet\.mentions'
syn keyword csdlTarget twitter.retweet.mention_ids
syn match csdlTarget 'twitter\.retweet\.links'
syn match csdlTarget 'twitter\.retweet\.domains'
syn match csdlTarget 'twitter\.retweeted\.user\.description'
syn match csdlTarget 'twitter\.retweeted\.user\.location'
syn keyword csdlTarget twitter.retweeted.user.statuses_count
syn keyword csdlTarget twitter.retweeted.user.followers_count
syn keyword csdlTarget twitter.retweeted.user.follower_ratio
syn keyword csdlTarget twitter.retweeted.user.profile_age
syn keyword csdlTarget twitter.retweeted.user.friends_count
syn keyword csdlTarget twitter.retweeted.user.screen_name
syn match csdlTarget 'twitter\.retweeted\.user\.lang'
syn keyword csdlTarget twitter.retweeted.user.time_zone
syn match csdlTarget 'twitter\.retweeted\.user\.name'
syn match csdlTarget 'twitter\.retweeted\.user\.id'
syn keyword csdlTarget twitter.retweeted.user.listed_count
syn match csdlTarget 'twitter\.retweeted\.user\.url'
syn match csdlTarget 'twitter\.retweeted\.user\.verified'
syn match csdlTarget 'twitter\.retweeted\.geo'
syn keyword csdlTarget twitter.retweeted.place.place_type
syn match csdlTarget 'twitter\.retweeted\.place\.country'
syn keyword csdlTarget twitter.retweeted.place.country_code
syn keyword csdlTarget twitter.retweeted.place.full_name
syn match csdlTarget 'twitter\.retweeted\.place\.name'
syn match csdlTarget 'twitter\.retweeted\.place\.url'
syn match csdlTarget 'twitter\.retweeted\.place\.attributes'
syn match csdlTarget 'twitter\.hashtags'
syn match csdlTarget 'twitter\.retweet\.hashtags'
syn match csdlTarget 'twitter\.media\.type'
syn keyword csdlTarget twitter.media.media_url
syn keyword csdlTarget twitter.media.display_url
syn match csdlTarget 'twitter\.retweet\.media\.type'
syn keyword csdlTarget twitter.retweet.media.media_url
syn keyword csdlTarget twitter.retweet.media.display_url
syn match csdlTarget 'blog\.title'
syn match csdlTarget 'blog\.content'
syn match csdlTarget 'blog\.contenttype'
syn match csdlTarget 'blog\.link'
syn match csdlTarget 'blog\.domain'
syn match csdlTarget 'blog\.author\.name'
syn match csdlTarget 'blog\.author\.link'
syn match csdlTarget 'blog\.author\.avatar'
syn match csdlTarget 'blog\.author\.username'
syn match csdlTarget 'blog\.type'
syn match csdlTarget 'blog\.post\.link'
syn match csdlTarget 'blog\.post\.title'
syn match csdlTarget 'facebook\.author\.name'
syn match csdlTarget 'facebook\.author\.link'
syn match csdlTarget 'facebook\.author\.id'
syn match csdlTarget 'facebook\.author\.avatar'
syn match csdlTarget 'facebook\.message'
syn match csdlTarget 'facebook\.description'
syn match csdlTarget 'facebook\.caption'
syn match csdlTarget 'facebook\.type'
syn match csdlTarget 'facebook\.application'
syn match csdlTarget 'facebook\.source'
syn match csdlTarget 'facebook\.link'
syn match csdlTarget 'facebook\.name'
syn match csdlTarget 'facebook\.to\.names'
syn match csdlTarget 'facebook\.to\.ids'
syn match csdlTarget 'facebook\.og\.title'
syn match csdlTarget 'facebook\.og\.location'
syn match csdlTarget 'facebook\.og\.photos'
syn match csdlTarget 'facebook\.og\.by'
syn match csdlTarget 'facebook\.og\.description'
syn match csdlTarget 'facebook\.og\.type'
syn match csdlTarget 'facebook\.og\.length'
syn match csdlTarget 'facebook\.likes\.count'
syn match csdlTarget 'facebook\.likes\.names'
syn match csdlTarget 'facebook\.likes\.ids'
syn match csdlTarget 'topix\.title'
syn match csdlTarget 'topix\.content'
syn match csdlTarget 'topix\.contenttype'
syn match csdlTarget 'topix\.link'
syn match csdlTarget 'topix\.author\.name'
syn match csdlTarget 'topix\.type'
syn match csdlTarget 'topix\.thread'
syn match csdlTarget 'topix\.author\.location'
syn match csdlTarget 'bitly\.user\.agent'
syn keyword csdlTarget bitly.url_hash
syn match csdlTarget 'bitly\.share\.hash'
syn match csdlTarget 'bitly\.cname'
syn keyword csdlTarget bitly.referring_url
syn keyword csdlTarget bitly.referring_domain
syn match csdlTarget 'bitly\.url'
syn match csdlTarget 'bitly\.domain'
syn keyword csdlTarget bitly.country_code
syn keyword csdlTarget bitly.geo_region_code
syn match csdlTarget 'bitly\.country'
syn keyword csdlTarget bitly.geo_region
syn keyword csdlTarget bitly.geo_city
syn match csdlTarget 'bitly\.geo'
syn match csdlTarget 'bitly\.timezone'
syn match csdlTarget 'trends\.type'
syn match csdlTarget 'trends\.content'
syn match csdlTarget 'trends\.source'
syn match csdlTarget 'board\.title'
syn match csdlTarget 'board\.content'
syn match csdlTarget 'board\.contenttype'
syn match csdlTarget 'board\.link'
syn match csdlTarget 'board\.domain'
syn match csdlTarget 'board\.author\.name'
syn match csdlTarget 'board\.author\.link'
syn match csdlTarget 'board\.author\.avatar'
syn match csdlTarget 'board\.author\.username'
syn match csdlTarget 'board\.type'
syn match csdlTarget 'board\.thread'
syn match csdlTarget 'board\.author\.location'
syn match csdlTarget 'board\.author\.signature'
syn match csdlTarget 'board\.author\.registered'
syn match csdlTarget 'board\.author\.age'
syn match csdlTarget 'board\.author\.gender'
syn match csdlTarget 'video\.title'
syn match csdlTarget 'video\.content'
syn match csdlTarget 'video\.contenttype'
syn match csdlTarget 'video\.domain'
syn match csdlTarget 'video\.author\.name'
syn match csdlTarget 'video\.author\.link'
syn match csdlTarget 'video\.author\.avatar'
syn match csdlTarget 'video\.author\.username'
syn match csdlTarget 'video\.type'
syn match csdlTarget 'video\.videolink'
syn match csdlTarget 'video\.commentslink'
syn match csdlTarget 'video\.duration'
syn match csdlTarget 'video\.thumbnail'
syn match csdlTarget 'video\.category'
syn match csdlTarget 'video\.tags'
syn match csdlTarget '2ch\.title'
syn match csdlTarget '2ch\.content'
syn match csdlTarget '2ch\.contenttype'
syn match csdlTarget '2ch\.link'
syn match csdlTarget '2ch\.author\.name'
syn match csdlTarget '2ch\.type'
syn match csdlTarget '2ch\.thread'
syn match csdlTarget 'dailymotion\.title'
syn match csdlTarget 'dailymotion\.content'
syn match csdlTarget 'dailymotion\.contenttype'
syn match csdlTarget 'dailymotion\.author\.link'
syn match csdlTarget 'dailymotion\.author\.username'
syn match csdlTarget 'dailymotion\.videolink'
syn match csdlTarget 'dailymotion\.duration'
syn match csdlTarget 'dailymotion\.thumbnail'
syn match csdlTarget 'dailymotion\.category'
syn match csdlTarget 'dailymotion\.tags'
syn match csdlTarget 'language\.tag'
syn match csdlTarget 'language\.confidence'
syn match csdlTarget 'digg\.type'
syn match csdlTarget 'digg\.user\.name'
syn match csdlTarget 'digg\.user\.fullname'
syn match csdlTarget 'digg\.user\.registered'
syn match csdlTarget 'digg\.user\.profileviews'
syn match csdlTarget 'digg\.user\.icon'
syn match csdlTarget 'digg\.user\.links'
syn match csdlTarget 'digg\.item\.status'
syn match csdlTarget 'digg\.item\.description'
syn match csdlTarget 'digg\.item\.title'
syn match csdlTarget 'digg\.item\.diggs'
syn match csdlTarget 'digg\.item\.comments'
syn match csdlTarget 'digg\.item\.topic'
syn match csdlTarget 'digg\.comment\.buries'
syn match csdlTarget 'digg\.comment\.diggs'
syn match csdlTarget 'digg\.comment\.text'
syn match csdlTarget 'youtube\.title'
syn match csdlTarget 'youtube\.content'
syn match csdlTarget 'youtube\.contenttype'
syn match csdlTarget 'youtube\.author\.name'
syn match csdlTarget 'youtube\.author\.link'
syn match csdlTarget 'youtube\.type'
syn match csdlTarget 'youtube\.videolink'
syn match csdlTarget 'youtube\.commentslink'
syn match csdlTarget 'youtube\.duration'
syn match csdlTarget 'youtube\.thumbnail'
syn match csdlTarget 'youtube\.category'
syn match csdlTarget 'youtube\.tags'

syn match csdlComment "^\/\/.*$"
syn match csdlComment "^\/\*.*$"
syn match csdlComment "^.*\*\/$"

highlight link csdlKeyword Statement
highlight link csdlOperator Operator
highlight link csdlLogicalOperator Operator
highlight link csdlTarget Constant
highlight link csdlComment Comment
"
let b:current_syntax = "csdl"
