module S3BackendModel
  class Base
    def self.s3_credentials
      @s3_credentials ||= Aws::Credentials.new(ENV.fetch('AWS_S3_ACCESS_KEY_ID'),
                                               ENV.fetch('AWS_S3_SECRET_ACCESS_KEY'))
    end

    def self.s3_client
      @s3_client ||= Aws::S3::Client.new(region: 'ap-northeast-1', credentials: s3_credentials)
    end

    def self.use_s3_backend(bucket:, prefix_key:)
      ArgumentError.new('bucket is required') if bucket.blank?
      ArgumentError.new('prefix_key is required') if prefix_key.blank?

      define_singleton_method(:s3_bucket) { bucket }
      define_singleton_method(:prefix_key) { prefix_key }

      define_method(:s3_bucket) do
        self.class.s3_bucket
      end

      define_method(:s3_client) do
        self.class.s3_client
      end

      define_method(:prefix_key) do
        self.class.prefix_key
      end

      define_method(:id_with_prefix) do
        File.join(prefix_key, (@id || raise(ArgumentError.new('id is required'))))
      end
    end

    def self.to_s3_key(id)
      File.join(prefix_key, id)
    end

    def self.id_without_prefix(id_with_prefix)
      id_with_prefix.sub(%r{\A#{prefix_key}/}, '')
    end

    def self.all
      objects = s3_client.list_objects_v2(bucket: s3_bucket, prefix: prefix_key).contents.sort_by do |obj|
        -obj.last_modified.to_i
      end

      Parallel.map(objects, in_threads: 10) do |obj|
        head_object = s3_client.head_object(bucket: s3_bucket, key: obj.key)
        new(id: id_without_prefix(obj.key), s3_head_object: head_object)
      end
    end

    def self.create(id:, body:, metadata:)
      s3_client.put_object(bucket: s3_bucket, key: to_s3_key(id), body: body, metadata: metadata)
      find(id)
    end

    def self.find(id)
      head_object = s3_client.head_object(bucket: s3_bucket, key: to_s3_key(id))
      new(id: id, s3_head_object: head_object)
    rescue Aws::S3::Errors::NotFound
      nil
    end

    def initialize(id:, s3_head_object:)
      raise NotImplementedError.new
    end

    def fetch_body
      s3_client.get_object(bucket: s3_bucket, key: id_with_prefix).body.read
    end

    def destroy
      s3_client.delete_object(bucket: s3_bucket, key: id_with_prefix)
    end

    def update(body, params: {})
      s3_client.put_object(
        bucket: s3_bucket,
        key: id_with_prefix,
        body: body,
        content_type: params[:content_type]
      )
    end

    def update_metadata(metadata)
      s3_client.copy_object(
        bucket: s3_bucket,
        copy_source: "#{s3_bucket}/#{id_with_prefix}",
        key: id_with_prefix,
        metadata_directive: 'REPLACE',
        metadata: metadata
      )
    end
  end
end
