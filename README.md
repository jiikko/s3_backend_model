# S3BackendModel

A library for persisting models on S3.

### なぜ S3 に保存するのか？

ちょっとしたツールでデータを永続化する際、RDBMS や NoSQL データベースは管理の手間がかかりすぎたり、コストが高すぎたりすることがあります。一方、S3 は設定が簡単で、低コストかつデータの共有が容易なため、シンプルな永続化ニーズに適しています。

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add s3_backend_model
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install s3_backend_model
```

## Usage

TODO: configuration(how to set credentials)

- .all
- .find(id)
- .create(id:, body:, metadata: {})
- #update
- #destroy

### Google アカウント OAuth2 クレデンシャルを保存する例

```ruby
class GoogleCredential < S3BackendModel::Base
  use_s3_backend bucket: 'hogehoge-bucket', prefix_key: 'google_credentials'

  attr_accessor :id, :object

  def self.instance
    id = 'data.json'
    find(id) || new(id: id, s3_head_object: {})
  end

  def initialize(id:, s3_head_object:)
    @id = id
    begin
      @body = JSON.parse(fetch_body)
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end
  end

  def refresh_token
    return if @body.nil?

    @body['refresh_token']
  end

end
```

```ruby
class OmniauthCallbacksController < ApplicationController
  def google_oauth2
    if (credentials = request.env['omniauth.auth']['credentials']).present?
      GoogleCredential.instance.update(credentials.to_json, params: { content_type: 'application/json' })
    end

    redirect_to root_path, notice: 'Google OAuth2 authentication was successful.'
  end
end
```

### スクレイピングした YouTube 動画情報を保存する例

```ruby
class Video < S3BackendModel::Base
  use_s3_backend bucket: 'hogehoge-bucket', prefix_key: 'videos'

  attr_accessor :id, :s3_head_object

  def initialize(id:, s3_head_object:)
    @id = id
    @s3_head_object = s3_head_object
  end

  def title
    return unless s3_head_object.metadata['title'].present?

    Base64.strict_decode64(s3_head_object.metadata['title']).force_encoding('UTF-8')
  end

  def user_name
    s3_head_object.metadata['user_name']
  end

  def created_at
    s3_head_object.metadata['created_at']&.to_time
  end

  def metadata
    s3_head_object.metadata
  end
end
```

```ruby
metadata = {
  title: Base64.strict_encode64(live.title),
  user_id: @user.id.to_s,
  user_name: @user.name,
  created_at: live.created_at.to_s
}
Video.create(id: live.live_id, body: nil, metadata: metadata)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

Bug reports and pull requests are welcome on GitHub at https://github.com/jiikko/s3_backend_model.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
