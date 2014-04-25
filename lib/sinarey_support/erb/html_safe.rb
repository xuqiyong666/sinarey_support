require 'erb'
require 'sinarey_support/core_ext/string/output_safety'

class ERB
  class Compiler
    def compile(s)
      enc = s.encoding
      raise ArgumentError, "#{enc} is not ASCII compatible" if enc.dummy?
      s = s.dup.force_encoding("ASCII-8BIT") # don't use constant Enoding::ASCII_8BIT for miniruby
      enc = detect_magic_comment(s) || enc
      out = Buffer.new(self, enc)
      content = ''
      scanner = make_scanner(s)
      scanner.scan do |token|
        next if token.nil?
        next if token == ''
        if scanner.stag.nil?
          case token
          when PercentLine
            add_put_cmd(out, content) if content.size > 0
            content = ''
            out.push(token.to_s)
            out.cr
          when :cr
            out.cr
          when '<%', '<%==', '<%=', '<%#'
            scanner.stag = token
            add_put_cmd(out, content) if content.size > 0
            content = ''
          when "\n"
            content << "\n"
            add_put_cmd(out, content)
            content = ''
          when '<%%'
            content << '<%'
          else
            content << token
          end
        else
          case token
          when '%>'
            case scanner.stag
            when '<%'
              if content[-1] == ?\n
                content.chop!
                out.push(content)
                out.cr
              else
                out.push(content)
              end
            when '<%=='
              add_insert_cmd(out, content)
            when '<%='
              add_insert_escapehtml_cmd(out, content)
            when '<%#'
              # out.push("# #{content_dump(content)}")
            end
            scanner.stag = nil
            content = ''
          when '%%>'
            content << '%>'
          else
            content << token
          end
        end
      end
      add_put_cmd(out, content) if content.size > 0
      out.close
      return out.script, enc
    end

    def add_insert_cmd(out, content)
      out.push("#{@insert_cmd}((#{content}).to_s)")
    end

    def add_insert_escapehtml_cmd(out, content)
      out.push("#{@insert_cmd}(ERB::Util.sinarey_escape((#{content})))")
    end

    class TrimScanner < Scanner
      def scan_line(line)
        line.scan(/(.*?)(<%%|%%>|<%==|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end
      def trim_line1(line)
        line.scan(/(.*?)(<%%|%%>|<%==|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if token == "%>\n"
              yield('%>')
              yield(:cr)
            else
              yield(token)
            end
          end
        end
      end
      def trim_line2(line)
        head = nil
        line.scan(/(.*?)(<%%|%%>|<%==|<%=|<%#|<%|%>\n|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            head = token unless head
            if token == "%>\n"
              yield('%>')
              if is_erb_stag?(head)
                yield(:cr)
              else
                yield("\n")
              end
              head = nil
            else
              yield(token)
              head = nil if token == "\n"
            end
          end
        end
      end
      def explicit_trim_line(line)
        line.scan(/(.*?)(^[ \t]*<%\-|<%\-|<%%|%%>|<%==|<%=|<%#|<%|-%>\n|-%>|%>|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            if @stag.nil? && /[ \t]*<%-/ =~ token
              yield('<%')
            elsif @stag && token == "-%>\n"
              yield('%>')
              yield(:cr)
            elsif @stag && token == '-%>'
              yield('%>')
            else
              yield(token)
            end
          end
        end
      end
      ERB_STAG << '<%=='
      def is_erb_stag?(s)
        ERB_STAG.member?(s)
      end
    end
    Scanner.default_scanner = TrimScanner
    class SimpleScanner < Scanner # :nodoc:
      def scan
        @src.scan(/(.*?)(<%%|%%>|<%==|<%=|<%#|<%|%>|\n|\z)/m) do |tokens|
          tokens.each do |token|
            next if token.empty?
            yield(token)
          end
        end
      end
    end
    Scanner.regist_scanner(SimpleScanner, nil, false)
    begin
      require 'strscan'
      class SimpleScanner2 < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(<%%|<%==|<%=|<%#|<%|\z)/m
          etag_reg = /(.*?)(%%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])
            yield(scanner[2])
          end
        end
      end
      Scanner.regist_scanner(SimpleScanner2, nil, false)
      class ExplicitScanner < Scanner # :nodoc:
        def scan
          stag_reg = /(.*?)(^[ \t]*<%-|<%%|<%==|<%=|<%#|<%-|<%|\z)/m
          etag_reg = /(.*?)(%%>|-%>|%>|\z)/m
          scanner = StringScanner.new(@src)
          while ! scanner.eos?
            scanner.scan(@stag ? etag_reg : stag_reg)
            yield(scanner[1])
            elem = scanner[2]
            if /[ \t]*<%-/ =~ elem
              yield('<%')
            elsif elem == '-%>'
              yield('%>')
              yield(:cr) if scanner.scan(/(\n|\z)/)
            else
              yield(elem)
            end
          end
        end
      end
      Scanner.regist_scanner(ExplicitScanner, '-', false)
    rescue LoadError
    end
  end
end
