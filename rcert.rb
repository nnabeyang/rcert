# -*- encoding: utf-8 -*-
require 'erb'
require 'stringio'
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
      "expected:<%= @problem.answer.out.inspect %>, \n",
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
    end
    def run(&block)
      load DEFAULT_RCERT_FILE if File.exist? DEFAULT_RCERT_FILE
      @problems.sort_by{rand}.each do|k, p|
         idx, success = block.call(p)
         @failures.push(FailureProblem.new(idx, p)) unless success
      end
    end
    def status(out = STDOUT)
      out.puts "score: #{point}/#{@problems.size}"
    end
    def report_result(out = STDOUT)
      @failures.each do|f|
        out.puts f
      end 
    end
    def point
      @problems.size - @failures.size
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
  class Option
    include Helper
    attr_reader :out, :attrs
    def initialize(attrs)
      @attrs = attrs
      attrs.each do|k, v|
        instance_variable_set("@#{k}", v)
      end
    end
    def to_s
      @code
    end
    def eval name
      s = StringIO.new
      $stdout = s
      @code = send(name)
      Kernel.eval(@code, nil, name, 1)
      @out = s.string
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
    def add_option(value)
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
    alias option add_option 
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
  extend Helper
end
def problem(name, &block)
  Rcert::Problem.define_problem(name, &block)
end
def method_problem(name, &block)
  Rcert::MethodProblem.define_problem(name, &block)
end
