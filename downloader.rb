
# Downloader

require 'net/http'
require 'uri'
require 'open3'
require 'json'
#require 'open4'

#with @address, @port, @path all defined elsewhere


class Downloader

    def initialize(local_file)
        @proxy_addr = 'localhost'
        @proxy_port = 8888

        #url = "http://hamburgpromedia.com/hpm-downloads/MXF-Testfiles/XDCAM_HD720p60.mxf"
        #url = "http://dveo.com/downloads/TS-sample-files/San_Diego_Clip.ts"
        #url = "http://s3-ap-southeast-2.amazonaws.com/zen-test-syd/abc-sample-captions.gxf"
        #@url = "http://asbctest.s3.amazonaws.com/dolby_channel_check_dualaudio.mp4"
        #@local_file = "sintel_trailer-1080p.mp4"
        #local_file = "abc-sample-captions.gxf"
        #local_file = "AVC_Intra1080i50.mxf"
        @local_file = local_file
    end


    # Use this to tell if we have sufficient info on a file being downloaded
    def probe_streams (filename)

    		
    	streams_cmd = "ffprobe -print_format json -show_streams #{filename}"
    	probe_response = nil
    	Open3.popen3(streams_cmd) {|i,o,e,t|
      		probe_response = o.read.chomp
    	}
    	
    	streams = JSON.parse(probe_response)
    	if not streams.empty? then
    		#puts streams["streams"][0]["codec_name"] #[0]["codec_name"]
    		puts "#{filename} Duration: #{streams["streams"][0]["duration"]}"
            # Todo fix this as audio won't have frame rate
    		puts "#{filename} Real frame rate: #{streams["streams"][0]["r_frame_rate"]}"
    	else
    		puts "#{filename} Can't detect video type yet"
    	end
        return streams
    end

    def count_frame_types(frames, type)
    	frame_count = 0
    	frames.each do |frame|
    		if frame["pict_type"] == type then
    			frame_count += 1
    		end
    	end
    	puts "Frames of type #{type} = #{frame_count}"
    	frame_count
    end

    def gen_frame_map (filename, av)
    	frames_cmd = "ffprobe -print_format json -show_frames -select_streams #{av} #{filename}"
        puts "Generating frame map"
    	probe_response = nil
    	Open3.popen3(frames_cmd) {|i,o,e,t|
      		probe_response = o.read.chomp
    	}
    	
    	frame_map = JSON.parse(probe_response)
    	if not frame_map.empty? then
    		puts "#{filename} Frames in current download #{frame_map["frames"].length}"
    		count_frame_types(frame_map["frames"], "I")
    	end
        total_size = 0
        frame_map["frames"].each do |frame|
            total_size += frame["pkt_size"].to_i
        end
        #puts "Am I all I frames: #{all_iframes(frame_map["frames"],200)}" if av == "v" 
        puts "Total track size #{av} #{total_size}"
        return frame_map["frames"], total_size
    end

    def all_iframes(frames, threshold)
        # This checks a certain number of frames and if all I-frames within the threshold then we are good to go
        threshold_count = 0
        frames.each {
            |frame|
            if frame["pict_type"].to_s != "I" then
                return false
            end
            threshold_count += 1
            if threshold_count >= threshold then
                break
            end
        }
        return true
    end

    def download_file(url, start_range)
        # This function is not 100% needed right now but can do some smarts
    	uri = URI(url)
    	size = 10000000 #the last offset (for the range header)
    	#start_range = 10000000
    	end_range = start_range + size
    	
    	http = Net::HTTP.new(uri.host, uri.port, @proxy_addr, @proxy_port)

    	headers = {
    	    'Range' => "bytes=#{start_range}-#{end_range}"
    	}
    	path = uri.path.empty? ? "/" : uri.path

    	#test to ensure that the request will be valid - first get the head
    	code = http.head(path, headers).code.to_i

    	if (code >= 200 && code < 300) then

    	    #the data is available...
    	    filename = "#{start_range}-#{end_range}-#{File.basename(uri.path)}"
    	    f = open(filename,'w')
    	    puts "Writing to #{filename}" 
    	    chunk_file_check = 0
    	    http.get(uri.path, headers) do |chunk|
    	        #provided the data is good, print it...
    	        #print chunk unless chunk =~ />416.+Range/
    	        #puts "Writing chunk"
    	        f.write(chunk)
    	        chunk_file_check += 1
    	        if chunk_file_check >= 100 then
    	        	#only probe file every 10 chunks
    	        	probe_file(filename)
    	        	chunk_file_check = 0
    	        end
    	    end
    	    f.close()
    	end
    end

    def multi_stream_download
        # Placeholder with threading sample
        size = get_file_info(url)
        segments = size / 4
        t1 = Thread.new {
            download_file(url, 0)
        }
        t2 = Thread.new {
            download_file(url, 10000001)
        }
        t1.join
        t2.join
    end

    def create_video_mezz(filename)
        # This should essentially just convert the original file to a mezz format with all I frames
        # Strips audio and data tracks, data is never re-added, q = 4 seems to be a reasonable compromise on q =0
        # ffmpeg also won't process the file over http without faststart
        # The mjpeg was too big and couldn't get parts of it read... need to do more ffmpeg mods
        #frames_cmd = "ffmpeg -i #{filename} -c:v mjpeg -pix_fmt yuvj422p -an -dn -q 4 -movflags faststart -y #{filename}_mezz.mov"
        frames_cmd = "ffmpeg -i #{filename} -c:v copy -an -dn -q 4 -y #{filename}_mezz.flv"
        puts "Creating video mezz file"
        puts frames_cmd
        probe_response = nil
        Open3.popen3(frames_cmd) {|i,o,e,t|
            # ffmpeg writes to stde
            probe_response = e.read.chomp
        }
        puts probe_response
        return "#{filename}_mezz.flv"
    end

    def create_audio_mezz(filename)
        # This is pus! Needs to check for number of tracks present and lots more, should be done in zencoder workflow
        frames_cmd = "ffmpeg -i #{filename} -vn -dn -c:a pcm_s16le -q 4 -y #{filename}_mezz.wav"
        puts frames_cmd
        puts "Creating audio mezz file"
        probe_response = nil
        Open3.popen3(frames_cmd) {|i,o,e,t|
            probe_response = e.read.chomp
        }
        puts probe_response
        return "#{filename}_mezz.wav"
    end

    def create_concat_video(filename)
        # This is really dummed down! Needs to check for number of tracks present and lots more
        frames_cmd = "ffmpeg -i #{filename} -an -c:v copy -y #{filename}_concat.ts"
        puts frames_cmd
        puts "Creating audio mezz file"
        probe_response = nil
        Open3.popen3(frames_cmd) {|i,o,e,t|
            probe_response = e.read.chomp
        }
        puts probe_response
        return "#{filename}_concat.ts"
    end

    def get_http_file_info(url)
        # Used for making decisions in downloading
    	uri = URI(url)
    	response = nil
    	#First let's get some details on the file size
    	Net::HTTP.start(uri.host, uri.port, @proxy_addr, @proxy_port) do |http|
    	  response = http.head(uri.path)
    	  puts "Total file size: #{response.content_length}"
    	end
    	response.content_length
    end

    def supported_concat_type(streams)
        streams.each do |key, stream|
            # Ignore audio streams
            #puts stream
            # Todo fix this data structure as nested one level more than required
            stream.each do |s|
                if s["codec_type"] == "video" then
                    case s["codec_name"]
                    when "mpeg2video"
                        return true
                    when "h264"
                        return true
                    else
                        puts "No matching codec for concat found"
                        return false
                    end
                end
            end
        end
    end

    def encode_part_zencoder
    end

    def cleanup()
        # Definitely for post hackweek!
        # Deletes all the TS and other files generated
    end

    def encode_video_part(url, start, finish, rate, width, height)
        # Most basic version 1
        # Get the filename from the url
        uri = URI.parse(url)
        filename = File.basename(uri.path)
        frames_cmd = "nice ffmpeg -i #{filename} -ss #{start} -t #{finish} -c:v libx264 -b:v #{rate}k -s #{width}x#{height} -pix_fmt yuv420p -y #{filename}_#{start}_#{finish}.ts"
        puts frames_cmd
        puts "Creating video part file"
        probe_response = nil
        Open3.popen3(frames_cmd) {|i,o,e,t|
            probe_response = e.read.chomp
        }
        puts probe_response
        return "#{filename}_#{start}_#{finish}.ts"
    end

    def create_parts(duration, segment_length)
        # Takes a duration and an segment length and returns an array of parts
        segments_count = duration.to_i / segment_length
        segments = Array.new
        start = 0
        for counter in 0..segments_count
            segment = {"start" => start, "finish" => segment_length}
            start += segment_length
            segments << segment
        end
        return segments
    end

    def gen_merged_video(files_to_join, local_video_file)
        cmd = "cat #{files_to_join.join(" ")} > #{local_video_file}_joined.ts"
        Open3.popen3(cmd) {|i,o,e,t|
            probe_response = e.read.chomp
        }
        return "#{local_video_file}_joined.ts"
    end

    def merge_audio(video_file, audio_file)
        # audio processing is a hack!
        file_no_ext = File.basename(video_file,File.extname(video_file))
        cmd = "nice ffmpeg -y -i #{video_file} -i #{audio_file} -c:v copy -c:a libfdk_aac #{file_no_ext}_merged.mp4"
        puts cmd
        Open3.popen3(cmd) {|i,o,e,t|
            probe_response = e.read.chomp
            puts probe_response
        }
        return "#{File.basename(video_file)}.mp4"
    end

    def process_file(local_file)
        streams = probe_streams(local_file)
        files_to_join = Array.new

        #local_video_file = "abc-sample-captions.gxf_mezz.mov"

        frames, total_size = gen_frame_map(local_file,"v")

        if !all_iframes(frames, 200)
            # Need to convert to a mezz file
            puts "This isn't all I-frame file so creating a mezz"
            local_video_file = create_video_mezz(local_file)
            local_audio_file = create_audio_mezz(local_file)
        elsif supported_concat_type(streams)
            # Convert to a concat format
            # Really need to check for supported formats here e.g. MPEG-2, H.264 etc
            local_video_file = create_concat_video(local_file)
            local_audio_file = create_audio_mezz(local_file)
            puts "Concat OK"
        end

        segments = create_parts(streams["streams"][0]["duration"],100)
        return {
                "segments"=>segments,
                "local_video_file" => local_video_file,
                "local_audio_file" => local_audio_file
            }
        #segments.each do |segment|
        #    files_to_join << encode_video_part(local_video_file, segment["start"], segment["finish"], 800, 640, 360)
        #end

        #merged_video = gen_merged_video(files_to_join, local_video_file)
        #final_file = merge_audio(merged_video, local_audio_file)
        #puts "Final file ready #{final_file}"
        #return "Completed #{final_file}"
    end
end

#process_file(local_file)
__END__





