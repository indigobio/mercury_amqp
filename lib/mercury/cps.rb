require 'mercury/cps/seq'
require 'mercury/cps/seq_with_let'
require 'mercury/cps/methods'
require 'mercury/utils'

# Async IO often involves CPS (continuation-passing style)
# code, where the continuation (a.k.a. "callback") is passed
# to a function to be invoked at a later time. CPS style
# can result in deep lexical nesting making code difficult
# to read.
# This monad hides the CPS plumbing, which allows code
# to be written in a flat style with no visible continuation
# passing. It basically wraps a CPS proc with methods for
# composing them.
# See http://codon.com/refactoring-ruby-with-monads
class Mercury
  class Cps
    attr_reader :cps

    # @param [Proc] cps a CPS proc (signature: *args, &k)
    def initialize(&cps)
      @cps = cps
    end

    # Applies the wrapped proc. If the CPS return value
    # is not needed, the continuation k may be omitted.
    # Returns the return value of the continuation.
    def run(*args, &k)
      k ||= proc { |x| x }
      cps.call(*args, &k)
    end

    # The "bind" operation; composes two Cps
    # @param [Proc] pm a proc that takes the output of this
    #   Cps and returns a Cps
    def and_then(&pm)
      Cps.new do |*args, &k|
        run(*args) do |*args2|
          next_cps = yield(*args2)
          next_cps.is_a?(Cps) || raise("'and_then' block did not return a Cps object. Did you want 'and_lift'? at #{pm.source_location}")
          next_cps.run(&k)
        end
      end
    end

    # equivalent to: and_then { lift { ... } }
    def and_lift
      and_then do |*args|
        Cps.lift { yield(*args) }
      end
    end

    # Returns a Cps for a non-CPS proc.
    def self.lift(&p)
      new do |*args, &k|
        value = p.call(*args)
        if value.is_a?(Cps)
          # This is technically valid, but 99% of the time it indicates a programming error.
          raise "'lift' block returned a Cps object. Did you want 'and_then'? at #{p.source_location}"
        end
        k.call(value)
      end
    end

    # The identity function as a Cps.
    def self.identity
      new { |*args, &k| k.call(*args) }
    end

    # Returns a Cps that executes the provided Cpses concurrently.
    # Once all complete, their return values are passed to the continuation
    # in an array with positions corresponding to the provided Cpses.
    def self.concurrently(*cpss)
      cpss = Utils.unsplat(cpss)

      Cps.new do |*in_args, &k|
        pending_completions = cpss
        returned_args = []
        cpss.each_with_index do |cps, i|
          cps.run(*in_args) do |*out_args|
            returned_args[i] = out_args
            pending_completions.delete(cps)
            k.call(returned_args) if pending_completions.none?
          end
        end
      end
    end

    # Calls and_then for each x.
    # @yieldparam  x     [Object]  An item from xs
    # @yieldparam  *args [Objects] The value(s) passed from the last action
    # @yieldreturn       [Cps]     The next action to add to the chain
    def inject(xs)
      xs.inject(self) do |chain, x|
        chain.and_then { |*args| yield(x, *args) }
      end
    end

    # equivalent to Cps.identity.inject(...)
    def self.inject(xs, &block)
      Cps.identity.inject(xs, &block)
    end
  end
end

Cps = Mercury::Cps
