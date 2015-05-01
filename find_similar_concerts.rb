require 'json'
require 'open-uri'
require 'cgi'
require 'pry'

path = './schedule.json'
dest = './schedule_with_similars.json'
API_KEY = 'cc2f6ef14dfc15aa8b5be688eb33a704'

concerts = JSON.parse(File.read path)

def lastfm_url_for concert
  "http://ws.audioscrobbler.com/2.0/?method=artist.getinfo" \
  "&artist=#{CGI.escape concert['artist']}&api_key=#{API_KEY}&format=json"
end

def last_fm_similar_url_for_concert(concert)
  "http://ws.audioscrobbler.com/2.0/?method=artist.getsimilar" \
  "&artist=#{CGI.escape (concert['lastfm_name'] || concert['name'])}" \
  "&api_key=#{API_KEY}&format=json"
end

puts "Fetching last.fm data"

concerts = concerts.map do |concert|
  print "[#{concert['artist']}:"
  lastfm = JSON.parse(open(lastfm_url_for concert).read)

  if !lastfm || lastfm["error"]
    print "🚫 ] "
    next
  end

  lastfm = lastfm['artist']

  images = lastfm['image'] && lastfm['image'].inject({}) do |hash, image|
    hash.merge image['size'].to_sym => image["#text"]
  end

  if lastfm['tags'].is_a?(Hash)
    tags = lastfm['tags']['tag']
    tags = [tags] unless tags.is_a?(Array)
    tags = tags.inject([]) do |array, tag|
      array << tag['name']
    end.join(", ")
  else
    tags = nil
  end

  print "✅ ] "

  concert.merge!({
    'musicbrainz_id' => lastfm['mbid'],
    'lastfm_name' => lastfm['name'],
    'lastfm_images' => images,
    'lastfm_tags' => tags
  })
end

puts "\nFetching last.fm similar artists"

concerts = concerts.compact.map do |concert|
  print "[#{concert['artist']}:"

  lastfm = JSON.parse(open(last_fm_similar_url_for_concert concert).read)

  similar = lastfm.fetch('similarartists', {}).fetch('artist', [])

  # some are just strings wut?
  if !similar.is_a?(Array)
    similar = []
  end

  similar = similar.inject([]) do |similar, artist|
    match = artist['mbid'] != '' && concerts.find do |c|
      c && c['musicbrainz_id'] == artist['mbid']
    end

    if match
      similar << match.merge(score: artist['match'].to_f)
    end

    similar
  end

  print "#{similar.count}] "

  concert.merge similar: similar
end

File.open(dest, 'w') { |f| f.write concerts.to_json }

