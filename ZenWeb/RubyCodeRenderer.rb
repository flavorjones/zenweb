require 'ZenWeb/GenericRenderer'

=begin

= Class RubyCodeRenderer

Finds paragraphs prefixed with "!" and evaluates them with xmp

=== Methods

=end

class RubyCodeRenderer < GenericRenderer

=begin

--- RubyCodeRenderer#render(content)

    Finds paragraphs prefixed with "!" and evaluates them with xmp

=end

  def render(content)

    text = content.split($PARAGRAPH_RE)
    
    text.each { | p |

      if (p =~ /^\s*\!/m) then

	p.gsub!(/^[\ \t]*\!/, '')
	
	begin
	  cmd = "irb --prompt xmp --noreadline 2>/dev/null"
	  puts "Running irb for code:"
	  puts p
	  IO.popen(cmd, "r+") { |xmp|
	    p.split(/\n/).each { |line|
	      push("  #{line}")
	      if line !~ /^\s+\#/ then
		xmp.puts(line)
		s = xmp.gets.chomp!
		s.sub!(/==>(.*)$/, '==\\><EM>\1</EM>')
		push("    #{s}")
	      end
	    }
	  }
	rescue Exception => something
	  $stderr.puts "xmp: #{something}\nTrace =\n" + $@.join("\n") + "\n"
	end
      else
	push(p)
      end
      push("\n\n")
    }
    
    # put it back into line-by-line format
    @result = @result.join("\n").scan(/^.*[\n\r]+/)

    return self.result
  end
end
