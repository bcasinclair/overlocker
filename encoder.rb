class Encoder

	def initialize

	end

	def encode_video_part(url, start, finish, rate, width, height)
        # Most basic version 1
        # Get the filename from the url
        uri = URI.parse(url)
        filename = File.join('tmp',File.basename(uri.path))
        frames_cmd = "ffmpeg -i #{url} -ss #{start} -t #{finish} -c:v libx264 -b:v #{rate}k -s #{width}x#{height} -pix_fmt yuv420p -y #{filename}_#{start}_#{finish}.ts"
        puts frames_cmd
        puts "Creating video part file"
        probe_response = nil
        Open3.popen3(frames_cmd) {|i,o,e,t|
        	e.each_line do |line|
  				puts(line)
			end
			o.each_line do |line|
  				puts(line)
			end
            probe_response = e.read.chomp
        }
        puts probe_response
        return "#{filename}_#{start}_#{finish}.ts"
    end


end