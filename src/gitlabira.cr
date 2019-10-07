# TODO: Write documentation for `Gitlabira`'
require "kemal"
require "logger"

module Gitlabira
  VERSION = "0.1.0"

  post "/hook" do |env|
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.info env.request.body.not_nil!.gets_to_end

    "OK"
  end
end

Kemal.run
