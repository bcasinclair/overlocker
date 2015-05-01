# This one takes the original requests 
# does the inspection and hands the segment encodes out to the workers then
# Gets the notifications back and does the stitching

require 'sinatra'
#require 'json'
#require 'base64'
##require 'httpclient'
require 'openssl'
require 'securerandom'

set :bind, '0.0.0.0'
set :port, 9494

require_relative 'downloader'

# Todo move this into a util clase
def http_post(url, data)
	uri = URI(url)
	req = Net::HTTP::Post.new(uri.path, initheader = {'Content-Type' =>'application/json'})
    req.body = data.to_json
    response = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
    return response
end

get '/hi' do
  "Hellow world"
end 

get '/file/:file' do
  send_file File.join(File.join("source/",params[:file]))
end

get '/file/source/:file' do
  send_file File.join(File.join("source/",params[:file]))
end

get '/process/:file' do
	# Test assumes file exists in the source dir
	# Also really should submit a job into a q but this is a hack poc
	workers = ["http://192.168.88.249:9495/encode", "http://192.168.88.240:9495/encode"]
	file_to_process = File.join(File.join("source/",params[:file]))
	jobid = SecureRandom.uuid
	puts "Created job #{jobid}"
	if File.file?(file_to_process) then
		d = Downloader.new(file_to_process)
		resp = d.process_file(File.join(File.join("source/",params[:file])))
		video_file = resp["local_video_file"]
		resp["segments"].each do |segment|
			encode_job = {
				"jobid"=>"#{jobid}",
				"source"=>"http://192.168.88.249:9494/file/#{video_file}",
				"start"=> segment["start"],
				"duration"=> segment["finish"],
				"rate"=>"800",
				"width"=>"640",
				"height"=>"360"
			}
			worker = workers.shift
			workers.push(worker)
			resp = http_post(worker,encode_job)
			puts "Response #{resp} from #{worker}"
        #    files_to_join << encode_video_part(local_video_file, segment["start"], segment["finish"], 800, 640, 360)
        	puts segment
        end
	else
		resp = "Source file not found #{file_to_process}"
	end
	return resp.to_s
end

post '/complete' do
	request.body.rewind
	payload = JSON.parse(request.body.read)
	puts "Post complete #{payload.to_s}"
	return "OK"
end

get '/register/:address' do
	puts "#{params[:address]}"
	return "#{params[:address]}"
end

post '/register' do

end