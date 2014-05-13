module Diffy
  class HtmlFormatter
    def initialize(diff, options = {})
      @diff = diff
      @options = options
    end

    def to_s
      if @options[:highlight_words]
        wrap_lines(highlighted_words)
      else
        wrap_lines(@diff.map{|line| wrap_line(ERB::Util.h(line))})
      end
    end

    private
    def wrap_line(line)
      cleaned = clean_line(line)
      case line
      when /^(---|\+\+\+|\\\\)/
        '    <li class="diff-comment"><span>' + line.chomp + '</span></li>'
      when /^\+/
        '    <li class="ins"><ins>' + cleaned + '</ins></li>'
      when /^-/
        '    <li class="del"><del>' + cleaned + '</del></li>'
      when /^ /
        '    <li class="unchanged"><span>' + cleaned + '</span></li>'
      when /^@@/
        '    <li class="diff-block-info"><span>' + line.chomp + '</span></li>'
      end
    end

    # remove +/- or wrap in html
    def clean_line(line)
      if @options[:include_plus_and_minus_in_html]
        line.sub(/^(.)/, '<span class="symbol">\1</span>')
      else
        line.sub(/^./, '')
      end.chomp
    end

    def wrap_lines(lines)
      if lines.empty?
        %'<div class="diff"></div>'
      else
        %'<div class="diff">\n  <ul>\n#{lines.join("\n")}\n  </ul>\n</div>\n'
      end
    end

    def highlighted_words
      chunks = @diff.each_chunk.
        reject{|c| c == '\ No newline at end of file'"\n"}
      
      # patch starts
      i = 0
      chunks.each do |element|
        chunks[i] = element.gsub(/\.\s|&nbsp;<\/p><p>|\?\s|!\s/,".\r\n")
        i += 1
      end
      temp_chunks = Array.new
      full_chunks = Array.new
      chunks.each do |chunk|
        temp_chunks = chunk.split("\r\n")
        temp_chunks.each do |t|
          #t = " #{t}"
          full_chunks << t
        end
      end
      chunks = full_chunks
      #find indices of the 2 elements of chunks array containing + and - in their 1st positions
      #replace + and - by blank
      #start comparing elements in pairs starting from those 2 indices
      #if elements are different, insert a blank space at the beginning of the element
      #else for the 1st element, insert - at the beginning of the element
      #     for the 2nd element, insert + at the beginning of the element
      
      i = 0
      k = 0
      j = 0
      chunks.each do |line|
        if line[0] == "-"
          p "j assigned"
          line[0] = ""
          j = i 
        end
        if line[0] == "+"
          p "k assigned"
          line[0] = ""
          k = i 
        end
        i += 1
      end
      p "value of j is #{j}"
      p "value of k is #{k}"
      i = k
      p "value of i is #{i}"
      
      chunks_to_delete = Array.new
      until j==i do
        if chunks[j] != chunks[k]
          chunks << "-#{chunks[j]}"
          chunks[j] = "Del#{chunks[j]}"
          chunks_to_delete << chunks[j]
          chunks << "+#{chunks[k]}"
          chunks[k] = "Del#{chunks[k]}"
          chunks_to_delete << chunks[k]
        else
          chunks << " #{chunks[j]}"
          chunks[k] = "Del#{chunks[k]}"
          chunks[j] = "Del#{chunks[j]}"
          chunks_to_delete << chunks[j]
        end
        j += 1
        k += 1
      end

      chunks_to_delete.each do |e|
        chunks.delete("#{e}")
        k -= 1
      end

      p "latest chunks... #{chunks}"
      p "k is: #{k}"
      p "size of chunk:"
      p chunks.size

       j = 0
       while j<i-k do
         temp = chunks.shift
         chunks << temp
         j += 1
       end

      # patch ends
      
      processed = []
      lines = chunks.each_with_index.map do |chunk1, index|
        next if processed.include? index
        processed << index
        chunk1 = chunk1
        chunk2 = chunks[index + 1]
        if not chunk2
          next ERB::Util.h(chunk1)
        end

        dir1 = chunk1.each_char.first
        dir2 = chunk2.each_char.first
        case [dir1, dir2]
        when ['-', '+']
          if chunk1.each_char.take(3).join("") =~ /^(---|\+\+\+|\\\\)/ and
              chunk2.each_char.take(3).join("") =~ /^(---|\+\+\+|\\\\)/
            ERB::Util.h(chunk1)
          else
            line_diff = Diffy::Diff.new(
                                        split_characters(chunk1),
                                        split_characters(chunk2)
                                        )
            hi1 = reconstruct_characters(line_diff, '-')
            hi2 = reconstruct_characters(line_diff, '+')
            processed << (index + 1)
            [hi1, hi2]
          end
        else
          ERB::Util.h(chunk1)
        end
      end.flatten
      lines.map{|line| line.each_line.map(&:chomp).to_a if line }.flatten.compact.
        map{|line|wrap_line(line) }.compact
    end

    def split_characters(chunk)
      chunk.gsub(/^./, '').each_line.map do |line|
        chars = line.sub(/([\r\n]$)/, '').split('')
        # add escaped newlines
        chars << '\n'
        chars.map{|chr| ERB::Util.h(chr) }
      end.flatten.join("\n") + "\n"
    end

    def reconstruct_characters(line_diff, type)
      enum = line_diff.each_chunk
      enum.each_with_index.map do |l, i|
        re = /(^|\\n)#{Regexp.escape(type)}/
        case l
        when re
          highlight(l)
        when /^ /
          if i > 1 and enum.to_a[i+1] and l.each_line.to_a.size < 4
            highlight(l)
          else
            l.gsub(/^./, '').gsub("\n", '').
              gsub('\r', "\r").gsub('\n', "\n")
          end
        end
      end.join('').split("\n").map do |l|
        type + l.gsub('</strong><strong>' , '')
      end
    end

    def highlight(lines)
      "<strong>" +
        lines.
          # strip diff tokens (e.g. +,-,etc.)
          gsub(/(^|\\n)./, '').
          # mark line boundaries from higher level line diff
          # html is all escaped so using brackets should make this safe.
          gsub('\n', '<LINE_BOUNDARY>').
          # join characters back by stripping out newlines
          gsub("\n", '').
          # close and reopen strong tags.  we don't want inline elements
          # spanning block elements which get added later.
          gsub('<LINE_BOUNDARY>',"</strong>\n<strong>") + "</strong>"
    end
  end
end
