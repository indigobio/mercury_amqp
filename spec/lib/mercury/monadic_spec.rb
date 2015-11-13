require 'rspec'
require 'spec_helper'
require 'mercury'
require 'mercury/monadic'
require 'securerandom'
require 'logatron/logatron'

describe Mercury::Monadic do
  include Cps::Methods
  include MercuryFakeSpec

  let!(:source1) { 'test-exchange1' }
  let!(:source2) { 'test-exchange2' }
  let!(:source) { source1 }
  let!(:queue1) { 'test-queue1' }
  let!(:queue2) { 'test-queue2' }
  let!(:queue) { queue1 }
  let!(:worker) { queue }
  let!(:tag1) { 'tag1' }
  let!(:tag2) { 'tag2' }
  let!(:tag) { tag1 }
  let!(:msg1) { {'a' => 1} }
  let!(:msg2) { {'b' => 2} }
  let!(:msg3) { {'c' => 3} }
  let!(:msg4) { {'d' => 4} }
  let!(:msg) { msg1 }
  let!(:long_enough_to_receive_any_messages) { 0.5 } # seconds

  # Sending an receiving are complementary operations. You can't test
  # one without testing the other. Consequently, these tests verify
  # system behavior rather than method contracts.

  itt 'sends and receives messages' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_listener(source1, &msgs.method(:push)) }
        and_then { m.publish(source1, msg1) }
        and_then { m.publish(source2, msg2) } # different source
        and_then { m.publish(source1, msg3) }
        and_then { wait_until { msgs.size == 2 } }
        and_lift do
          msgs.each { |msg| expect(msg).to be_a Mercury::ReceivedMessage }
          expect(msgs[0].content).to eql(msg1)
          expect(msgs[1].content).to eql(msg3)
        end
      end
    end
  end

  itt 'sends and receives tagged messages' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_listener(source, tag_filter: tag1, &msgs.method(:push)) }
        and_then { m.publish(source, msg1, tag: tag1) }
        and_then { m.publish(source, msg2, tag: tag2) } # different tag
        and_then { m.publish(source, msg3, tag: tag1) }
        and_then { wait_until { msgs.size == 2 } }
        and_lift do
          expect(msgs[0].content).to eql(msg1)
          expect(msgs[0].tag).to eql(tag1)
          expect(msgs[1].content).to eql(msg3)
          expect(msgs[1].tag).to eql(tag1)
        end
      end
    end
  end

  itt 'sends and receives headers' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_listener(source, &msgs.method(:push)) }
        and_then { m.publish(source, msg, headers: {'foo' => 'bar'}) }
        and_then { wait_until { msgs.size == 1 } }
        and_lift do
          expect(msgs[0].headers['foo']).to eql 'bar'
        end
      end
    end
  end

  it 'propagates logatron headers' do
    real_msg_id = SecureRandom.uuid
    Logatron.msg_id = real_msg_id
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_listener(source, &msgs.method(:push)) }
        and_then { m.publish(source, msg) }
        and_lift { Logatron.msg_id = 'fake_msg_id' }
        and_then { wait_until { msgs.size == 1 } }
        and_lift do
          expect(msgs[0].headers['X-Ascent-Log-Id']).to eql real_msg_id
          expect(Logatron.msg_id).to eql real_msg_id
        end
      end
    end
  end

  itt 'uses AMQP-style tag filters' do
    test_with_mercury do |m|
      successes = []
      failures = []
      bars = []
      everything = []
      seql do
        and_then { m.start_listener(source, tag_filter: '*.success', &successes.method(:push)) }
        and_then { m.start_listener(source, tag_filter: '*.failure', &failures.method(:push)) }
        and_then { m.start_listener(source, tag_filter: 'bar.*', &bars.method(:push)) }
        and_then { m.start_listener(source, tag_filter: '#', &everything.method(:push)) }
        and_then { m.publish(source, msg1, tag: 'foo.success') }
        and_then { m.publish(source, msg2, tag: 'foo.failure') }
        and_then { m.publish(source, msg3, tag: 'bar.success') }
        and_then { m.publish(source, msg4, tag: 'bar.failure') }
        and_then { wait_until { successes.size == 2 && failures.size == 2 && bars.size == 2 && everything.size == 4 } }
        and_lift do
          expect(successes[0].content).to eql(msg1)
          expect(successes[1].content).to eql(msg3)
          expect(failures[0].content).to eql(msg2)
          expect(failures[1].content).to eql(msg4)
          expect(bars[0].content).to eql(msg3)
          expect(bars[1].content).to eql(msg4)
          expect(everything[0].content).to eql(msg1)
          expect(everything[1].content).to eql(msg2)
          expect(everything[2].content).to eql(msg3)
          expect(everything[3].content).to eql(msg4)
        end
      end
    end
  end

  itt 'workers share a queue' do
    test_with_mercury do |m|
      seql do
        let(:m2) { Mercury::Monadic.open }
        work1 = []
        work2 = []
        and_then { m.start_worker(worker, source, &push_and_ack(work1)) }
        and_then { m2.start_worker(worker, source, &push_and_ack(work2)) }
        and_then { m.publish(source, msg1) }
        and_then { m.publish(source, msg2) }
        and_then { wait_until { work1.size + work2.size == 2 } }
        and_lift { expect((work1 + work2).map(&:content).uniq.size).to eql 2 }
        and_then { m2.close }
      end
    end
  end

  itt 'workers can specify tag filters' do
    test_with_mercury do |m|
      seql do
        let(:m2) { Mercury::Monadic.open }
        work1 = []
        work2 = []
        and_then { m.start_worker(worker, source, tag_filter: 'success', &push_and_ack(work1)) }
        and_then { m2.start_worker(worker, source, tag_filter: 'failure', &push_and_ack(work2)) }
        and_then { m.publish(source, msg1, tag: 'success') }
        and_then { m.publish(source, msg2, tag: 'failure') }
        and_then { wait_until { work1.size == 1 && work2.size == 1 } }
        and_lift do
          expect(work1[0].content).to eql msg1
          expect(work2[0].content).to eql msg2
        end
        and_then { m2.close }
      end
    end
  end

  def push_and_ack(array)
    proc do |msg|
      array.push(msg)
      msg.ack
    end
  end

  itt 'a worker must ack before receiving another message' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_worker(worker, source, &msgs.method(:push)) }
        and_then { m.publish(source, msg1) }
        and_then { m.publish(source, msg2) }
        and_then { wait_for(long_enough_to_receive_any_messages) }
        and_lift { expect(msgs.size).to eql 1 }
        and_lift { msgs[0].ack }
        and_then { wait_until { msgs.size == 2 } }
      end
    end
  end

  itt 'rejected messages are not requeued' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_worker(worker, source, &msgs.method(:push)) }
        and_then { m.publish(source, msg) }
        and_then { wait_until { msgs.size == 1 } }
        and_lift { msgs[0].reject }
        and_then { wait_for(long_enough_to_receive_any_messages) }
        and_lift { expect(msgs.size).to eql 1}
      end
    end
  end

  itt 'nacked messages are requeued' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_worker(worker, source, &msgs.method(:push)) }
        and_then { m.publish(source, msg) }
        and_then { wait_until { msgs.size == 1 } }
        and_lift { msgs[0].nack }
        and_then { wait_until { msgs.size == 2} }
      end
    end
  end

  it 'unacked messages are requeued (client failure)' do
    test_with_mercury do |m|
      msgs = []
      seql do
        and_then { m.start_worker(worker, source, &msgs.method(:push)) }
        and_then { m.publish(source, msg) }
        and_then { wait_until { msgs.size == 1 } }
        and_then { m.close }
        let(:m2) { Mercury::Monadic.open }
        and_then { m2.start_worker(worker, source, &msgs.method(:push)) }
        and_then { wait_until { msgs.size == 2 } }
      end
    end
  end

  it 'raises when an error occurs' do
    # verify it registers a handler
    expect_any_instance_of(AMQP::Channel).to receive(:on_error) {|&b| @handler = b}

    # verify the handler raises an error
    expect do
      em do
        Mercury.open do
          ch = double
          info = double(reply_code: 'code', reply_text: 'text')
          @handler.call(ch, info)
        end
      end
    end.to raise_error 'An error occurred: code - text'
  end

  describe '#delete_source' do
    itt 'deletes the source if it exists' do
      test_with_mercury do |m|
        seql do
          and_then { m.start_listener(source) }
          let(:r1) { m.source_exists?(source) }
          and_lift { expect(r1).to be true    }
          and_then { m.delete_source(source)  }
          let(:r2) { m.source_exists?(source) }
          and_lift { expect(r2).to be false   }
        end
      end
    end
    itt 'does nothing if the source does not exist' do
      test_with_mercury do |m|
        seql do
          and_then { m.delete_source(source)  }
          let(:r)  { m.source_exists?(source) }
          and_lift { expect(r).to be false    }
        end
      end
    end
  end

  describe '#delete_work_queue' do
    itt 'deletes the queue if it exists' do
      test_with_mercury do |m|
        seql do
          and_then { m.start_worker(queue, source) }
          let(:r1) { m.queue_exists?(queue)        }
          and_lift { expect(r1).to be true         }
          and_then { m.delete_work_queue(queue)    }
          let(:r2) { m.queue_exists?(queue)        }
          and_lift { expect(r2).to be false        }
        end
      end
    end
    itt 'does nothing if the queue does not exist' do
      test_with_mercury do |m|
        seql do
          and_then { m.delete_work_queue(queue)    }
          let(:r)  { m.queue_exists?(queue)        }
          and_lift { expect(r).to be false         }
        end
      end
    end
  end

  describe '#source_exists?' do
    itt 'returns false when the source does not exist' do
      test_with_mercury do |m|
        m.source_exists?('asdf').
          and_lift { |result| expect(result).to be false }
      end
    end

    it 'returns true when the source exists' do
      test_with_mercury do |m|
        m.source_exists?('amq.direct').
          and_lift { |result| expect(result).to be true }
      end
    end
  end

  describe '#queue_exists?' do
    itt 'returns false when the queue does not exist' do
      test_with_mercury do |m|
        m.queue_exists?('asdf').
          and_lift { |result| expect(result).to be false }
      end
    end

    itt 'returns true when the source exists' do
      test_with_mercury do |m|
        m.start_worker(queue1, source1, proc{}).
          and_then { m.queue_exists?(queue1) }.
          and_lift { |result| expect(result).to be true }
      end
    end
  end

  describe '#open' do
    it 'relays args to Mercury.open' do
      logger = double
      expect(Mercury).to receive(:open).with(logger: logger, host: 'asdf')
      Mercury::Monadic.open(logger: logger, host: 'asdf').run
    end
  end

  # the block must return a Cps
  def test_with_mercury(&block)
    sources = [source1, source2]
    queues = [queue1, queue2]
    test_with_mercury_cps(sources, queues, &block)
  end
end

