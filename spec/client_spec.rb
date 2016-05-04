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

  context '#buffer()' do
    before do
      @buffer = SqsBuffer::Client.new(
        queue_url: "test.notread",
        client: @aws_client,
      )
    end

    it 'works with anonymous classes in the buffer' do
      buffer_queue << Class.new
      expect { @buffer.buffer }.to_not raise_error
    end

    it 'returns a copy of the buffer' do
      expect(@buffer.buffer.object_id).to_not eq(buffer_queue.object_id)
    end

  end

  def buffer_poller
    @buffer.instance_variable_get(:@poller)
  end

  def buffer_queue
    @buffer.instance_variable_get(:@message_queue)
  end

end


