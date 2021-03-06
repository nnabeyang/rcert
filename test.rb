#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-
require 'minitest/autorun'
require './rcert'
class Tests < MiniTest::Test
  def test_random_string
     size = 1 + rand(9)
     s = Rcert::Problem.new(:problem_name).random_string(size)
     assert_equal size, s.size
     assert_match /\A\w+\z/, s
  end
  def test_problem_object
    prob = Rcert::Problem.new :problem_name, <<-SRC
      puts "<%= @say %>"
    SRC
    prob.option :say => 'hello'
    prob.option :say => 'world' 
    prob.set_answer
    assert_equal "以下のコードを実行したとき表示されるものを全て選択してください", prob.default_description
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
  end
  def test_application_define_problem
    app = Rcert::Application.new
    prob = app.define_problem Rcert::Problem, :problem_name do
      src <<-SRC
        puts "#{random_string(5)}"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    prob.set_answer
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
  end
  def test_problem
    Rcert.application.clear
    prob = problem :problem_name do
      src <<-SRC
        puts "#{random_string(5)}"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    prob.set_answer
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
    Rcert.application.clear
  end
  def test_application_run
    Rcert.application.clear
    problem :problem_1 do
      src <<-SRC
        puts "hello_world"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    method_problem :problem_2 do
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option "first"
      option "shift"
    end
    src1 = <<-RUBY
def foo
  puts 'foo'
  end
foo
    RUBY
    src2 = <<-RUBY
def foo
  fail 'failed'
end
foo
      RUBY
 
    program_problem :problem_3 do
      option src1
      option src2
    end
 
    original_dir = Dir.pwd
    Dir.chdir('./data/')
    out = StringIO.new
    Rcert.application.status(out)
    assert_match %r"\d/3$", out.string
    begin
      Rcert.application.run do|p|
        p.set_answer
        p.select(1)
      end
      out = StringIO.new
      Rcert.application.status(out)
      assert_match %r"0/3$", out.string
      out.string = ""
      Rcert.application.report_result(out)
      assert_match /^problem_1:$/, out.string
      assert_match /"llo\\n"/, out.string
      assert_match /"ll\\n"$/, out.string
      assert_match /^problem_2:$/, out.string
      assert_match /first/, out.string
      assert_match /shift/, out.string
      assert_match /^problem_3:$/, out.string
      assert_match /#{src1.sub(/\A\s*/, '')}/m, out.string
      assert_match /#{src2.sub(/\A\s*/, '')}/m, out.string
      Rcert.application.clear
    ensure
      Dir.chdir(original_dir)
    end
  end
  def test_method_problem
    Rcert.application.clear
    prob = method_problem :problem_name do
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option "first"
      option "shift"
    end
    prob.set_answer
    assert_equal "以下のように出力されるメソッドを全て選択してください", prob.default_description
    out = prob.render
    assert_match /Ruby\nRuby\n/, out 
    assert_match /first/, out 
    assert_match /shift/, out
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
    Rcert.application.clear
  end
  def test_problem_with_error_code
    Rcert.application.clear
    prob = method_problem :problem_1 do
      src <<-SRC
        [0, 1, 4, 9].<%= @method_name %> {|x, y| p [x, y]}
      SRC
      option "each_with_index"
      option "no_such_method"
      option "no_such_method2"
      option "no_such_method3"
    end
    prob.set_answer
    assert prob.select(0)[1]
    assert !prob.select(3)[1]
    prob = method_problem :problem_2 do
      src <<-SRC
        [0, 1, 4, 9].<%= @method_name %> {|x, y| p [x, y]}
      SRC
      option "no_such_method"
      option "each_with_index"
      option "no_such_method2"
      option "no_such_method3"
    end
    prob.set_answer
    assert !prob.select(0)[1]
    assert prob.select(0, 2, 3)[1]
    assert_equal "<error>", prob.options[0].out
    Rcert.application.clear
  end
  def test_context
    s = StringIO.new
    $stdout = s
    Rcert::Context.class_eval(<<-SRC, 'fname', 1)
      def foo1234
       puts "foo"
      end
      foo1234
    SRC
    assert_equal "foo\n", s.string
    $stdout = STDOUT
  end
  def test_src_define_method
     Rcert.application.clear
    prob = program_problem :problem_name do
      src <<-RUBY
        def foo
        <%= @src %>
        end
        foo
      RUBY
      option <<-RUBY
          puts 'foo'
      RUBY
      option <<-RUBY
          fail 'failed'
      RUBY
    end
    prob.set_answer
    assert_equal "以下のように出力されるコードを全て選択してください", prob.default_description
    out = prob.render
    assert_match /def foo/, out
    assert_match /puts 'foo'/, out
    assert_match /fail 'failed'/, out
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
    Rcert.application.clear
  end
  def test_application_run_argv
    ARGV.clear
    Rcert.application.clear
    problem :p1 do
      src <<-SRC
        puts "hello_world"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    problem :p2 do
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option :method_name => "first"
      option :method_name => "shift"
    end
    problem :p3 do
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option :method_name => "first"
      option :method_name => "shift"
    end
    original_dir = Dir.pwd
    Dir.chdir('./data/')
    begin
      plist = []
      ARGV << "p2" << "p1"
      Rcert.application.run do|p|
        plist << p.name
        [0, true]
      end
      assert_equal [:p1, :p2], plist
    ensure
      ARGV.clear
      Rcert.application.clear
      Dir.chdir(original_dir)
    end
  end
  def test_rescue_syntax_error
     Rcert.application.clear
    program_problem :problem_name do
      option "puts 'hello"
      option "puts 'hello'" 
    end
    Rcert.application.clear
  end
  def test_method_problem_select_multiple_answers
    Rcert.application.clear
    prob = method_problem :problem_name do
      src <<-SRC
        puts [1, 2, 3, 4].<%= @method_name %> {|x| x*x}.inspect
      SRC
      option "collect"
      option "map"
      option "each"
    end
    prob.set_answer
    assert !prob.select(0)[1]
    assert !prob.select(1)[1]
    assert !prob.select(2)[1]
    assert !prob.select(2, 1, 0)[1]
    assert prob.select(0, 1)[1]
    Rcert.application.clear
  end
  def test_problem_select_multiple_answers
    Rcert.application.clear
    prob = program_problem :problem_name do
      option <<-SRC
