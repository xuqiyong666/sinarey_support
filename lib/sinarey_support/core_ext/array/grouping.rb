class Array

  def in_groups_of(number, fill_with = nil)
    if fill_with == false
      collection = self
    else
      padding = (number - size % number) % number
      collection = dup.concat([fill_with] * padding)
    end
    if block_given?
      collection.each_slice(number) { |slice| yield(slice) }
    else
      groups = []
      collection.each_slice(number) { |group| groups << group }
      groups
    end
  end

  def in_groups(number, fill_with = nil)
    division = size.div number
    modulo = size % number
    groups = []
    start = 0
    number.times do |index|
      length = division + (modulo > 0 && modulo > index ? 1 : 0)
      groups << last_group = slice(start, length)
      last_group << fill_with if fill_with != false &&
        modulo > 0 && length == division
      start += length
    end
    if block_given?
      groups.each { |g| yield(g) }
    else
      groups
    end
  end

  def split(value = nil, &block)
    inject([[]]) do |results, element|
      if block && block.call(element) || value == element
        results << []
      else
        results.last << element
      end
      results
    end
  end

end
