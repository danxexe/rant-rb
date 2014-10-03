require 'rltk'
require 'rltk/ast'
require 'pry'
require 'colorize'

module Rant
end

class Rant::Lexer < RLTK::Lexer
  escapes = {
    'n' => "\n",
    'r' => "\r",
    'b' => "\b",
  }

  # Block definition
  rule(/\{/) { push_state(:block); :LBRACES } # Open block
  rule(/\{/, :block) { push_state(:block); :LBRACES } # Nested open block
  rule(/\|/, :block) { :PIPE } # Option separator
  rule(/\\/, :block) { push_state(:escape); [] } # Start escape sequence
  rule(/[^{}|\\]*/, :block) { |t| [:TEXT, t] } # Text inside block
  rule(/\}/, :block) { pop_state; :RBRACES } # Close block

  # Escape sequences
  rule(/\\/) { push_state(:escape); [] } # Start escape sequence
  rule(/[{}\\|]/, :escape) { |t| pop_state; [:TEXT, t] } # Escape special characters
  rule(/[#{escapes.keys.join}]/, :escape) { |t| pop_state; [:TEXT, escapes[t]] } # Escape control sequences
  rule(/[^{}|]/, :escape) { |t| pop_state; [:TEXT, "\\#{t}"] } # Unescapable character

  rule(/[^{}\\]*/) { |t| [:TEXT, t] } # Text node
end

class Rant::Node < RLTK::ASTNode

  def inspect_name
    self.class.name.split('::').last.cyan
  end

  def run
    ''
  end
end

class Rant::Pattern < Rant::Node
  value :nodes, Array

  def inspect
    "<#{nodes.map(&:inspect).join(', ')}>"
  end

  def run
    nodes.map(&:run).join
  end
end

class Rant::Block < Rant::Node
  value :options, Array

  def inspect
    "[#{options.map(&:inspect).join(' | ')}]"
  end

  def run
    (sample = options.sample) && sample.run
  end
end

class Rant::Text < Rant::Node
  value :text, String

  def inspect
    text.inspect.green
  end

  def run
    text
  end
end

class Rant::Parser < RLTK::Parser

  p(:pattern, 'subpattern+') {|l| Rant::Pattern.new(l) }
  p :subpattern do
    c('block') {|l| l }
    c('text') {|t| t }
  end

  production :block do
    clause('LBRACES options RBRACES') {|_, o, _| Rant::Block.new(o) }
  end

  list(:options, 'pattern', :PIPE)

  production(:text, 'TEXT') { |t| Rant::Text.new(t) }

  finalize
end

class Rant::Interpreter

  def run(ast)
    ast = Rant::Parser::parse(Rant::Lexer::lex(ast)) if ast.kind_of?(String)
    ast.run
  end

end

interpreter = Rant::Interpreter.new

DATA.each_line do |line|
  ast = Rant::Parser::parse(Rant::Lexer::lex(line.strip))
  puts ast.inspect
  puts
  puts interpreter.run(ast).light_green
  puts
end

__END__
This is plain | text with {a block|something} and more text
{single option}
Escaping \\\ \{\}
| \| {\{|\}|\|}
-\n-\r-\ba
{small: {a|b}|BIG: {A|B}}