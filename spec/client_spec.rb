require 'spec_helper'

describe SqsBuffer::Client do
  before(:all) do
    @aws_client = Aws::SQS::Client.new(
      region:            ENV['region'],
      access_key_id:     ENV['accessKeyId'],
      secret_access_key: ENV['secretAccessKey']
    )
  end

  before do
    @buffer = SqsBuffer::Client.new(
      queue_url: "test.notread",
      client: @aws_client,
    )
  end

  context 'exceptions while polling' do
    before do
      allow(buffer_poller).to \
        receive(:poll).and_raise("AWS ERROR")
    end

    after do
      @buffer.stop_polling
    end

    it 'does not kill the worker thread' do
      @buffer.start_polling
      sleep(2)
      expect(@buffer.worker_thread_alive?).to eq(true)
    end

    it 'retries after some time' do
      expect(buffer_poller).to receive(:poll).at_least(:twice)
      @buffer.start_polling
      sleep(4)
      @buffer.stop_polling
    end

  end

  def buffer_poller
    @buffer.instance_variable_get(:@poller)
  end

end