puts ("Ca" 'fe')
      SRC
      option <<-'SRC'
puts (%q!Cafe!)
      SRC
      option <<-SRC
puts 0xCafe
      SRC
      option <<-SRC
puts ?C + ?a + ?f + ?e
      SRC
      option <<-SRC
puts (0800)
      SRC
    end
    prob.set_answer
    assert !prob.select(0)[1]
    assert !prob.select(1)[1]
    assert !prob.select(2)[1]
    assert prob.select(0, 1, 3)[1]
    Rcert.application.clear
  end
  def test_method_problem_error_messages
    Rcert.application.clear
    method_problem :problem_name do
      src <<-SRC
        puts [1, 2, 3, 4].<%= @method_name %> {|x| x*x}.inspect
      SRC
      option "collect"
      option "map"
      option "each"
    end
    original_dir = Dir.pwd
    Dir.chdir('./data/')
    Rcert.application.run do|p|
      p.set_answer
      p.select(0, 2)
    end
    out = StringIO.new
    Rcert.application.report_result(out)
    assert_match /["map", "collect"]/, out.string
    assert_match /["collect", "each"]/, out.string
    Rcert.application.clear
  ensure
    Dir.chdir(original_dir)
  end
  def test_program_problem_error_messages
    Rcert.application.clear
    program_problem :problem_name do
      option <<-SRC
puts ("Ca" 'fe')
      SRC
      option <<-'SRC'
puts (%q!Cafe!)
      SRC
      option <<-SRC
puts 0xCafe
      SRC
      option <<-SRC
puts ?C + ?a + ?f + ?e
      SRC
      option <<-SRC
puts (0800)
      SRC
    end
    original_dir = Dir.pwd
    Dir.chdir('./data/')
    Rcert.application.run do|p|
      p.set_answer
      p.select(0, 2)
    end
    out = StringIO.new
    Rcert.application.report_result(out)
    assert_match /puts \(%q!Cafe!\)/, out.string
    assert_match /puts \?C \+ \?a \+ \?f \+ \?e/, out.string
    assert_match /puts \("Ca" 'fe'\)/, out.string
    assert_match /puts 0xCafe/, out.string
    Rcert.application.clear
  ensure
    Dir.chdir(original_dir)
  end
end
