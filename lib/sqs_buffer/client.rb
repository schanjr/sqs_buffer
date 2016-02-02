require 'thread'
require 'aws-sdk'
require 'concurrent'

module SqsBuffer
  class Client
    def initialize(opts)
      @queue_url = opts.fetch(:queue_url) { |k| missing_key!(k) }
      client = opts.fetch(:client) { |k| missing_key!(k) }

      @poller = Aws::SQS::QueuePoller.new(@queue_url, client: client)
      @skip_delete = opts.fetch(:skip_delete, true)
      @max_number_of_messages = opts.fetch(:max_number_of_messages, 10)
      @logger = opts.fetch(:logger, Logger.new(STDOUT))
      @process_block = Concurrent::MutexAtomicReference.new
      @before_request_block = Concurrent::MutexAtomicReference.new
      @process_block = Concurrent::MutexAtomicReference.new
      @message_queue = Concurrent::Array.new
      @last_process_time = Concurrent::AtomicFixnum.new(Time.now.to_i)
      @running = Concurrent::AtomicBoolean.new(false)
      @max_wait_time = Concurrent::AtomicFixnum.new(
        opts.fetch(:max_wait_time, 300)
      )
      @max_queue_threshold = Concurrent::AtomicFixnum.new(
        opts.fetch(:max_queue_threshold, 100)
      )
      configure_before_request_block
    end

    def start_polling
      @running.make_true

      @worker_thread = Thread.new do
        opts = {
          skip_delete: @skip_delete,
          max_number_of_messages: @max_number_of_messages
        }
        @poller.poll(opts) do |messages|
          store_messages(messages)
        end
      end # End worker thread

      @running.value
    end

    def queue_url
      @queue_url
    end

    def stop_polling
      @running.make_false
    end

    def buffer_full?
      @message_queue.length >= @max_queue_threshold.value
    end

    def buffer_empty?
      @message_queue.empty?
    end

    def buffer_length
      @message_queue.length
    end

    def buffer
      # Return a copy of the array events to guard against potential mutation
      Marshal.load( Marshal.dump(@message_queue) )
    end

    def shutting_down?
      @running.false? && worker_thread_alive?
    end

    def running?
      @running.true? && worker_thread_alive?
    end

    def worker_thread_alive?
      !@worker_thread.nil? && @worker_thread.alive?
    end

    def last_process_time_stale?
      @last_process_time.value < Time.now.to_i - @max_wait_time.value
    end

    def process_all_messages
      @process_block.value.call(buffer)
      delete_all_messages
      touch_process_time
    rescue StandardError => e
      @logger.error "An exception(#{e.message}) occurred while process the message queue: #{@message_queue.join("\n")} | Backtrace: #{e.backtrace}"
    end

    def process_block(&block)
      @process_block.value = block
    end

    def before_request_block(&block)
      @before_request_block.value = block
    end

    private

    def need_to_process?
      if !buffer_empty? && (buffer_full? || last_process_time_stale?)
        true
      else
        false
      end
    end

    def missing_key!(k)
      raise ":#{k} is a required key!"
    end

    def configure_before_request_block
      @poller.before_request do |stats|
        if @running.false?
          @logger.info "Shutting down. Processing all messages first..."
          process_all_messages
          @logger.info "All messages have been processed. Throwing :stop_polling"
          throw :stop_polling
        end
        if @before_request_block.value
          @before_request_block.value.call(stats)
        end
        if need_to_process?
          process_all_messages
        end
      end # End Poller loop
    end

    def store_messages(messages)
      messages.each do |msg|
        store_message(msg)
      end
    end

    def store_message(msg)
      @message_queue << msg
    rescue StandardError => e
      @logger.error "Exception: #{e.message} while storing message: #{msg} | Backtrace: #{e.backtrace}"
    end

    def touch_process_time
      @last_process_time.value = Time.now.to_i
    end

    def delete_all_messages
      while @message_queue.length > 0 do
        messages = @message_queue.shift(10)
        @poller.delete_messages(messages)
      end
    end

  end
end

