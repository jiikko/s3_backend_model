# frozen_string_literal: true

RSpec.describe S3BackendModel do
  it "has a version number" do
    expect(S3BackendModel::VERSION).not_to be nil
  end
end
