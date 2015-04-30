# This one takes the original requests 
# does the inspection and hands the segment encodes out to the workers then
# Gets the notifications back and does the stitching

require 'sinatra'
require 'net/http'
require 'uri'
require 'openssl'
require 'json'

require_relative 'downloader'
require_relative 'encoder'

set :bind, '0.0.0.0'
set :port, 9495
@controller = "http://localhost:9494"

get '/file/:file' do
  send_file File.join(File.join("source/",params[:file]))
end

post '/encode' do
	request.body.rewind
	payload = JSON.parse(request.body.read)
	e = Encoder.new()
	e.encode_video_part(payload["source"], payload["start"], payload["duration"], payload["rate"], payload["width"], payload["height"])
	return payload.to_s
end

get '/encode' do
	
end

get '/encodetest' do
	sleep(20)
	uri = URI(@controller + "encode_complete")
	response = nil
	#First let's get some details on the file size
	Net::HTTP.start(uri.host, uri.port, @proxy_addr, @proxy_port) do |http|
	  response = http.head(uri.path)
	  puts "Total file size: #{response.content_length}"
	end
	response.content_length
end