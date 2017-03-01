require 'spec_helper'
require 'mercury/cps'

describe Cps do
  include Cps::Methods

  let!(:a) { 123 }

  describe '::lift' do
    it 'CPS-transforms a non-CPS proc' do
      expect(Cps.lift{rand}.run).to be_a Numeric
    end
    it 'raises an error if the block returns a Cps object' do
      expect{lift{lift{'cps'}}.run}.to raise_error /returned a Cps/
    end
  end

  describe '::run' do
    it 'passes the value to the continuation' do
      expect{|b| lift{a}.run(&b)}.to yield_with_args(a)
    end
    it 'returns the return value of the continuation' do
      expect(lift{a}.run{456}).to eql 456
    end
    it 'feeds its arguments into the Cps' do
      expect{|b| Cps.identity.run(a, &b)}.to yield_with_args(a)
    end
  end

  describe '#and_then' do
    it 'composes two Cps instances' do
      expect(lift{a}.and_then{|x| to_string(x)}.run).to eql a.to_s
    end
    it 'raises an error if the block does not return a Cps object' do
      expect{lift{a}.and_then{'not-cps'}.run}.to raise_error /did not return a Cps/
    end
  end

  describe '#and_lift' do
    it 'composes a Cps instance with a normal proc' do
      expect(lift{a}.and_lift{|x| x.to_s}.run).to eql a.to_s
    end
    it 'raises an error if the block returns a Cps object' do
      expect{lift{a}.and_lift{lift{'cps'}}.run}.to raise_error /returned a Cps/
    end
  end

  describe '::concurrently' do
    it 'composes Cps instances concurrently' do
      em do
        actions = []
        started1 = false
        finished2 = false

        task1 = proc do |n, &k|
          actions << 'start1'
          started1 = true
          em_wait_until(proc{finished2}) do
            actions << 'finish1'
            k.call(n.to_s)
          end
        end
        task2 = proc do |n, &k|
          em_wait_until(proc{started1}) do
            actions << 'start2'
            actions << 'finish2'
            finished2 = true
            k.call(-1 * n)
          end
        end

        result = nil
        Cps.concurrently(Cps.new(&task1), Cps.new(&task2)).run(42) { |r| result = r }
        em_wait_until(proc{result}) do
          expect(result).to eql [['42'], [-42]]
          expect(actions).to eql %w(start1 start2 finish2 finish1)
          done
        end
      end
    end
  end

  describe '::seq' do
    it 'binds a sequence of monadic functions' do
      result = Cps.seq do |th|
        th.en { to_string(a) }
        th.en { |v| twice(v) }
        th.en { |v| reverse(v) }
      end.run
      expect(result).to eql '321321'
    end
    it 'can be chained' do
      result = Cps.seq do |th|
        th.en { to_string(a) }
        th.en { |v| twice(v) }
        th.en do |v|
          Cps.seq do |th|
            th.en { reverse(v)  }
            th.en { |v| surround(v) }
          end
        end
      end.run
      expect(result).to eql '*321321*'
    end
  end

  describe '::seql' do
    it 'binds a sequence of monadic functions' do
      result = Cps.seql do
        let(:v)  { to_string(a) }
        let(:v)  { twice(v) }
        and_then { reverse(v) }
      end.run
      expect(result).to eql '321321'
    end
    it 'can be chained' do
      result = Cps.seql do
        let(:v) { to_string(a) }
        let(:v) { twice(v) }
        and_then do
          Cps.seql do
            let(:v) { reverse(v) }
            and_then { surround(v) }
          end
        end
      end.run
      expect(result).to eql '*321321*'
    end
    it 'can be used like seq' do
      result = Cps.seql do
        and_then { to_string(a) }
        and_then { |v| twice(v) }
        and_then { |v| reverse(v) }
      end.run
      expect(result).to eql '321321'
    end
    it 'passes a bound value to the next function' do
      result = Cps.seql do
        let(:v) { to_string(a) }
        and_then { |x| lift{x} }
      end.run
      expect(result).to eql '123'
    end
    it 'block can access outer methods' do
      Cps.seql do
        expect(foo).to eql 'foo'
      end
    end
    def foo
      'foo'
    end
    it 'block can access outer variables' do
      bar = 'bar'
      Cps.seql do
        expect(bar).to eql 'bar'
      end
    end
    it 'block cannot access outer instance variables' do
      @baz = 'baz'
      Cps.seql do
        expect(@baz).to eql nil
      end
    end
    it 'block can access outer constants' do
      Cps.seql do
        expect(FLIP).to eql 'flip'
      end
    end
    FLIP = 'flip'
  end

  describe '::identity' do
    it 'passes its arguments to the continuation' do
      expect{|b| Cps.identity.run(a, &b)}.to yield_with_args(a)
    end
  end

  describe '#inject' do
    it 'creates a Cps chain given an array and a transformation function' do
      chain = lift{'entity'}.inject(['-ize', '-er']) do |suffix, v|
        lift { v + suffix }
      end
      expect(chain.run).to eql 'entity-ize-er'
    end
  end

  # verify Cps obeys the monad laws (https://wiki.haskell.org/Monad_laws)
  # unit   ::= Cps::lift
  # bind   ::= Cps#and_then

  it 'obeys the left identity law' do
    # return a >>= f  ===  f a
    expect_identical(lift{a}.and_then(&method(:to_string)),
                     to_string(a),
                     '123')
  end

  it 'obeys the right identity law' do
    # m >>= return  === m
    m = lift{123}
    expect_identical(m.and_then{|x| lift{x}},
                     m,
                     123)
  end

  it 'obeys the associativity law' do
    # (m >>= f) >>= g  ===  m >>= (\x -> f x >>= g)
    m = lift{123}
    expect_identical((m.and_then(&method(:to_string))).and_then(&method(:twice)),
                     m.and_then {|x| to_string(x).and_then(&method(:twice)) },
                     '123123')
  end

  def expect_identical(lhs, rhs, expected_value)
    expect{|b| lhs.run(&b)}.to yield_with_args(expected_value)
    expect{|b| rhs.run(&b)}.to yield_with_args(expected_value)
  end

  def to_string(x)
    lift { x.to_s }
  end

  def twice(x)
    lift { x * 2 }
  end

  def reverse(x)
    lift { x.reverse }
  end

  def surround(x)
    lift { "*#{x}*" }
  end
end
