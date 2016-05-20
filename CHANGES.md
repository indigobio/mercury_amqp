## [0.6.0](https://github.com/indigobio/mercury_amqp/compare/v0.5.0...indigobio:v0.6.0) (2016-05-12)

- Added ReceivedMessage#republish
  ([c534476](https://github.com/indigobio/mercury_amqp/commit/c53447683ccb8ab0d0e51dc56c7e276620738d93))


## [0.5.0](https://github.com/indigobio/mercury_amqp/compare/v0.4.0...indigobio:v0.5.0) (2016-05-10)

- Mercury#republish
  ([dc1b352](https://github.com/indigobio/mercury_amqp/commit/dc1b352707ea5f425192b67f449b17bc57aea6aa))
- Added quick monad tutorial
  ([30117a9](https://github.com/indigobio/mercury_amqp/commit/30117a950da01327a29c5d173d3fe155fadc26a2))


## [0.4.0](https://github.com/indigobio/mercury_amqp/compare/v0.3.0...indigobio:v0.4.0) (2016-04-28)

- Coerce nil tag_filter to '#'
  ([7df50f4](https://github.com/indigobio/mercury_amqp/commit/7df50f4bbc75fb5a292a200e14e35f783d4e1aba))
- Improved README
  ([1727266](https://github.com/indigobio/mercury_amqp/commit/17272662693707f5edb6368ef9ea5e0a8e47a56f))
- Mercury::Fake.install
  ([2eaf6b4](https://github.com/indigobio/mercury_amqp/commit/2eaf6b4744e246ffb748da4ea93b12dc639651d2))
- install_lost_connection_error_handler as soon as possible
  ([70252b8](https://github.com/indigobio/mercury_amqp/commit/70252b8a4e2005d967cfc9a874ac86b496e2bc03))
- Emulate public method guards in Mercury::Fake
  ([3aa574b](https://github.com/indigobio/mercury_amqp/commit/3aa574b8ba8fae1f0cb75ad1d252d0e678f0a779))
- Guard against a closed mercury instance being used.
  ([7802fb3](https://github.com/indigobio/mercury_amqp/commit/7802fb3193ca77ba98648b5732ab99f5a3c2195a))
- Raise an error when lift/and_lift is used incorrectly
  ([17019c0](https://github.com/indigobio/mercury_amqp/commit/17019c06e5345432c217831046591c336d9aeadc))


## [0.3.0](https://github.com/indigobio/mercury_amqp/compare/v0.2.0...indigobio:v0.3.0) (2016-04-22)

- Actually use logger passed in; improved acking
  ([8b4bba9](https://github.com/indigobio/mercury_amqp/commit/8b4bba9a810444d9da9e87c6e3ff65bc27a6fc86))


## [0.2.0](https://github.com/indigobio/mercury_amqp/compare/v0.1.9...indigobio:v0.2.0) (2016-04-20)

- Make publisher confirms optional
  ([1552bbe](https://github.com/indigobio/mercury_amqp/commit/1552bbe8be485c1ecaed2c7e3b44043aa3a7685b))
- Improve error reporting
  ([ada6600](https://github.com/indigobio/mercury_amqp/commit/ada6600cc79d9c4f7fd13046c7e2b821dae5a138))
- Use publisher acknowledgements
  ([59b2f30](https://github.com/indigobio/mercury_amqp/commit/59b2f307530a675600ceae27756b5e378a8691e4))


## [0.1.9](https://github.com/indigobio/mercury_amqp/compare/v0.1.7...indigobio:v0.1.9) (2016-03-12)

- Crash on connection failure
  ([e4763df](https://github.com/indigobio/mercury_amqp/commit/e4763df0401657edaadc88b630ca80f29f91aa22))


## [0.1.7](https://github.com/indigobio/mercury_amqp/compare/v0.1.6...indigobio:v0.1.7) (2016-03-02)

- Temporarily make Cps top level for backwards compatibility
  ([6fd6b36](https://github.com/indigobio/mercury_amqp/commit/6fd6b36da7928de6f7c59bb85be9b10c1879b3a9))


## [0.1.6](https://github.com/indigobio/mercury_amqp/compare/v0.1.5...indigobio:v0.1.6) (2016-03-02)

- Moved Cps and Utils under Mercury:: to avoid conflicts
  ([b0329e5](https://github.com/indigobio/mercury_amqp/commit/b0329e5d50ed35e10edf65938efb7bacb159c1de))


## [0.1.5](https://github.com/indigobio/mercury_amqp/compare/v0.1.4...indigobio:v0.1.5) (2016-02-09)

- Made the number of simultaneous messages that can be handled configurable
  ([19b9bd9](https://github.com/indigobio/mercury_amqp/commit/19b9bd9bebc07ba470d1b746f0e11119bd08b368))


## [0.1.4](https://github.com/indigobio/mercury_amqp/compare/v0.1.3...indigobio:v0.1.4) (2015-12-17)

- Added convenience method to read all messages given a source and a worker. ALso added cps benchmark
  ([0c55a5a](https://github.com/indigobio/mercury_amqp/commit/0c55a5a8e036fc7cd559cd9afabae7075635ce58))


## [0.1.3](https://github.com/indigobio/mercury_amqp/compare/v0.1.2...indigobio:v0.1.3) (2015-11-23)

- Fixed nil headers bug
  ([90020f3](https://github.com/indigobio/mercury_amqp/commit/90020f3f8c634c04998f44c298910c7c5e889606))


## [0.1.2](https://github.com/indigobio/mercury_amqp/compare/v0.1.1...indigobio:v0.1.2) (2015-11-13)

- Fixed gemspec
  ([5bfe847](https://github.com/indigobio/mercury_amqp/commit/5bfe8476e09b374ed17b044384110884f0194619))


## [0.1.1](https://github.com/indigobio/mercury_amqp/compare/v0.1.0...indigobio:v0.1.1) (2015-11-13)

- Propagate logatron msg id
  ([43205bf](https://github.com/indigobio/mercury_amqp/commit/43205bf581f1f2a18068783b3231d968ad505897))
- Rebranded as mercury_amqp
  ([4aa63aa](https://github.com/indigobio/mercury_amqp/commit/4aa63aa6e80032aeb6b5dffd931393f5bdbb21b0))


## [0.1.0](https://github.com/indigobio/mercury_amqp/compare/d914fc1acfde2e563867d63bd6c913882272fb53...indigobio:v0.1.0) (2015-09-14)

- ReceivedMessage#nack
  ([4de8990](https://github.com/indigobio/mercury_amqp/commit/4de8990054bbf59ee95b018bf8a4dae7fc8525ac))
- Fixed Mercury::Monadic.open to relay args to Mercury.open
  ([edc0d6d](https://github.com/indigobio/mercury_amqp/commit/edc0d6dd2b611500786c8b2f9665b28ff6343408))
- Implemented Mercury::Fake
  ([14e6169](https://github.com/indigobio/mercury_amqp/commit/14e61692666de086c55759efeaff4bdb32b6a34c))
- Implemented mercury
  ([222e490](https://github.com/indigobio/mercury_amqp/commit/222e490834750039c4f4d26763190b0888806f10))
