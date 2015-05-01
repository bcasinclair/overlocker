# This one takes the original requests 
# does the inspection and hands the segment encodes out to the workers then
# Gets the notifications back and does the stitching

require 'sinatra'
require 'json'
#require 'base64'
require 'socket'
require 'openssl'
require 'securerandom'

@port = 9494

set :bind, '0.0.0.0'
set :port, @port

require_relative 'downloader'

def my_first_private_ipv4
  Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
end
@myip = my_first_private_ipv4.ip_address

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
	start = params['start']
	send_file File.join(File.join("source/",params[:file]))
end

get '/file/source/:file' do
  puts "#{ request.env }"
  puts "#{response.headers}"
  send_file File.join(File.join("source/",params[:file]))
end

def load_workers()
	f = File.open("workers.json")
	@workers = JSON.parse(f.read)["workers"]
end

get '/process/:file' do
	# Test assumes file exists in the source dir
	# Also really should submit a job into a q but this is a hack poc
	#workers = ["http://192.168.88.249:9495/encode", "http://192.168.88.240:9495/encode", "http://192.168.88.250:9495/encode"]
	load_workers()
	file_to_process = File.join(File.join("source/",params[:file]))
	jobid = SecureRandom.uuid
	puts "Created job #{jobid}"
	if File.file?(file_to_process) then
		d = Downloader.new(file_to_process)
		resp = d.process_file(File.join(File.join("shared/",params[:file])))
		video_file = resp["local_video_file"]
		job = {
			"jobid":jobid,
			"local_video_file" => resp["local_video_file"],
			"local_audio_file" => resp["local_audio_file"],
			"segments":resp["segments"]
		}
		File.open("jobs/#{jobid}",'w') { |file| 
			file.write(job.to_json) 
			file.close }

		resp["segments"].each do |segment|
			encode_job = {
				"jobid"=>"#{jobid}",
				#{}"source"=>"http://#{my_first_private_ipv4.ip_address}:9494/file/#{video_file}",
				"source" => "#{video_file}",
				"start"=> segment["start"],
				"duration"=> segment["finish"],
				"rate"=>"800",
				"width"=>"640",
				"height"=>"360"
			}
			worker = @workers.shift
			@workers.push(worker)
			# No queueing here! Dish all the jobs out
			puts "Sending job to #{worker}"
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

def all_renditions_complete(job)
	job["segments"].each do |segment|
		if !segment["complete"] then
			return false
		end
	end
	return true
end

post '/complete' do
	request.body.rewind
	payload = JSON.parse(request.body.read)
	load_workers()
	f = File.open("jobs/#{payload['jobid']}", 'r')
	job = JSON.parse(f.read)
	job["segments"].each  do |k,v| 
		if k["start"] == payload["start"] then 
			k["complete"]=true 
			k["file"]=payload["file"]
		end
	end
	puts job
	f.close
	# There is no doubt a better way to do this in Ruby...
	f = File.open("jobs/#{payload['jobid']}", 'w')
	f.write(job.to_json)
	f.close
	if all_renditions_complete(job) then
		puts "All renditions complete, time to mux and join"
		d = Downloader.new(nil)
		d.merge_and_join(job)
	end
	puts "Post complete #{payload.to_s}"
	return "OK"
end

get '/register/:address' do
	puts "#{params[:address]}"
	return "#{params[:address]}"
end

post '/register' do
	request.body.rewind
	payload = JSON.parse(request.body.read)
	puts payload
	worker = payload["worker"]
	f = File.open("workers.json")
	@workers = JSON.parse(f.read)
	f.close
	puts @workers
	
	@workers["workers"].push(worker) unless @workers["workers"].include?(worker)
	f = File.open("workers.json",'w')
	f.write(@workers.to_json)
	f.close
	return @workers.to_json
end