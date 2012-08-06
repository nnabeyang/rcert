# -*- encoding: utf-8 -*-
require 'erb'
require 'stringio'
require 'time'
class ERB
  def self.call(source)
    new(source, nil, nil, 'output_buffer').src
  end
end
module Rcert
  module Helper
    ALPHABET = ('a'..'z').to_a
    ALPHABET_SIZE = ALPHABET.size
    def random_string size
      Array.new(size) { ALPHABET[rand(ALPHABET_SIZE)] }.join
    end
  end
  class << self
    def application
      @app ||= Application.new
    end
  end
  class FailureProblem
    def initialize(idx, problem)
      @problem = problem
      @expected = problem.answer
      @actual = problem.options[idx]
    end
    def to_s
       template = [ 
      "<%= @problem.name %>:\n",
      "expected:<%= @problem.answer.out.inspect %>, ",
      "actual:<%= @actual.out.inspect %>"
      ].join
      ERB.new(template).result(binding)
    end
  end
  DEFAULT_RCERT_FILE = 'Rcertfile'
  class Application
    attr_reader :problems
    def initialize
      @problems = {}
      @failures = []
      @successes = []
    end
    def run(&block)
      @path = File.expand_path(DEFAULT_RCERT_FILE)
      load @path if File.exist? @path 
      if ARGV.size > 0
        problems = @problems.select {|k, v| ARGV.include?(k.to_s) }
      else
        problems = @problems.sort_by{rand}
      end
      problems.each do|k, p|
         run_program(p, &block)
      end
    end
    def run_program(problem, &block)
     idx, success = block.call(problem)
     if success
       @successes.push(problem)
     else
       @failures.push(FailureProblem.new(idx, problem))
     end
    end
    def status(out = STDOUT)
      out.puts "score: #{point}/#{@problems.size}"
    end
    def report_result(out = STDOUT)
      out.puts "load:#{@path}"
      datetime_line = "--------#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}-----------"
      out.puts datetime_line
      @failures.each do|f|
        out.puts f
      end 
      out.puts  ('-'*datetime_line.size)
    end
    def point
      @successes.size
    end
    def clear
      @problems.clear
      @failures.clear
    end
    def define_problem(problem_class, name, &block)
      prob = problem_class.new(name)
      @problems[name.to_s] = prob
      prob.instance_eval(&block) 
    end
    def [](key)
      @problems[key.to_s]
    end
  end
  class Context
    def self.instance
      @instance ||= new
    end
    def self.method_missing(*args, &block)
      instance.send(*args, &block)
    end
  end
  class Option
    include Helper
    attr_reader :out, :attrs
    def initialize(attrs)
      @attrs = attrs
      attrs.each do|k, v|
        instance_variable_set("@#{k}", v)
      end
      @context = Context
    end
    def to_s
      @code
    end
    def eval name
      s = StringIO.new
      $stdout = s
      @code = send(name)
      begin
        @context.class_eval(@code, name, 1)
        @out = s.string
      rescue => e
        @out = "<error>"
        raise e
      end
    ensure
      $stdout = STDOUT
    end
  end
  class Problem
    attr_reader :options, :name, :answer
    attr_writer :answer
    def initialize(name, data = nil)
      @name = name
      @options = []
      @error_options = []
      src(data) if data
    end
    class << self
      def define_problem(name, &block)
        Rcert.application.define_problem(self, name, &block)
      end
    end
    def set_answer
      @answer = (@options - @error_options)[0]
    end
    def prepare
      @options = @options.sort_by {rand}
      set_answer
    end
    def render
      template = [ 
      "<%= @desc %>",
      "<%= @answer %>",
      "<% options.each_with_index do|opt, i| %>",
      "<%= i %>)<%= opt.out.inspect %>\n",
      "<% end %>"
      ].join
      ERB.new(template).result(binding)
    end
    def src data
      @code_template = data
      @code = <<-RUBY
        def _#{@name}
          #{ERB.call(data)}
          output_buffer
        end
      RUBY
    end
    def option(value)
      option = Option.new(value)
      klass = option.singleton_class
      klass.class_eval(@code) 
      begin
        option.eval "_#{@name}"
      rescue
        @error_options.push(option)
      ensure
        @options << option 
        option
      end
    end
    def select(idx)
      success = (@answer.out == @options[idx].out)? true : false
      return [idx, success]
    end
    def description text
      @desc = text
    end
  end
  class MethodProblem < Problem
    def render
      template = [ 
      "<%= @desc %>",
      "<%= @code_template %>",
      "---------\n",
      "<%= @answer.out %>",
      "---------\n",
      "<% options.each_with_index do|opt, i| %>",
      "<%= i %>)<%= opt.attrs %>\n",
      "<% end %>"
      ].join
      ERB.new(template).result(binding)
    end
  end
  class ProgramProblem < Problem
    def initialize(name, data = nil)
      super
      src "<%= @src %>"
    end
    def option(value)
      super :src => value
    end
    def render
      template = [ 
      "<%= @desc %>",
      "<% unless @answer.out.to_s.chomp.empty? %>",
      "---------\n",
      "<%= @answer.out %>",
      "---------\n",
      "<% end %>",
      "<% options.each_with_index do|opt, i| %>",
      "<%= i %>)\n<%= opt.attrs[:src].to_s %>",
      "<% end %>"
      ].join
      ERB.new(template).result(binding)
    end
  end
  extend Helper
end
def problem(name, &block)
  Rcert::Problem.define_problem(name, &block)
end
def method_problem(name, &block)
  Rcert::MethodProblem.define_problem(name, &block)
end
def program_problem(name, &block)
  Rcert::ProgramProblem.define_problem(name, &block)
end
