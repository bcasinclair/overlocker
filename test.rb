
require 'json'
require 'net/http'
require 'uri'


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
end