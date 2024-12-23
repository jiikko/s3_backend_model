# frozen_string_literal: true

require 'aws-sdk-s3'
require_relative 's3_backend_model/version'
require_relative 'base'

module S3BackendModel
  class Error < StandardError; end
end
