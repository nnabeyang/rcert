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
    prob.add_option :say => 'hello'
    prob.add_option :say => 'world' 
    prob.set_answer
    assert prob.select(0)
    assert !prob.select(1)
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
    assert prob.select(0)
    assert !prob.select(1)
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
    assert prob.select(0)
    assert !prob.select(1)
    Rcert.application.clear
  end
  def test_application_run
    Rcert.application.clear
    str = Rcert::random_string(5)
    problem :problem_1 do
      description <<-DESC
        以下のコードを実行したとき表示されるものを1つ選択してください
      DESC
      src <<-SRC
        puts "#{str}"[<%= @range %>]
      SRC
      option :range => "2..4"
      option :range => "2...4"
    end
    problem :problem_2 do
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
    answers = [0, 1]
    Rcert.application.run do|p|
      p.set_answer
      p.select(0)
    end
    out = StringIO.new
    Rcert.application.status(out)
    Rcert.application.clear
    assert_match %r"\d+/\d+$", out.string
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
    assert prob.select(0)
    assert !prob.select(1)
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
    assert !prob.select(0)
    assert prob.select(3)
    Rcert.application.clear
  end
end
