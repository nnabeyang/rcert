#!/usr/bin/ruby1.9.1
# -*- encoding: utf-8 -*-
require 'test/unit'
require './rcert'
class Tests < Test::Unit::TestCase
  def test_random_string
     size = 1 + rand(9)
     s = Rcert.random_string(size)
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
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
  end
  def test_application_define_problem
    app = Rcert::Application.new
    str = Rcert::random_string(5)
    app.define_problem Rcert::Problem, :problem_name do
      src <<-SRC
        puts "#{str}"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    prob = app[:problem_name]
    prob.set_answer
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
  end
  def test_problem
    Rcert.application.clear
    str = Rcert::random_string(5)
    problem :problem_name do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        puts "#{str}"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    prob = Rcert.application[:problem_name]
    prob.set_answer
    assert prob.select(0)[1]
    assert !prob.select(1)[1]
    Rcert.application.clear
  end
  def test_application_run
    Rcert.application.clear
    problem :problem_1 do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        puts "hello_world"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    method_problem :problem_2 do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option :method_name => "first"
      option :method_name => "shift"
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
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      option src1
      option src2
    end
 
    original_dir = Dir.pwd
    Dir.chdir('./data/')
    out = StringIO.new
    Rcert.application.status(out)
    assert_match %r"0/3$", out.string
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
  def test_method_problem
    Rcert.application.clear
    str = Rcert::random_string(5)
    method_problem :problem_name do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option :method_name => "first"
      option :method_name => "shift"
    end
    prob = Rcert.application[:problem_name]
    prob.set_answer
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
    method_problem :problem_name do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        [0, 1, 4, 9].<%= @method_name %> {|x, y| p [x, y]}
      SRC
      option :method_name => "no_such_method"
      option :method_name => "no_such_method2"
      option :method_name => "no_such_method3"
      option :method_name => "each_with_index"
    end
    prob = Rcert.application[:problem_name]
    prob.set_answer
    assert !prob.select(0)[1]
    assert prob.select(3)[1]
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
    program_problem :problem_name do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      option <<-RUBY
        def foo
          puts 'foo'
        end
        foo
      RUBY
      option <<-RUBY
        def foo
          fail 'failed'
        end
        foo
      RUBY
    end
    prob = Rcert.application[:problem_name]
    prob.set_answer
    out = prob.render
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
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        puts "hello_world"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    problem :p2 do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        x = ["Ruby", "Perl", "C"]
        puts x.<%= @method_name %>
        puts x[0] 
      SRC
      option :method_name => "first"
      option :method_name => "shift"
    end
    problem :p3 do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
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
    plist = []
    ARGV << "p2" << "p1"
    Rcert.application.run do|p|
      plist << p.name
      [0, true]
    end
    assert_equal [:p1, :p2], plist
    ARGV.clear
    Rcert.application.clear
  ensure
    Dir.chdir(original_dir)
  end
end
