mercury
=======

Mercury is a messaging layer intended to hide complexity for typical
messaging scenarios. It is backed by the AMQP gem and consequently
runs in an EventMachine reactor and has an asynchronous API. Mercury
consists of _sources_, _work queues_, and _listeners_. A message is
published to a source, to which one or more work queues and/or
listeners are attached. These map roughly to AMQP constructs:

- **source**: topic exchange
- **work queue**: durable named queue
- **listener**: temporary anonymous queue
- **tag**: routing key

At the moment, mercury is backed by AMQP and serializes messages as
JSON. In the future, additional transports and message formats may be
supported.

Mercury writes string messages directly without encoding; this allows
a client to pre-encode a message using an arbitrary encoding. The
receiving client receives the encoded bytes as the message content
(assuming the encoded message fails to parse as JSON).


```ruby
require 'mercury'

def run
  EventMachine.run do
    Mercury.open do |m|
      m.start_worker('cooks', 'orders', method(:handle_message)) do
        m.publish('orders', {'table' => 5, 'items' => ['salad', 'steak', 'cake']})
      end
    end
  end
end

def handle_message(msg)
  order = msg.content
  cook(order)
  msg.ack
end
```

Notably, mercury also has a monadic interface that hides the explicit
continuation passing introduced by asynchrony, which has the effect of
flattening chained calls. This is particularly useful for testing,
where the same code plays both sides of a conversation. Compare:

```ruby
require 'mercury'

Mercury.open do |m|
  m.start_listener(source, proc{}) do
    m.source_exists?(source) do |r1|
      expect(r1).to be true
      m.delete_source(source) do
        m.source_exists?(source) do |r2|
          expect(r2).to be false
          m.close do
            done
          end
        end
      end
    end
  end
end

# ... vs ...

require 'mercury/monadic'

seq do
  let(:m)  { Mercury::Monadic.open    }
  and_then { m.start_listener(source) }
  let(:r1) { m.source_exists?(source) }
  and_lift { expect(r1).to be true    }
  and_then { m.delete_source(source)  }
  let(:r2) { m.source_exists?(source) }
  and_lift { expect(r2).to be false   }
  and_then { m.close                  }
  and_lift { done                     }
end
```

Design Decisions
----------------

#### Continuation blocks are required

It would be possible to make continuation blocks optional. The problem is that this allows the user
to make the mistake of treating the API as synchronous and only discover their error when tests fail,
probably intermittently. An empty block can be passed, but at least it indicates that the continuation
is being intentionally ignored.

