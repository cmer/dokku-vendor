require 'sinatra'
require 'logger'
require 'down'

set :logger, Logger.new(STDOUT)

DOWNLOAD_DIR = "/tmp/dokku-vendor/"
VENDOR_URL = "https://s3-external-1.amazonaws.com/"

get '/:buildpack/*.tgz' do
  buildpack = params[:buildpack]
  file_path = params[:splat].first
  file = get_file(buildpack, file_path)
  if file.is_a?(Integer)
    halt(file)
  else
    send_file(file)
  end
end

get '/' do
  "OK"
end

def get_file(buildpack, file_path)
  if file_path.include? "/"
    file_data = file_path.split("/")
    dir = file_data[0]
    file_name = file_data[1] + ".tgz"
  else
    dir = ""
    file_name = file_path + ".tgz"
  end

  absolute_dir_path = DOWNLOAD_DIR + buildpack + "/" + dir
  absolute_file_path = absolute_dir_path + "/#{file_name}"

  if File.exists?(absolute_file_path) && File.size(absolute_file_path) > 0
    return absolute_file_path
  else
    logger.info "NO FILE - DOWNLOAD"
    FileUtils.mkdir_p  absolute_dir_path unless File.exists?(absolute_dir_path) # Create dir first
    remote_url = VENDOR_URL + "#{buildpack}/#{file_path}.tgz"

    download = download_file(absolute_file_path, remote_url)

    if download == true
      return absolute_file_path
    else
      return download # error code
    end
  end
end

def download_file(local_path, remote_url)
  logger.info "DOWNLOADING FILE"
  logger.info remote_url
  Down.download(remote_url, destination: local_path)
  true
rescue Down::TooManyRedirects, Down::ConnectionError => ex
  logger.info ex.message
  404
rescue Down::Error => ex
  logger.info ex.message
  code = ex.message.to_i
  code > 0 ? code : 500
end
