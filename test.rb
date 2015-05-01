
require 'json'
require 'net/http'
require 'uri'

@worker = "http://localhost:9495"

def test_worker_encode
	request = '{
	"jobid":"234234234",
	"source":"http://localhost:9494/file/bipbop.mp4_mezz.mov",
	"start":"0",
	"duration":"10",
	"rate":"800",
	"width":"640",
	"height":"360"
	}'
	uri = URI(@controller + "encode_complete")
	response = nil
	#First let's get some details on the file size
	Net::HTTP.start(uri.host, uri.port) do |http|
	  response = http.head(uri.path)
	  puts "Total file size: #{response.content_length}"
	end
end