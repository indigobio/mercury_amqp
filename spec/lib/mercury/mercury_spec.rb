require 'spec_helper'
require 'mercury'

describe Mercury do
  include MercuryFakeSpec

  # These tests just cover the basics. Most of the testing is
  # done in the Mercury::Monadic spec for convenience.

  let!(:sent) { { 'a' => 1 } }
  let!(:source) { 'test-exchange' }
  let!(:queue) { 'test-queue' }

  describe '::open' do
    it 'opens a mercury instance' do
      em do
        Mercury.open do |m|
          expect(m).to be_a Mercury
          m.close do
            done
          end
        end
      end
    end
  end

  describe '#close' do
    itt 'closes the connection' do
      em do
        Mercury.open do |m|
          m.close do
            expect { m.publish(queue, {'a' => 1}) }.to raise_error /connection is closed/
            done
          end
        end
      end
    end
  end

  describe '#start_listener' do
    itt 'listens for messages' do
      with_mercury do |m|
        received = []
        m.start_listener(source, received.method(:push)) do
          m.publish(source, sent) do
            em_wait_until(proc{received.any?}) do
              expect(received.size).to eql 1
              expect(received[0].content).to eql sent
              m.close do
                done
              end
            end
          end
        end
      end
    end
  end

  describe '#start_worker' do
    itt 'listens for messages' do
      with_mercury do |m|
        received = []
        m.start_worker(queue, source, received.method(:push)) do
          m.publish(source, sent) do
            em_wait_until(proc{received.any?}) do
              expect(received.size).to eql 1
              expect(received[0].content).to eql sent
              m.close do
                done
              end
            end
          end
        end
      end
    end
  end

  describe '#publish' do
    context 'docker assumptions' do
      after(:each) { start_rabbitmq_server }
      # This test is commented out because it make assumptions about, and manipulates, a local docker orchestration.
      # Uncomment and run it in a suitable environment to do semi-automated testing on publisher confirms.
      # it 'waits to invoke its continuation until after the message is confirmed' do
      #   got_confirmation = false
      #   expect {
      #     with_mercury(timeout_seconds: 15) do |m|
      #       m.publish(source, 'hello') do # cause `source` to be declared so subsequent publishes simply publish
      #         stop_rabbitmq_server
      #         m.publish(source, 'hello') do
      #           got_confirmation = true
      #           m.close { done }
      #         end
      #       end
      #     end
      #   }.to raise_error /Lost connection to AMQP server/
      #   expect(got_confirmation).to be false
      # end
    end
    it 'allows multiple outstanding confirmations' do
      log = []
      with_mercury do |m|
        m.publish(source, 'hello') do # cause `source` to be declared so subsequent publishes simply publish
          publish_and_confirm(m, 'a', log)
          publish_and_confirm(m, 'b', log)
          em_wait_until(proc { log.size == 4 }) do
            expect(log).to eql ['publish a', 'publish b', 'confirm a', 'confirm b']
            m.close { done }
          end
        end
      end
    end

    def publish_and_confirm(m, name, log)
      m.publish(source, name) do
        log << "confirm #{name}"
      end
      log << "publish #{name}"
    end
  end

  def start_rabbitmq_server
    Dir.chdir(File.expand_path('~/git/docker/local_orchestration')) do
      system('docker-compose start rabbitmq')
    end
    puts 'done.'
  end

  def stop_rabbitmq_server
    Dir.chdir(File.expand_path('~/git/docker/local_orchestration')) do
      system('docker-compose stop rabbitmq')
    end
    puts 'done.'
  end

  def with_mercury(timeout_seconds: 3, &block)
    sources = [source]
    queues = [queue]
    em(timeout_seconds: timeout_seconds) { delete_sources_and_queues_cps(sources, queues).run{done} }
    em(timeout_seconds: timeout_seconds) { Mercury.open(&block) }
    em(timeout_seconds: timeout_seconds) { delete_sources_and_queues_cps(sources, queues).run{done} }
  end

end

