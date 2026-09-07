require 'minitest/autorun'
require 'active_support/all'
require 'action_dispatch/http/upload'
require 'tempfile'
require_relative '../app/services/desk_chatwoot_source'

class DeskSourcePayloadTest < Minitest::Test
  def test_rejects_invalid_ids_notes_and_empty_payloads
    source = DeskChatwootSource.new(2)
    assert_raises(DeskChatwootSource::Denied) { source.send(:validate_content!, { 'echo_id' => '../x' }) }
    assert_raises(DeskChatwootSource::Denied) { source.send(:validate_content!, { 'echo_id' => 'safe', 'private' => true }) }
    assert_raises(DeskChatwootSource::Denied) { source.send(:validate_files!, {}) }
    assert_raises(DeskChatwootSource::Denied) { source.send(:validate_files!, { 'attachments' => ['not-a-file'] }) }
  end

  def test_multipart_preserves_files_and_correlation_id
    source = DeskChatwootSource.new(2)
    Tempfile.create('desk-payload') do |file|
      file.write('test fixture')
      file.flush
      upload = ActionDispatch::Http::UploadedFile.new(tempfile: file, filename: 'test.txt', type: 'text/plain')
      files = source.send(:validate_files!, { 'attachments' => [upload] })
      body = { echo_id: 'test-id', content_attributes: { desk_request_id: 'test-id' } }
      fields = source.send(:multipart_fields, body, {}, files)
      assert_equal 'test-id', fields.assoc('echo_id')[1]
      assert_equal 'test-id', JSON.parse(fields.assoc('content_attributes')[1])['desk_request_id']
      assert_equal file, fields.assoc('attachments[]')[1]
      assert_equal 0, file.pos
    end
  end
end
