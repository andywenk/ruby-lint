# This script generates a list of all the constants and methods that are
# available out of the box. This is done in a standalone script so that
# constants introduced by Rlint and its dependencies don't pollute this list.

buffer  = []
output  = <<-OUTPUT
# This code is automatically generated by ./script/symbols.rb. Modifying this
# file directly will result in the loss of data the next time this script is
# executed.

module Rlint
  ##
  # Hash that contains all the standard Ruby constants and their methods.
  #
  # @return [Hash]
  #
  SYMBOLS = {
    %s
  }
end # Rlint
OUTPUT

# Generate a Hash for each constant. The keys are the method names and the
# values are set to `true`. The reason for using a Hash instead of an Array is
# that performing a lookup using the latter can be quite a bit slower as the
# size grows.
Object.constants.each do |name|
  const   = Object.const_get(name)
  methods = ''

  if !const.methods.is_a?(Array) or name =~ /RUBY_/
    next
  end

  if const
    longest = const.methods.sort do |left, right|
      right.length <=> left.length
    end

    longest = longest[0].length

    # Format each line of the hash and ensure that the values are aligned
    # nicely.
    methods = const.methods.map do |m|
      spaces = ' '

      (longest - m.length).times do
        spaces += ' '
      end

      "      '#{m}'#{spaces}=> true"
    end

    methods = methods.sort.join(",\n")
  end

  if !methods.empty?
    buffer << "'#{name}' => {\n#{methods}\n    },"
  else
    buffer << "'#{name}' => {},"
  end
end

handle = File.open(
  File.expand_path('../../lib/rlint/symbols.rb', __FILE__),
  'w'
)

handle.write(output % buffer.join("\n    "))
handle.close