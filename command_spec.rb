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

    def test_suggestions
        assert_nothing_raised do
            @dispatcher.register(
                literal('cmd').then(
                    literal('sub')
                ).then(
                    literal('sob')
                )
            )
            @dispatcher.register(
                literal('command').then(
                    argument(:arg).suggests {['no1', 'no2', '3on']}
                ).then(
                    literal('lit')
                )
            )
        end
        assert_equal(['cmd', 'command'].sort, @dispatcher.suggest(''))
        assert_equal(['cmd', 'command'].sort, @dispatcher.suggest('c'))
        assert_equal(['cmd'].sort, @dispatcher.suggest('cm'))
        assert_equal(['cmd'].sort, @dispatcher.suggest('cmd'))
        assert_equal(['sub', 'sob'].sort, @dispatcher.suggest('cmd '))
        assert_equal(['sub', 'sob'].sort, @dispatcher.suggest('cmd s'))
        assert_equal(['sob'].sort, @dispatcher.suggest('cmd so'))
        assert_equal(['no1', 'no2', '3on', 'lit'].sort, @dispatcher.suggest('command '))
        assert_equal(['no1', 'no2'].sort, @dispatcher.suggest('command n'))
        assert_equal(['lit'].sort, @dispatcher.suggest('command l'))
        assert_equal(['3on'].sort, @dispatcher.suggest('command 3on'))
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'a'}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest ' '}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'command  '}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'command sdhsjdh'}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'command lit '}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'command no2 '}
        assert_raise_kind_of(ParsingError) {@dispatcher.suggest 'command no2 ahjsdh'}
    end
end