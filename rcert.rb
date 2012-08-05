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
  DEFAULT_RCERT_FILE = 'Rcertfile'
  class Application
    def initialize
      @problems = {}
      @point = 0
    end
    def run(&block)
      load DEFAULT_RCERT_FILE if File.exist? DEFAULT_RCERT_FILE
      @problems.sort_by{rand}.each do|k, p|
        @point += 1 if block.call(p)
      end
    end
    def status(out = STDOUT)
      out.puts "score: #{@point}/#{@problems.size}"
    end
    def clear
      @problems.clear
    end
    def define_problem(name, &block)
      prob = Problem.new(name)
      @problems[name.to_s] = prob
      prob.instance_eval(&block) 
    end
    def [](key)
      @problems[key.to_s]
    end
  end
  class Option
    include Helper
    attr_reader :out
    def initialize(attrs)
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
    attr_reader :options, :name
    attr_writer :answer
    def initialize(name, data = nil)
      @name = name
      @options = []
      src(data) if data
    end
    def set_answer
      @answer = @options[0]
    end
    def render
      @options = @options.sort_by {rand}
      set_answer
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
      option.eval "_#{@name}"
      @options << option 
      option
    end
    def select(idx)
      return (@answer.out == @options[idx].out)? true : false 
    end
    def description text
      @desc = text
    end
    alias option add_option 
  end
  extend Helper
end
def problem(name, &block)
  Rcert.application.define_problem(name, &block)
end
