# This one takes the original requests 
# does the inspection and hands the segment encodes out to the workers then
# Gets the notifications back and does the stitching

require 'sinatra'
require 'net/http'
require 'uri'
require 'openssl'
require 'json'
require 'socket'

require_relative 'downloader'
require_relative 'encoder'

set :bind, '0.0.0.0'
set :port, 9495
@controller = "http://localhost:9494"


def my_first_private_ipv4
  Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
end
@myip = my_first_private_ipv4.ip_address

def my_first_public_ipv4
  Socket.ip_address_list.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?}
end

get '/file/:file' do
  send_file File.join(File.join("source/",params[:file]))
end

def http_get(url)
	uri = URI(url)
	#First let's get some details on the file size
	Net::HTTP.start(uri.host, uri.port, @proxy_addr, @proxy_port) do |http|
	  response = http.get(uri.path)
	end
end

def http_post(url, data)
	uri = URI(url)
	req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
    req.body = data.to_json
    response = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
    return response
end

def encode_background(payload, callback)
	#t1 = Thread.new {
        e = Encoder.new()
		file = e.encode_video_part(payload["source"], payload["start"], payload["duration"], payload["rate"], payload["width"], payload["height"])
		status = {
			"file" => file,
			"worker" => my_first_private_ipv4.ip_address
		}
		puts "Status #{status.to_json}"
		http_post("#{callback}", status)
    #}
    #t1.join
end

post '/encode' do
	request.body.rewind
	payload = JSON.parse(request.body.read)
	encode_background(payload, "http://localhost:9494/complete")
	return "OK"
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