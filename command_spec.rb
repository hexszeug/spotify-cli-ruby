require './command'
require 'test/unit'

class CommandTest < Test::Unit::TestCase
    include Command

    def setup
        @dispatcher = CommandDispatcher.new
    end

    def test_simple_command
        calls = 0
        assert_nothing_raised do
            @dispatcher.register(
                literal('simple').executes do |ctx|
                    calls += 1
                    assert_equal('simple', ctx.last_tracked.name)
                    assert_equal(1, ctx.nodes.length)
                end
            )
        end
        assert_nothing_raised { @dispatcher.execute('simple') }
        assert_equal(1, calls)
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'abc' }
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'simple arg' }
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'simple ' }
        assert_equal(1, calls)
    end

    def test_simple_word_argument_command
        calls = 0
        input = nil
        assert_nothing_raised do
            @dispatcher.register(
                literal('simple').then(
                    argument(:word).executes do |ctx|
                        calls += 1
                        input = ctx[:word]
                        assert_equal(:word, ctx.last_tracked.name)
                    end
                )
            )
        end
        assert_nothing_raised { @dispatcher.execute 'simple test' }
        assert_equal(1, calls)
        assert_equal('test', input)
        assert_nothing_raised { @dispatcher.execute 'simple input' }
        assert_equal(2, calls)
        assert_equal('input', input)
        assert_nothing_raised { @dispatcher.execute 'simple ' }
        assert_equal(3, calls)
        assert_equal('', input)
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'simple' }
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'simple arg1 arg2' }
        assert_raise_kind_of(ParsingError) { @dispatcher.execute 'simple arg ' }
        assert_equal(3, calls)
    end

    def test_two_literal_commands
        calls1 = 0
        calls2 = 0
        assert_nothing_raised do
            @dispatcher.register(
                literal('cmd1').executes do
                    calls1 += 1
                end
            )
        end
        assert_nothing_raised do
            @dispatcher.register(
                literal('cmd2').executes do
                    calls2 += 1
                end
            )
        end
        assert_nothing_raised { @dispatcher.execute 'cmd1' }
        assert_equal(1, calls1)
        assert_equal(0, calls2)
        assert_nothing_raised { @dispatcher.execute 'cmd2' }
        assert_equal(1, calls1)
        assert_equal(1, calls2)
    end

    def test_argument_or_literal_command
        calls1 = 0
        calls2 = 0
        assert_nothing_raised do
            @dispatcher.register(
                literal('cmd').then(
                    literal('sub_cmd').executes do
                        calls1 += 1
                    end
                ).then(
                    argument(:arg).executes do |ctx|
                        calls2 += 1
                        assert_equal('test_arg', ctx[:arg])
                    end
                )
            )
        end
        assert_nothing_raised { @dispatcher.execute 'cmd sub_cmd' }
        assert_equal(1, calls1)
        assert_equal(0, calls2)
        assert_nothing_raised { @dispatcher.execute 'cmd test_arg' }
        assert_equal(1, calls1)
        assert_equal(1, calls2)
    end
end